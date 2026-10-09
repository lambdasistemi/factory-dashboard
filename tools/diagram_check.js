/* Mechanical check of rendered Mermaid diagrams. Visual inspection is also required. */
(doc => {
  const out = [];
  const R = e => e.getBoundingClientRect();
  const hit = (a, b, tol = 2) => {
    const ix = Math.min(a.right, b.right) - Math.max(a.left, b.left);
    const iy = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
    return ix > tol && iy > tol && ix * iy >= 0.25 * Math.min(a.width * a.height, b.width * b.height);
  };
  [...doc.querySelectorAll(".mermaid")].forEach((n, i) => {
    const svg = n.querySelector("svg");
    const rec = { index: i, problems: [] };
    if (!svg) { rec.problems.push("not rendered"); out.push(rec); return; }
    const width = R(svg).width, column = n.clientWidth;
    if (width > column + 4) rec.problems.push(`wider than its column (${Math.round(width)} > ${column})`);
    const boxes = [];
    svg.querySelectorAll("text, foreignObject").forEach(t => {
      const text = (t.textContent || "").trim();
      if (!text || (t.tagName === "text" && t.closest("foreignObject"))) return;
      const r = R(t);
      if (r.width && r.height) boxes.push({ el: t, r, text, owner: t.closest("g.node, g.edgeLabel, g.cluster, g.actor, g.label") });
    });
    const shapes = [...svg.querySelectorAll("g.node rect, g.node polygon, g.node circle, g.node path.label-container")]
      .map(s => ({ el: s, r: R(s), owner: s.closest("g.node") }));
    const seen = new Set();
    for (let a = 0; a < boxes.length; a++) for (let b = a + 1; b < boxes.length; b++) {
      const A = boxes[a], B = boxes[b];
      if (A.owner && A.owner === B.owner) continue;
      if (hit(A.r, B.r)) {
        const key = A.text + "|" + B.text;
        if (!seen.has(key)) { seen.add(key); rec.problems.push(`labels overlap: "${A.text.slice(0, 40)}" / "${B.text.slice(0, 40)}"`); }
      }
    }
    for (const A of boxes.filter(x => x.owner && x.owner.matches("g.edgeLabel, g.label"))) for (const S of shapes) {
      if (S.owner && A.owner && S.owner.contains(A.el)) continue;
      if (hit(A.r, S.r, 4)) rec.problems.push(`label over a node shape: "${A.text.slice(0, 40)}"`);
    }
    out.push(rec);
  });
  return out.filter(r => r.problems.length);
})
