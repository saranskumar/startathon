// Runs INSIDE the page (installed via page.addInitScript), not in Node.
// Detects "a real navigation/state-change happened" without trying to
// classify whatever element was clicked, per docs/tech/research/08
// §4's closing point: watch the *effect*, not the triggering element.
//
// Two independent signals, matching production SPA-analytics practice:
//   1. History API hook — pushState/replaceState/popstate. Covers routers.
//   2. MutationObserver + a threshold on document.body — covers apps
//      (like Aperture) that re-render without ever touching the URL.
(() => {
  if (window.__auxWatcherInstalled) return;
  window.__auxWatcherInstalled = true;

  function notifyNav(type) {
    if (window.__onNavEvent) window.__onNavEvent(type, location.href);
  }
  const origPush = history.pushState;
  const origReplace = history.replaceState;
  history.pushState = function (...args) { origPush.apply(this, args); notifyNav('pushState'); };
  history.replaceState = function (...args) { origReplace.apply(this, args); notifyNav('replaceState'); };
  window.addEventListener('popstate', () => notifyNav('popstate'));

  // Cheap fingerprint of "what page/screen is this", not a full tree read.
  function fingerprint() {
    const main = document.querySelector('main, [role="main"]');
    const h1 = document.querySelector('h1');
    return {
      elementCount: document.body ? document.body.getElementsByTagName('*').length : 0,
      mainLabel: ((main && (main.getAttribute('aria-label') || main.textContent)) || '').slice(0, 80),
      heading: ((h1 && h1.textContent) || '').slice(0, 80),
      title: document.title,
    };
  }

  // Doc 08 §4: no standardized threshold exists — >50% node-count churn,
  // or the page's own idea of its heading/title changing, is a starting
  // point to hand-tune, not a proven constant.
  // Returns the list of fields that changed enough to count, so the Node side
  // can report the real reason rather than guessing at one.
  function majorChanges(before, after) {
    var changed = [];
    if (before.heading !== after.heading) changed.push('heading');
    if (before.mainLabel !== after.mainLabel) changed.push('main label');
    if (before.title !== after.title) changed.push('title');
    if (before.elementCount > 0 &&
        Math.abs(after.elementCount - before.elementCount) / before.elementCount > 0.5) {
      changed.push('element count ' + before.elementCount + ' -> ' + after.elementCount);
    }
    return changed;
  }

  function start() {
    if (!document.body) return;
    let last = fingerprint();
    let scheduled = false;
    const observer = new MutationObserver(() => {
      if (scheduled) return;
      scheduled = true;
      queueMicrotask(() => {
        scheduled = false;
        const now = fingerprint();
        const changed = majorChanges(last, now);
        if (changed.length > 0) {
          last = now;
          if (window.__onMajorChange) window.__onMajorChange(JSON.stringify({ ...now, changed }));
        }
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
