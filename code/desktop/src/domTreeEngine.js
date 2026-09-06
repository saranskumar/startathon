// The DOM tree engine — takes the raw accessibility tree (from
// page.ariaSnapshotJSON) and produces the "auxiliary tree": a pruned,
// ranked, two-bucket (navigation / information) subset of nodes worth showing
// a low-precision user, per the tier-1 scoring plan in
// docs/tech/research/08-feature-ranking-auxiliary-tree.md and the
// navigation/information split from docs/idea/18-meeting-notes-feature-ranking.md.
//
// Pure and synchronous: no Playwright, no network, no LLM. The only
// "learning" signal is a usage-frequency boost (how often a feature has been
// picked before) supplied by the caller — see usageStore.js — which stands in
// for the "ML model, not an LLM" ranking signal raised in conversation,
// without needing a trained model or labeled data.
//
// Everything it produces is explainable: each feature carries the exact list
// of score terms that produced its number (`parts`), so the desktop inspector
// can show *why* something ranked where it did rather than asking anyone to
// trust an opaque total.

import { extractFeatureVector } from './rankingModel.js';
import { rankBucket } from './groupFeatures.js';

const LANDMARK_ROLES = new Set([
  'banner', 'navigation', 'main', 'search', 'form', 'complementary', 'contentinfo', 'region',
]);

// Page chrome landmarks — demoted so banner/nav links do not crowd out the
// real task inside main/form. search sits with chrome (site search), form
// and main are task containers.
const CHROME_LANDMARK_ROLES = new Set([
  'banner', 'navigation', 'complementary', 'contentinfo', 'search',
]);

const TASK_LANDMARK_ROLES = new Set(['main', 'form']);

// Roles a user can actually act on, split by the task shape the phone app
// renders for them (code/app/lib/runtime/task_spec.dart's TaskShape), so a
// feature arrives at the phone already knowing which input pattern fits.
const ROLE_TASK_SHAPE = {
  button: 'discrete',
  link: 'discrete',
  menuitem: 'discrete',
  menuitemcheckbox: 'discrete',
  menuitemradio: 'discrete',
  tab: 'discrete',
  option: 'discrete',
  checkbox: 'discrete',
  radio: 'discrete',
  switch: 'discrete',
  combobox: 'discrete',
  listbox: 'discrete',
  slider: 'continuous',
  spinbutton: 'continuous',
  scrollbar: 'continuous',
  textbox: 'text',
  searchbox: 'text',
};

// What Playwright call the agent would dispatch for this role.
const ROLE_ACTION = {
  checkbox: 'check',
  radio: 'check',
  switch: 'check',
  menuitemcheckbox: 'check',
  menuitemradio: 'check',
  textbox: 'fill',
  searchbox: 'fill',
  combobox: 'select',
  listbox: 'select',
  slider: 'set',
  spinbutton: 'set',
  scrollbar: 'set',
};

const INTERACTIVE_ROLES = new Set(Object.keys(ROLE_TASK_SHAPE));

// Roles that carry meaning for the Information bucket even without being
// landmarks or headings.
const INFORMATIVE_ROLES = new Set([
  'heading', 'paragraph', 'status', 'alert', 'log', 'listitem', 'cell',
  'rowheader', 'columnheader', 'term', 'definition', 'blockquote', 'code',
  'caption', 'figure', 'img', 'time', 'note', 'tooltip',
]);

// Structural wrappers with nothing to say on their own.
const NO_NAME_PENALTY_ROLES = new Set(['generic', 'none', 'presentation']);

const DEFAULT_WEIGHTS = {
  landmark: 3.0,
  headingBase: 2.5,
  headingLevelStep: 0.3,
  interactive: 2.0,
  hasName: 1.0,
  nameLengthDivisor: 40,
  // Tuned down from doc 08 §5's 1.5 starting point: at 1.5 a long label was
  // worth more than the whole h1-to-h6 range, so a verbose h3 outranked the
  // page's h1. Name length should break ties, not decide them.
  nameLengthCap: 0.75,
  linkDensity: 2.0,
  hidden: 1.5,
  offscreen: 1.25,
  disabled: 1.25,
  namelessWrapper: 1.0,
  landmarkProximity: 0.5,
  ambiguousInteractive: 0.75,
  usage: 1.5,
  // Prefer controls inside main/form over banner/nav chrome.
  pageChrome: 1.0,
  inMain: 0.75,
  // Weight for the optional trained ranking model's contribution (see
  // rankingModel.js) -- centered so a neutral 0.5 prediction adds nothing.
  learned: 1.5,
};

const DEFAULT_VIEWPORT = { width: 1280, height: 720 };

// Shortest subtree text whose link ratio is worth inheriting as a signal.
const LINK_DENSITY_MIN_TEXT = 40;

// Longest accessible name shown verbatim before deriveLabel() shortens it.
const LABEL_MAX = 48;

function clamp(value, min, max) { return Math.min(Math.max(value, min), max); }
function round(value) { return Math.round(value * 100) / 100; }

function ownText(node) {
  return String(node.name ?? node.text ?? '').replace(/\s+/g, ' ').trim();
}

function normalizeText(value) {
  return value.toLowerCase().replace(/\s+/g, ' ').trim();
}

/**
 * Raw snapshot nodes are free-form JSON and the shape drifts between
 * Playwright versions. Normalize once, up front, so every pass below can
 * assume the same fields exist rather than each re-guessing.
 */
function normalizeNode(raw, path) {
  const children = Array.isArray(raw.children) ? raw.children : [];
  return {
    role: String(raw.role ?? 'generic'),
    name: raw.name != null ? String(raw.name).replace(/\s+/g, ' ').trim() : null,
    text: raw.text != null ? String(raw.text).replace(/\s+/g, ' ').trim() : null,
    level: typeof raw.level === 'number' ? raw.level : null,
    ref: raw.ref ?? null,
    box: raw.box ?? null,
    value: raw.value ?? null,
    checked: raw.checked ?? null,
    selected: raw.selected ?? null,
    expanded: raw.expanded ?? null,
    disabled: raw.disabled === true,
    // A plain <div onclick> gets role "generic" but a pointer cursor. That is
    // doc 18's "unknown element" case — recorded, not guessed at.
    pointer: raw.cursor === 'pointer',
    path,
    children: children.map((child, i) => normalizeNode(child, path + '.' + i)),
  };
}

export function normalizeTree(rawTree) {
  const roots = Array.isArray(rawTree) ? rawTree : [rawTree];
  return roots.filter(Boolean).map((root, i) => normalizeNode(root, String(i)));
}

// Post-order pass: annotate every node with subtree text length and subtree
// link-text length, so link density (Readability/Boilerpipe's single most
// reusable signal) can be computed bottom-up.
function annotate(node) {
  const own = ownText(node).length;
  let textLength = own;
  let linkTextLength = node.role === 'link' ? own : 0;
  let descendants = 0;
  let interactiveDescendants = 0;

  for (const child of node.children) {
    annotate(child);
    textLength += child.textLength;
    linkTextLength += child.linkTextLength;
    descendants += 1 + child.descendants;
    interactiveDescendants += child.interactiveDescendants + (INTERACTIVE_ROLES.has(child.role) ? 1 : 0);
  }

  node.textLength = textLength;
  node.linkTextLength = linkTextLength;
  node.descendants = descendants;
  node.interactiveDescendants = interactiveDescendants;
  return node;
}

function isHidden(node) {
  if (!node.box) return false; // No boxes requested — don't invent a penalty.
  return node.box.width === 0 || node.box.height === 0;
}

function isOffscreen(node, viewport) {
  const box = node.box;
  if (!box || isHidden(node)) return false;
  return box.y >= viewport.height || box.x >= viewport.width ||
    box.y + box.height <= 0 || box.x + box.width <= 0;
}

/**
 * A short label to actually show someone. An accessible name is built by
 * concatenating descendant text, so a card-shaped button's name is routinely a
 * whole paragraph — unusable as a button label on a phone. Prefer the heading
 * the card already contains; fall back to a word-boundary truncation.
 */
function deriveLabel(node, name) {
  if (!name) return null;
  if (name.length <= LABEL_MAX) return name;

  const heading = findDescendant(node, n => n.role === 'heading' && ownText(n));
  if (heading) return ownText(heading);

  const firstLine = name.split(/[.·—|]/)[0].trim();
  if (firstLine && firstLine.length <= LABEL_MAX) return firstLine;

  const cut = name.slice(0, LABEL_MAX);
  const lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > LABEL_MAX / 2 ? cut.slice(0, lastSpace) : cut).trim() + '…';
}

function findDescendant(node, predicate) {
  for (const child of node.children) {
    if (predicate(child)) return child;
    const found = findDescendant(child, predicate);
    if (found) return found;
  }
  return null;
}

/**
 * Stable usage key across snapshots — refs are regenerated on every snapshot,
 * role+name is not. Null for unnamed nodes: without a name every `button::`
 * would share one usage counter, so they get no usage boost at all rather
 * than a wrong one.
 */
export function featureSignature(node) {
  const name = normalizeText(ownText(node));
  return name ? node.role + '::' + name : null;
}

/**
 * Disambiguated identity for dedupe / locate fallback. Two "Cancel" buttons
 * under different section headings keep distinct identities while still
 * sharing one usage signature (`button::cancel`). The disambiguator is
 * normally the nearest section label / named group / named ancestor.
 *
 * @param node - normalized node (role + name/text).
 * @param nearestNamedAncestor - already-normalized section or ancestor label, or null.
 */
export function featureIdentity(node, nearestNamedAncestor = null) {
  const name = normalizeText(ownText(node));
  if (!name) return null;
  const ancestor = nearestNamedAncestor ? normalizeText(nearestNamedAncestor) : '';
  return ancestor
    ? node.role + '::' + name + '::' + ancestor
    : node.role + '::' + name;
}

/**
 * The tier-1 formula from docs/tech/research/08 §5, with each term kept as a
 * labelled part so the total is always traceable back to its reasons.
 */
function scoreNode(node, ctx) {
  const {
    ancestorNames, depthFromLandmark, usageCounts, weights, viewport,
    inChrome, inMain, sectionLabel, groupLabel,
  } = ctx;
  const parts = [];
  const add = (label, value) => { if (value) parts.push({ label, value: round(value) }); };

  const name = ownText(node);
  const isLandmark = LANDMARK_ROLES.has(node.role);
  const isHeading = node.role === 'heading';
  const isInteractive = INTERACTIVE_ROLES.has(node.role);
  // A pointer-cursor wrapper with no real role: actionable in practice,
  // unclassifiable by role alone. Scored below a real control, and flagged.
  const isAmbiguous = !isInteractive && node.pointer && node.interactiveDescendants === 0;

  if (isLandmark) add('ARIA landmark', weights.landmark);
  if (isHeading) {
    const level = clamp(node.level ?? 2, 1, 6);
    add('heading h' + level, weights.headingBase - weights.headingLevelStep * level);
  }
  if (isInteractive) add('interactive', weights.interactive);
  if (isAmbiguous) add('clickable (no ARIA role)', weights.ambiguousInteractive);

  // "Has a name AND that name isn't already said by an ancestor" — the
  // duplicate check is containment, not equality: an accessible name is
  // usually built by concatenating descendant text, so a child's text is a
  // substring of its parent's name far more often than an exact match.
  const duplicatesAncestor = Boolean(name) && ancestorNames.some(a => a.includes(normalizeText(name)));
  if (name && !duplicatesAncestor) add('accessible name', weights.hasName);

  add('name length', Math.min(name.length / weights.nameLengthDivisor, weights.nameLengthCap));

  // Readability's link density is a property of *containers* — a link's own
  // density is 1.0 by definition, so applying it to the link itself would just
  // be a flat penalty on every link on the page. What actually carries the
  // signal is the container the node sits in: a link inside a nav blob is
  // boilerplate, the same link inside prose is content. So a container is
  // scored on its own density, and everything else inherits its nearest
  // meaningful container's.
  const isContainer = node.children.length > 0 && !isInteractive;
  const ownDensity = isContainer && node.textLength > 0 ? node.linkTextLength / node.textLength : 0;
  const linkDensity = isContainer ? ownDensity : ctx.containerLinkDensity;
  add('link density', -weights.linkDensity * linkDensity);

  const hidden = isHidden(node);
  const offscreen = isOffscreen(node, viewport);
  if (hidden) add('zero-size', -weights.hidden);
  else if (offscreen) add('outside viewport', -weights.offscreen);
  if (node.disabled) add('disabled', -weights.disabled);

  if (NO_NAME_PENALTY_ROLES.has(node.role) && !name) add('nameless wrapper', -weights.namelessWrapper);

  add('near a landmark', weights.landmarkProximity * clamp(3 - depthFromLandmark, 0, 3));

  // Prefer the page's real task over site chrome. A control inside main/form
  // gets a boost; one sitting only in banner/nav/complementary is demoted.
  if (inMain) add('in main content', weights.inMain);
  else if (inChrome) add('page chrome', -weights.pageChrome);

  const signature = featureSignature(node);
  const count = signature ? (usageCounts[signature] ?? 0) : 0;
  if (count) add('picked ' + count + 'x before', weights.usage * Math.log2(1 + count));

  // Prefer the section/group that structurally owns this control (a preceding
  // heading or named role=group) so two "Cancel" buttons under different
  // headings keep distinct identities. Fall back to the nearest named
  // ancestor when there is no section context.
  const disambiguator = sectionLabel || groupLabel ||
    (ancestorNames.length ? ancestorNames[ancestorNames.length - 1] : null);
  const identity = featureIdentity(node, disambiguator);

  const total = parts.reduce((sum, p) => sum + p.value, 0);
  return {
    total: round(total), parts, name, signature, identity,
    isLandmark, isHeading, isInteractive, isAmbiguous,
    hidden, offscreen, linkDensity: round(linkDensity), ownDensity, isContainer,
    duplicatesAncestor,
  };
}

/**
 * Why a static-text node is noise, or null if it is worth keeping — the same
 * "drop StaticText that duplicates the parent's name" rule doc 08 §2 records
 * as standard agent-tooling practice, kept as a reason string so the inspector
 * can show what the engine threw away and why. Interactive, landmark and
 * heading nodes are never dropped for text reasons: they are actionable or
 * structural regardless of what wraps them. Offscreen/hidden interactive
 * nodes stay in the tree but are filtered from buckets later.
 */
function pruneReason(scored) {
  if (scored.isInteractive || scored.isHeading || scored.isLandmark || scored.isAmbiguous) return null;
  if (!scored.name) return 'no accessible name';
  if (scored.duplicatesAncestor) return "text already in an ancestor's name";
  return null;
}

function walk(node, ctx, out) {
  const depthFromLandmark = LANDMARK_ROLES.has(node.role) ? 0 : ctx.depthFromLandmark + 1;

  let inChrome = ctx.inChrome;
  let inMain = ctx.inMain;
  let landmarkLabel = ctx.landmarkLabel;
  let sectionLabel = ctx.sectionLabel;
  let groupLabel = ctx.groupLabel;

  if (CHROME_LANDMARK_ROLES.has(node.role)) {
    inChrome = true;
    landmarkLabel = ownText(node) || node.role;
  }
  if (TASK_LANDMARK_ROLES.has(node.role)) {
    inMain = true;
    // Entering main/form leaves chrome for scoring purposes even if nested
    // oddly; the task container wins.
    inChrome = false;
    landmarkLabel = ownText(node) || node.role;
  }
  if (node.role === 'heading' && ownText(node)) {
    sectionLabel = ownText(node);
  }
  if (node.role === 'group' && ownText(node)) {
    groupLabel = ownText(node);
  }

  const scored = scoreNode(node, {
    ...ctx,
    depthFromLandmark,
    inChrome,
    inMain,
  });

  const reason = pruneReason(scored);
  // Offscreen nodes stay visible in the inspector tree with a reason, but
  // are hard-excluded from both buckets (same as zero-size / hidden).
  let prunedBecause = reason;
  let kept = reason === null;
  if (scored.offscreen && kept) {
    prunedBecause = 'outside viewport';
  }

  out.push({
    role: node.role,
    name: scored.name || null,
    label: deriveLabel(node, scored.name),
    level: node.level,
    ref: node.ref,
    path: node.path,
    box: node.box,
    // A filled text field carries its content as the node's text, not as a
    // `value` — so without this, editing an existing value starts from blank.
    value: node.value ?? (scored.isInteractive ? node.text : null),
    checked: node.checked,
    selected: node.selected,
    disabled: node.disabled,
    score: scored.total,
    parts: scored.parts,
    isInteractive: scored.isInteractive,
    isHeading: scored.isHeading,
    isLandmark: scored.isLandmark,
    isAmbiguous: scored.isAmbiguous,
    hidden: scored.hidden,
    offscreen: scored.offscreen,
    inChrome,
    inMain,
    sectionLabel,
    groupLabel,
    landmarkLabel,
    linkDensity: scored.linkDensity,
    // A named leaf is this snapshot format's StaticText: most real page copy
    // arrives as a text-bearing <div>, i.e. role "generic" with no children.
    isLeafText: node.children.length === 0 && Boolean(scored.name),
    signature: scored.signature,
    identity: scored.identity,
    prunedBecause,
    taskShape: ROLE_TASK_SHAPE[node.role] ?? (scored.isAmbiguous ? 'discrete' : null),
    action: scored.isInteractive || scored.isAmbiguous ? (ROLE_ACTION[node.role] ?? 'click') : null,
    kept,
  });

  const childCtx = {
    ...ctx,
    depthFromLandmark,
    inChrome,
    inMain,
    landmarkLabel,
    sectionLabel,
    groupLabel,
    // Only containers with real text set the density their descendants
    // inherit; a two-word wrapper's ratio is noise, not a signal.
    containerLinkDensity: scored.isContainer && node.textLength >= LINK_DENSITY_MIN_TEXT
      ? scored.ownDensity
      : ctx.containerLinkDensity,
    ancestorNames: scored.name
      ? [...ctx.ancestorNames, normalizeText(scored.name)]
      : ctx.ancestorNames,
  };

  // Headings and named groups label subsequent *siblings*, not only their
  // own descendants — a form's "Applicant" h2 then six fields as siblings.
  let siblingSection = sectionLabel;
  let siblingGroup = groupLabel;
  for (const child of node.children) {
    walk(child, { ...childCtx, sectionLabel: siblingSection, groupLabel: siblingGroup }, out);
    if (child.role === 'heading' && ownText(child)) siblingSection = ownText(child);
    if (child.role === 'group' && ownText(child)) siblingGroup = ownText(child);
  }
}

/** Highest-scoring entry wins when the same feature appears more than once. */
function dedupe(features) {
  const bestByKey = new Map();
  for (const f of features) {
    const key = f.identity ?? f.signature ?? (f.role + '@' + f.path);
    const prev = bestByKey.get(key);
    if (!prev || f.score > prev.score) bestByKey.set(key, f);
  }
  return [...bestByKey.values()].sort((a, b) => b.score - a.score);
}

/**
 * Tier-1's honest self-assessment, per doc 08 §5's tier-2 trigger conditions.
 * Purely structural — deciding whether to escalate must not itself cost an LLM
 * call. Nothing here calls anything; it reports, the caller decides.
 */
function assessAmbiguity(features, ranked) {
  const reasons = [];
  const hasLandmark = features.some(f => f.isLandmark);
  const hasHeading = features.some(f => f.isHeading);
  const unknownInteractive = features.filter(f => f.isAmbiguous && f.kept).length;

  if (!hasLandmark && !hasHeading) {
    reasons.push('No ARIA landmarks and no headings — nothing structural to anchor the ranking on.');
  }
  const top = ranked.slice(0, 8);
  const flat = top.length >= 4 && top[0].score - top[top.length - 1].score < 0.5;
  if (flat) {
    reasons.push('Top ' + top.length + ' candidates are within 0.5 points — the ordering is close to arbitrary.');
  }
  if (unknownInteractive > 0) {
    reasons.push(unknownInteractive + ' clickable element(s) have no ARIA role to classify them by.');
  }
  return { needsReview: reasons.length > 0, hasLandmark, hasHeading, flat, unknownInteractive, reasons };
}

/**
 * A <label> is a sibling of its control, not an ancestor, so the ancestor-name
 * check above never sees it — yet "Rating (0-10)" as loose text next to a
 * spinbutton already named "Rating (0-10)" is the same redundancy, and on a
 * form it is most of the Information bucket. Cross-check the whole tree once
 * instead of per-branch.
 */
function dropControlLabels(features) {
  const controlNames = new Set(
    features.filter(f => f.isInteractive && f.name).map(f => normalizeText(f.name)));
  for (const f of features) {
    if (!f.kept || f.isInteractive || f.isHeading || f.isLandmark || !f.isLeafText) continue;
    if (controlNames.has(normalizeText(f.name))) {
      f.kept = false;
      f.prunedBecause = "repeats a control's label";
    }
  }
}

/**
 * Optional, additive, and fully backward-compatible: with no model passed in
 * (the default everywhere today), this is a no-op and every existing score
 * is untouched. When a model is trained (rankingModel.js, from real
 * selection history), its prediction becomes one more labelled `parts` entry
 * — still fully explainable, never an opaque override of the heuristic score.
 */
function applyRankingModel(features, model, learnedWeight) {
  if (!model) return;
  for (const f of features) {
    const p = model.predict(extractFeatureVector(f));
    const boost = round(learnedWeight * (2 * p - 1));
    if (!boost) continue;
    f.score = round(f.score + boost);
    f.parts = [...f.parts, { label: 'learned from usage (p=' + p.toFixed(2) + ')', value: boost }];
  }
}

/**
 * The pruned hierarchy behind the two buckets — same nodes, kept as a tree so
 * the inspector can show structure, not just two flat lists. A dropped node
 * that still has kept descendants stays as a passthrough wrapper.
 */
function pruneTree(node, byPath) {
  const feature = byPath.get(node.path);
  const children = node.children.map(c => pruneTree(c, byPath)).filter(Boolean);
  if (!feature) return null;
  if (!feature.kept && children.length === 0) return null;
  return { ...feature, children };
}

/**
 * Build the auxiliary tree: a ranked navigation set and information set, per
 * docs/idea/18-meeting-notes-feature-ranking.md's two-bucket split.
 *
 * @param rawTree - result of page.ariaSnapshotJSON({ mode: 'ai', boxes: true }) — a node or array of nodes.
 * @param options.usageCounts - { [signature]: count } from usageStore.js.
 * @param options.usageWeight - how much a prior selection boosts score (default 1.5, tune by eye).
 * @param options.limit - max features per bucket (default 12).
 * @param options.viewport - { width, height }, for the outside-viewport penalty.
 * @param options.weights - per-term overrides of DEFAULT_WEIGHTS, for live tuning.
 * @param options.rankingModel - an optional trained LogisticRanker (rankingModel.js).
 *   Still no LLM: one small trained-from-real-usage linear model, applied as
 *   one more explainable, additive score term.
 */
export function buildAuxiliaryTree(rawTree, options = {}) {
  const {
    usageCounts = {},
    usageWeight = DEFAULT_WEIGHTS.usage,
    limit = 12,
    viewport = DEFAULT_VIEWPORT,
    weights: weightOverrides = {},
    rankingModel = null,
  } = options;

  const weights = { ...DEFAULT_WEIGHTS, ...weightOverrides, usage: usageWeight };
  const roots = normalizeTree(rawTree).map(annotate);

  const features = [];
  const baseCtx = {
    ancestorNames: [],
    // Nothing above the first landmark gets proximity credit; 99 makes the
    // clamp fall to zero until a landmark is actually entered.
    depthFromLandmark: 99,
    containerLinkDensity: 0,
    inChrome: false,
    inMain: false,
    landmarkLabel: null,
    sectionLabel: null,
    groupLabel: null,
    usageCounts, weights, viewport,
  };
  for (const root of roots) walk(root, baseCtx, features);

  dropControlLabels(features);
  applyRankingModel(features, rankingModel, weights.learned);

  const kept = features.filter(f => f.kept);
  const byPath = new Map(features.map(f => [f.path, f]));

  // Offscreen and hidden never enter buckets — you cannot act on or read what
  // is not on screen. They remain in `tree` with prunedBecause set.
  const navigationCandidates = dedupe(kept.filter(f =>
    (f.isInteractive || f.isAmbiguous) && !f.disabled && !f.hidden && !f.offscreen));

  // Landmarks are excluded from Information on purpose. A landmark's own name
  // ("Page tools", "Personal tools") is structure, not something to read to
  // anyone — its +3.0 exists to lift the content *inside* it via landmark
  // proximity. Leaving them in put six navigation labels above the page's h1
  // on a real article, which is exactly backwards from the WebAIM finding
  // (doc 08 §1) that headings, not landmarks, are how people navigate.
  const informationCandidates = dedupe(kept.filter(f =>
    !f.isInteractive && !f.isAmbiguous && !f.isLandmark && !f.hidden && !f.offscreen &&
    Boolean(f.name) &&
    (f.isHeading || INFORMATIVE_ROLES.has(f.role) || f.isLeafText)));

  const navigation = rankBucket(navigationCandidates, limit);
  const information = rankBucket(informationCandidates, limit);

  const rankedAll = [...navigation, ...information].sort((a, b) => b.score - a.score);

  return {
    navigation,
    information,
    ambiguity: assessAmbiguity(features, rankedAll),
    tree: roots.map(root => pruneTree(root, byPath)).filter(Boolean),
    stats: {
      rawNodes: features.length,
      keptNodes: kept.length,
      prunedNodes: features.length - kept.length,
      interactive: kept.filter(f => f.isInteractive).length,
      landmarks: kept.filter(f => f.isLandmark).length,
      headings: kept.filter(f => f.isHeading).length,
      ambiguous: kept.filter(f => f.isAmbiguous).length,
    },
    weights,
  };
}

export { DEFAULT_WEIGHTS, LANDMARK_ROLES, INTERACTIVE_ROLES, ROLE_TASK_SHAPE, CHROME_LANDMARK_ROLES };
