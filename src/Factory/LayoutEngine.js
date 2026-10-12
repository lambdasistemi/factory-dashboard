// Geometry-only adapter; callbacks never receive raw engine errors or input values.
export const calculateImpl = input => success => failure => () => {
  const fail = () => failure('The graph layout could not be calculated. Try another scenario or reload.')();
  try {
    globalThis.factoryLayoutEngine.layout({
      id: 'root',
      layoutOptions: {
        'elk.algorithm': 'layered', 'elk.direction': 'RIGHT',
        'elk.edgeRouting': 'ORTHOGONAL', 'elk.randomSeed': '1',
        'elk.layered.spacing.nodeNodeBetweenLayers': '80',
        'elk.spacing.nodeNode': '44', 'elk.spacing.edgeNode': '24',
        'elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES'
      },
      children: input.nodes, edges: input.edges
    }).then(result => {
      const finite = v => Number.isFinite(v) && Math.abs(v) <= 10000000;
      const expected = new Set(input.nodes.map(n => n.id));
      if (!Array.isArray(result.children) || result.children.length !== expected.size) throw Error('nodes');
      const nodes = result.children.map(n => {
        if (!expected.delete(n.id) || !finite(n.x) || !finite(n.y)) throw Error('node');
        return { id:n.id, x:n.x, y:n.y };
      });
      const expectedEdges = new Set(input.edges.map(e => e.id));
      if (!Array.isArray(result.edges) || result.edges.length !== expectedEdges.size) throw Error('edges');
      const edges = result.edges.map(e => {
        if (!expectedEdges.delete(e.id) || !Array.isArray(e.sections) || !e.sections.length) throw Error('edge');
        const path=e.sections.map(section => {
          const points=[section.startPoint,...(section.bendPoints || []),section.endPoint];
          if (!points.every(p => p && finite(p.x) && finite(p.y))) throw Error('point');
          return points.map((p,i) => (i ? 'L' : 'M')+p.x+' '+p.y).join(' ');
        }).join(' ');
        return { id:e.id,path };
      });
      success({nodes,edges})();
    }).catch(fail);
  } catch (_) { fail(); }
};
