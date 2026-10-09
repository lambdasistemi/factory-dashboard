(() => {
  const selector = ".mermaid";
  const isDark = () => document.documentElement.dataset.factoryDashboardPalette === "dark";

  async function renderDiagrams() {
    if (!window.mermaid) return;
    const diagrams = [...document.querySelectorAll(selector)];
    if (diagrams.length === 0) return;

    const dark = isDark();
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: "base",
      themeVariables: {
        background: "transparent",
        primaryColor: dark ? "#1f2937" : "#ffffff",
        primaryTextColor: dark ? "#f8fafc" : "#111827",
        primaryBorderColor: dark ? "#94a3b8" : "#475569",
        lineColor: dark ? "#cbd5e1" : "#334155",
        secondaryColor: dark ? "#172554" : "#dbeafe",
        tertiaryColor: dark ? "#334155" : "#f1f5f9",
        edgeLabelBackground: dark ? "#111827" : "#ffffff",
        clusterBkg: dark ? "#0f172a" : "#f8fafc",
        clusterBorder: dark ? "#64748b" : "#94a3b8"
      },
      flowchart: { curve: "linear", useMaxWidth: true }
    });

    for (const diagram of diagrams) {
      if (!diagram.dataset.source) diagram.dataset.source = diagram.textContent;
      diagram.removeAttribute("data-processed");
      diagram.textContent = diagram.dataset.source;
    }
    await window.mermaid.run({ nodes: diagrams });
  }

  document.addEventListener("DOMContentLoaded", renderDiagrams);
  window.addEventListener("factory-dashboard-palette-change", renderDiagrams);
})();
