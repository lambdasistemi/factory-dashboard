/* Follow the device preference until the reader chooses a palette. */
(() => {
  const system = window.matchMedia("(prefers-color-scheme: dark)");
  let choice;
  try {
    choice = localStorage.getItem("factory-dashboard-palette");
  } catch (_) {
    /* Storage is optional. */
  }

  const isDark = () => choice === "dark" || (choice !== "light" && system.matches);
  const apply = () => {
    const dark = isDark();
    document.documentElement.dataset.factoryDashboardPalette = dark ? "dark" : "light";
    document.documentElement.style.colorScheme = dark ? "dark" : "light";

    const darkStylesheet = document.getElementById("factory-dashboard-dark-palette");
    if (darkStylesheet) darkStylesheet.media = dark ? "all" : "not all";

    const button = document.getElementById("factory-dashboard-palette-toggle");
    if (button) {
      button.innerHTML = dark
        ? '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2m0 16v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2 12h2m16 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42"></path></svg>'
        : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20.5 15.5A8.5 8.5 0 0 1 8.5 3.5 8.5 8.5 0 1 0 20.5 15.5Z"></path></svg>';
      button.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
      button.title = dark ? "Switch to light mode" : "Switch to dark mode";
      button.hidden = false;
    }

    window.dispatchEvent(new CustomEvent("factory-dashboard-palette-change", { detail: { dark } }));
  };

  apply();
  system.addEventListener("change", () => {
    if (choice !== "light" && choice !== "dark") apply();
  });

  document.addEventListener("DOMContentLoaded", () => {
    apply();
    const button = document.getElementById("factory-dashboard-palette-toggle");
    if (button) {
      button.addEventListener("click", () => {
        choice = isDark() ? "light" : "dark";
        try {
          localStorage.setItem("factory-dashboard-palette", choice);
        } catch (_) {
          /* Storage is optional. */
        }
        apply();
      });
    }

    const navigation = document.getElementById("factory-dashboard-navigation");
    if (navigation) {
      const wide = window.matchMedia("(min-width: 70em)");
      navigation.open = wide.matches;
      wide.addEventListener("change", () => {
        navigation.open = wide.matches;
      });
    }
  });
})();
