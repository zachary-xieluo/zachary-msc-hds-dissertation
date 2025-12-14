/**
 * Dynamically adjust the CSS variable `--sum-sep-gap`
 * based on whether the `.n` element inside `.sum`
 * is rendered on a single line or multiple lines.
 *
 * This implementation is designed to be safe for
 * Quarto closeread pages:
 *  - It runs only after the DOM and closeread layout
 *    are fully initialised.
 *  - It scopes DOM queries to the closeread container
 *    instead of the entire document.
 *  - It avoids global resize listeners that can
 *    interfere with closeread scroll observers.
 */

(function () {
  // Gap values for single-line vs multi-line `.n`
  const SINGLE_GAP = '2rem';
  const MULTI_GAP  = '.79rem';

  /**
   * Estimate how many text lines an element occupies
   * by dividing its rendered height by its line-height.
   */
  function lineCount(el) {
    const cs = getComputedStyle(el);
    const lh = parseFloat(cs.lineHeight);
    const h  = el.getBoundingClientRect().height;
    return Math.max(1, Math.round(h / lh));
  }

  /**
   * Update `--sum-sep-gap` for all `.sum` elements
   * within a given root container.
   */
  function updateSumGaps(root) {
    if (!root) return;

    root.querySelectorAll('.sum').forEach(sum => {
      const n = sum.querySelector('.n');
      if (!n) return;

      const gap = lineCount(n) <= 1 ? SINGLE_GAP : MULTI_GAP;
      sum.style.setProperty('--sum-sep-gap', gap);
    });
  }

  /**
   * Run updates after closeread has finished constructing
   * its DOM structure. We attempt to locate a closeread
   * container and scope all operations to it.
   */
  function runAfterCloseread() {
    // Try common closeread container selectors
    const crRoot =
      document.querySelector('.cr-content') ||
      document.querySelector('.closeread') ||
      document.querySelector('main');

    if (!crRoot) return;

    // Initial update
    updateSumGaps(crRoot);

    /**
     * Observe DOM changes inside the closeread container.
     * This ensures updates are re-applied if sections are
     * dynamically added or reflowed by closeread.
     */
    const observer = new MutationObserver(() => {
      updateSumGaps(crRoot);
    });

    observer.observe(crRoot, {
      childList: true,
      subtree: true
    });
  }

  /**
   * Delay execution until:
   *  1) DOMContentLoaded has fired
   *  2) The browser has completed at least two render frames
   *
   * This avoids racing against closeread's internal
   * initialisation and layout calculations.
   */
  document.addEventListener('DOMContentLoaded', () => {
    requestAnimationFrame(() => {
      requestAnimationFrame(runAfterCloseread);
    });
  });

})();
