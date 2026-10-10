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
