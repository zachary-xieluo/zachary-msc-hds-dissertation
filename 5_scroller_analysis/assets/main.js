/*
  Set --sum-sep-gap to:
  - 2rem when .n is a single line
  - 1rem when .n wraps to 2+ lines
  Adjust SINGLE_GAP / MULTI_GAP to your preferred units/values.
*/
(function(){
  const SINGLE_GAP = '2rem';
  const MULTI_GAP  = '.79rem';

  function lineCount(el){
    const cs = getComputedStyle(el);
    const lh = parseFloat(cs.lineHeight);
    const h  = el.getBoundingClientRect().height;
    return Math.max(1, Math.round(h / lh));
  }

  function updatesumGaps(root=document){
    root.querySelectorAll('.sum').forEach(sum => {
      const n = sum.querySelector('.n');
      if(!n) return;
      const gap = lineCount(n) <= 1 ? SINGLE_GAP : MULTI_GAP;
      sum.style.setProperty('--sum-sep-gap', gap);
    });
  }

  // Run on load and on resize (debounced)
  let t;
  window.addEventListener('resize', () => { clearTimeout(t); t = setTimeout(updatesumGaps, 100); });
  document.addEventListener('DOMContentLoaded', () => updatesumGaps());

  // expose for manual re-run after dynamic content changes
  window.updatesumGaps = updatesumGaps;
})();