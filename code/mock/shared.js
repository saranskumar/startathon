// Shared chrome for Aperture Daily mock worlds.
// No modules — these pages are opened via `npx serve` or file://.

(function (global) {
  function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function screenParam() {
    return new URLSearchParams(location.search).get('s') || '';
  }

  function gotoScreen(screen, extra) {
    const next = new URL(location.href);
    if (screen) next.searchParams.set('s', screen);
    else next.searchParams.delete('s');
    if (extra) {
      for (const [k, v] of Object.entries(extra)) {
        if (v == null || v === '') next.searchParams.delete(k);
        else next.searchParams.set(k, String(v));
      }
    }
    history.pushState({ screen }, '', next);
  }

  function bindPop(onChange) {
    window.addEventListener('popstate', () => onChange(screenParam()));
  }

  global.Aperture = { escapeHtml, screenParam, gotoScreen, bindPop };
})(window);
