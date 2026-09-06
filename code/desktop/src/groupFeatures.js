// Hierarchical packing for auxiliary-tree buckets. When a page has more
// actionable features than the visible limit (default 12), fold them into
// nested groups instead of silently dropping everything past rank N.
//
// Split order:
//   1. Structural — nearest heading, role=group, or landmark label.
//   2. Spatial — 2×2 bounding-box quadrants (empty ones dropped).
// Recurse until every visible level has ≤ limit items.
//
// Pure and synchronous. Groups are first-class bucket items with action
// "open"; opening one only changes what the consumer shows, never the page.

function round(value) {
  return Math.round(value * 100) / 100;
}

/** Union of member bounding boxes, or null if none have a box. */
export function unionBox(features) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  let any = false;
  for (const f of features) {
    const b = f.box;
    if (!b || typeof b.x !== 'number') continue;
    any = true;
    minX = Math.min(minX, b.x);
    minY = Math.min(minY, b.y);
    maxX = Math.max(maxX, b.x + (b.width ?? 0));
    maxY = Math.max(maxY, b.y + (b.height ?? 0));
  }
  if (!any) return null;
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
}

function leafCount(item) {
  if (item.isGroup) return item.memberCount ?? (item.members?.length ?? 0);
  return 1;
}

function bestScore(items) {
  let best = -Infinity;
  for (const item of items) {
    const s = item.score ?? -Infinity;
    if (s > best) best = s;
  }
  return best === -Infinity ? 0 : best;
}

/**
 * Build a synthetic group feature. `members` may themselves be groups.
 * Score is the best member score so a dense task region still outranks
 * leftover chrome.
 */
export function makeGroup(label, members, { kind = 'group', groupKey = null } = {}) {
  const count = members.reduce((sum, m) => sum + leafCount(m), 0);
  const score = round(bestScore(members));
  const base = label || 'Group';
  return {
    kind: 'group',
    isGroup: true,
    groupKind: kind,
    groupKey,
    role: 'group',
    name: base,
    label: base + ' · ' + count,
    score,
    parts: [{ label: 'best member', value: score }],
    members,
    memberCount: count,
    box: unionBox(members),
    action: 'open',
    taskShape: 'discrete',
    isInteractive: false,
    isAmbiguous: false,
    isHeading: false,
    isLandmark: false,
    hidden: false,
    offscreen: false,
    disabled: false,
    signature: null,
    identity: 'group::' + (groupKey ?? base),
    ref: null,
    path: null,
    kept: true,
  };
}

/** Structural cluster key: nearest heading/group/landmark, else "_ungrouped". */
export function structuralKey(feature) {
  if (feature.sectionLabel) return 'section:' + feature.sectionLabel;
  if (feature.groupLabel) return 'group:' + feature.groupLabel;
  if (feature.landmarkLabel && feature.inChrome) return 'landmark:' + feature.landmarkLabel;
  if (feature.landmarkLabel && !feature.inChrome) return 'landmark:' + feature.landmarkLabel;
  return '_ungrouped';
}

function structuralLabel(key) {
  if (key === '_ungrouped') return 'More';
  const colon = key.indexOf(':');
  return colon >= 0 ? key.slice(colon + 1) : key;
}

/**
 * Split features into up to 4 spatial quadrants by the midpoint of their
 * union box. Empty quadrants are dropped. Features without a box go into
 * the first non-empty bucket (or a leftover bucket).
 */
export function splitSpatial(features) {
  if (features.length === 0) return [];
  const box = unionBox(features);
  if (!box || box.width <= 0 || box.height <= 0) {
    // No geometry — fall back to equal-sized chunks of ~limit-friendly size.
    return chunkEvenly(features, 4);
  }

  const midX = box.x + box.width / 2;
  const midY = box.y + box.height / 2;
  const quads = [
    { key: 'nw', label: 'Top left', items: [] },
    { key: 'ne', label: 'Top right', items: [] },
    { key: 'sw', label: 'Bottom left', items: [] },
    { key: 'se', label: 'Bottom right', items: [] },
  ];
  const noBox = [];

  for (const f of features) {
    const b = f.box;
    if (!b || typeof b.x !== 'number') {
      noBox.push(f);
      continue;
    }
    const cx = b.x + (b.width ?? 0) / 2;
    const cy = b.y + (b.height ?? 0) / 2;
    const right = cx >= midX;
    const bottom = cy >= midY;
    if (!right && !bottom) quads[0].items.push(f);
    else if (right && !bottom) quads[1].items.push(f);
    else if (!right && bottom) quads[2].items.push(f);
    else quads[3].items.push(f);
  }

  const nonEmpty = quads.filter(q => q.items.length > 0);
  if (noBox.length && nonEmpty.length) {
    nonEmpty[0].items.push(...noBox);
  } else if (noBox.length) {
    nonEmpty.push({ key: 'other', label: 'Other', items: noBox });
  }
  return nonEmpty;
}

function chunkEvenly(features, parts) {
  const n = Math.min(parts, features.length);
  if (n <= 1) return [{ key: 'all', label: 'All', items: features }];
  const size = Math.ceil(features.length / n);
  const out = [];
  for (let i = 0; i < n; i++) {
    const slice = features.slice(i * size, (i + 1) * size);
    if (slice.length) out.push({ key: 'chunk' + i, label: 'Group ' + (i + 1), items: slice });
  }
  return out;
}

/**
 * Pack a flat sorted list into a visible level of ≤ limit items.
 * Returns a new list that may contain groups; every leaf remains reachable
 * by opening groups recursively.
 */
export function packToLimit(features, limit = 12) {
  if (!features || features.length === 0) return [];
  if (features.length <= limit) return features.slice();

  // Prefer structural clusters when they actually split the set.
  const byKey = new Map();
  for (const f of features) {
    const key = structuralKey(f);
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(f);
  }

  let clusters;
  if (byKey.size >= 2 && byKey.size <= limit) {
    clusters = [...byKey.entries()].map(([key, items]) => ({
      key,
      label: structuralLabel(key),
      items,
    }));
  } else if (byKey.size > limit) {
    // Too many tiny sections — take the biggest ones as groups and fold the
    // rest into "More".
    const sorted = [...byKey.entries()].sort((a, b) => b[1].length - a[1].length);
    const kept = sorted.slice(0, limit - 1);
    const rest = sorted.slice(limit - 1).flatMap(([, items]) => items);
    clusters = kept.map(([key, items]) => ({
      key,
      label: structuralLabel(key),
      items,
    }));
    if (rest.length) clusters.push({ key: '_more', label: 'More', items: rest });
  } else {
    // One structural bucket (or none) still over limit — split spatially.
    clusters = splitSpatial(features).map(q => ({
      key: q.key,
      label: q.label,
      items: q.items,
    }));
  }

  // If spatial/structural still produced a single oversized cluster, force
  // a 4-way spatial split (or even chunks).
  if (clusters.length === 1 && clusters[0].items.length > limit) {
    clusters = splitSpatial(clusters[0].items).map(q => ({
      key: q.key,
      label: q.label,
      items: q.items,
    }));
  }
  if (clusters.length === 1 && clusters[0].items.length > limit) {
    clusters = chunkEvenly(clusters[0].items, 4);
  }

  const packed = clusters.map(c => {
    const nested = packToLimit(c.items, limit);
    if (nested.length === 1 && !nested[0].isGroup) return nested[0];
    if (nested.length === c.items.length && nested.every(m => !m.isGroup) && nested.length <= limit) {
      // Members fit at this level as a group of leaves.
      return makeGroup(c.label, nested, { groupKey: c.key });
    }
    // Nested may already contain groups (recursive pack).
    return makeGroup(c.label, nested, { groupKey: c.key });
  });

  // If packing somehow still exceeds limit (pathological), wrap the overflow.
  if (packed.length <= limit) return packed.sort((a, b) => b.score - a.score);

  const head = packed.slice(0, limit - 1);
  const tail = packed.slice(limit - 1);
  head.push(makeGroup('More', packToLimit(flattenLeaves(tail), limit), { groupKey: '_overflow' }));
  return head.sort((a, b) => b.score - a.score);
}

function flattenLeaves(items) {
  const out = [];
  for (const item of items) {
    if (item.isGroup) out.push(...flattenLeaves(item.members ?? []));
    else out.push(item);
  }
  return out;
}

/**
 * When there are several chrome interactives AND at least one main-content
 * control, collapse all chrome into one "Site chrome · N" group so banner/nav
 * links cannot occupy most of the visible slots.
 */
export function bundleChrome(features, { minChrome = 2 } = {}) {
  const chrome = [];
  const content = [];
  for (const f of features) {
    if (f.inChrome && !f.inMain) chrome.push(f);
    else content.push(f);
  }
  if (chrome.length < minChrome || content.length === 0) return features.slice();

  const group = makeGroup('Site chrome', chrome.sort((a, b) => b.score - a.score), {
    kind: 'chrome',
    groupKey: 'site-chrome',
  });
  // Slight score trim so dense main content still leads when scores are close.
  group.score = round(group.score - 0.01);
  return [...content, group].sort((a, b) => b.score - a.score);
}

/**
 * Full bucket pipeline: deduped sorted features → chrome bundle → pack to limit
 * → assign ranks.
 */
export function rankBucket(features, limit = 12) {
  const sorted = features.slice().sort((a, b) => b.score - a.score);
  const bundled = bundleChrome(sorted);
  const packed = packToLimit(bundled, limit);
  return packed.map((f, i) => ({ rank: i + 1, ...f }));
}
