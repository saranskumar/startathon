// Groups the ranked tree into the top-level regions a page is actually built
// from — the "which of the three panels am I looking at" question a sighted
// user answers instantly and a switch/voice-scanning user cannot. Reuses
// domTreeEngine.js's `tree` output (already a hierarchy with `isLandmark`
// flagged on every ARIA-landmark node) rather than re-walking the raw
// accessibility snapshot — no second pass over the DOM, no new heuristic.
//
// This is the "highlight the three main panels" half of the phone↔desktop
// integration (docs/idea/29-phone-desktop-integration.md): before anything is
// scanned or spoken, the user (or their caregiver) should be able to see
// *which region* a feature belongs to.

const FRIENDLY_NAME = {
  banner: 'top bar',
  navigation: 'side panel',
  main: 'main content',
  complementary: 'side panel',
  contentinfo: 'footer',
  search: 'search',
  form: 'form',
  region: 'section',
};

/**
 * @typedef {object} Region
 * @property {string} role - The ARIA landmark role (banner/navigation/main/…).
 * @property {string} friendlyName - `FRIENDLY_NAME[role]`, falling back to role.
 * @property {string|null} name - The landmark's own accessible name, if any.
 * @property {object} box - Screen rect, for drawing the highlight.
 * @property {object[]} features - Every kept, non-landmark descendant —
 *   exactly the navigation/information entries that live inside this region.
 */

/**
 * Extract the page's top-level landmark regions and, for each, the flat list
 * of ranked features it contains. A landmark nested inside another landmark
 * (e.g. a `search` region inside `header`) is folded into its parent's region
 * rather than surfaced as a fourth sibling — this project's UI names three
 * panels (top bar / side panel / main content) on purpose, per the
 * integration doc, not an arbitrary landmark count a page happens to use.
 *
 * @param {object|object[]} tree - `buildAuxiliaryTree(...).tree`.
 * @returns {Region[]}
 */
export function extractRegions(tree) {
  const roots = Array.isArray(tree) ? tree : [tree];
  const regions = [];

  function walk(node, insideLandmark) {
    if (!node) return;
    const isTopLevelLandmark = node.isLandmark && !insideLandmark;
    if (isTopLevelLandmark) {
      regions.push({
        role: node.role,
        friendlyName: FRIENDLY_NAME[node.role] ?? node.role,
        name: node.name ?? null,
        box: node.box,
        path: node.path,
        features: flattenFeatures(node),
      });
    }
    for (const child of node.children ?? []) {
      walk(child, insideLandmark || isTopLevelLandmark);
    }
  }

  for (const root of roots) walk(root, false);
  return regions;
}

function flattenFeatures(node) {
  const out = [];
  (function collect(n) {
    if (n.kept && !n.isLandmark) out.push(n);
    for (const c of n.children ?? []) collect(c);
  })(node);
  return out;
}

/**
 * One line per region, for narration or the "which panel is this" caption —
 * e.g. "3 panels: top bar (4 items), side panel (6 items), main content (2
 * items)". Empty regions are still named (a caregiver benefits from knowing a
 * panel exists and is just empty right now, vs. it not existing at all).
 *
 * @param {Region[]} regions
 * @returns {string}
 */
export function describeRegions(regions) {
  if (regions.length === 0) return 'No named regions on this page.';
  const parts = regions.map(r => `${r.friendlyName} (${r.features.length} items)`);
  return `${regions.length} panel${regions.length === 1 ? '' : 's'}: ${parts.join(', ')}`;
}

/**
 * Which region a given feature (by `path`) lives in, or null if it is outside
 * every landmark — the phone needs this to answer "which panel did I just
 * select something from" without re-deriving the whole region list.
 *
 * @param {Region[]} regions
 * @param {string} path
 * @returns {Region|null}
 */
export function regionOf(regions, path) {
  for (const region of regions) {
    if (region.features.some(f => f.path === path)) return region;
  }
  return null;
}
