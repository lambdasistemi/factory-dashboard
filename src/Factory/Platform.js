"use strict";

// Minimal typed FFI: expose the container size as a nullable record so the
// PureScript side can treat absence explicitly. No other globals are used.
export function focusNodeImpl(selector) {
  return function () {
    var el = document.querySelector(selector);
    if (el && typeof el.focus === "function") {
      el.focus();
    }
  };
}

export function containerSizeImpl(element) {
  return function () {
    if (typeof element.getBoundingClientRect !== "function") {
      return null;
    }
    var rect = element.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
      return null;
    }
    return { width: rect.width, height: rect.height };
  };
}

export const copyTextImpl = text => done => () => {
  if (!navigator.clipboard) { done(false)(); return; }
  navigator.clipboard.writeText(text).then(() => done(true)(), () => done(false)());
};

// Fixtures are a developer-only harness, never commands on the operator desk.
export const developerExamples = () => new URLSearchParams(location.search).get('examples') === '1';

// Same split interaction as the JS prototype: 20-80%, pointer and keyboard.
export const installDivider = () => {
  const divider = document.getElementById('divider');
  const split = document.querySelector('.app-main');
  if (!divider || !split || divider.dataset.wired) return;
  divider.dataset.wired = 'true';
  let ratio = .565;
  const set = value => {
    ratio = Math.min(.8, Math.max(.2, value));
    split.style.setProperty('--left', `${ratio / (1 - ratio)}fr`);
    divider.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
    // Existing viewport is retained; next fit measures the resized stage.
  };
  divider.setAttribute('aria-valuemin', '20');
  divider.setAttribute('aria-valuemax', '80');
  divider.addEventListener('pointerdown', e => { divider.setPointerCapture(e.pointerId); divider.classList.add('drag'); });
  divider.addEventListener('pointermove', e => {
    if (!divider.classList.contains('drag')) return;
    const box = split.getBoundingClientRect(); set((e.clientX - box.left) / box.width);
  });
  ['pointerup', 'pointercancel'].forEach(name => divider.addEventListener(name, () => divider.classList.remove('drag')));
  divider.addEventListener('keydown', e => {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
    e.preventDefault(); e.stopPropagation(); set(ratio + (e.key === 'ArrowRight' ? .03 : -.03));
  });
};

export const resetDetailsScroll = () => { const pane = document.querySelector('.details'); if (pane) pane.scrollTop = 0; };
export const shortcutAllowed = () => !document.activeElement?.matches('input,select,textarea,[contenteditable="true"]');

export const compactScreen = () => matchMedia("(max-width: 62rem)").matches;

export const keyboardFocus = () => Boolean(document.activeElement?.matches(":focus-visible"));

export const revealQuestion = () => requestAnimationFrame(() => document.querySelector(".question textarea, .manual-prompt")?.scrollIntoView({block:"nearest"}));
