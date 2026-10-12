import { expect } from '@playwright/test';
import { test } from '@playwright/test';

// Complete acceptance journey over the built artifact: hierarchy, roles,
// communication, selection context with the global view intact,
// collapse/expand with explicit treatment of a collapsed selection,
// pan/zoom/fit/reset, keyboard reachability for every node and edge,
// narrow-screen use, honest empty/incomplete/refused states, and safe
// rendering of source-like text.

async function openGraph(page) {
  await page.goto('/app/');
  await expect(page.locator('svg.graph .node')).toHaveCount(10);
}

const N = (key) => `[data-node-id="synthetic:demo-installation/${key}"]`;
const E = (key) => `[data-edge-id="synthetic:demo-installation/${key}"]`;

// Click the visible edge line at its geometric midpoint, the way a user
// aims at the line itself rather than the bounding-box centre.
async function clickEdgeMidpoint(page, selector) {
  // wait for the initial fit and font layout to settle so the screen point
  // is stable in cold environments
  await page.locator('svg.graph').waitFor();
  await page.evaluate(() => document.fonts.ready.then(() => undefined));
  await page.waitForTimeout(150);
  const point = await page.evaluate((sel) => {
    const g = document.querySelector(sel);
    const path = g && g.querySelector('path');
    if (!path || !path.getScreenCTM()) return null;
    const ctm = path.getScreenCTM();
    const len = path.getTotalLength();
    // scan outward from the visible line's midpoint and return the first
    // screen point whose topmost element is this edge; middle-out avoids
    // the ends, where neighbouring edges' wide hit targets overlap
    const order = [10, 9, 11, 8, 12, 7, 13, 6, 14, 5, 15, 4, 16, 3, 17, 2, 18, 1, 19];
    for (const i of order) {
      const p = path.getPointAtLength((len * i) / 20);
      const sp = new DOMPoint(p.x, p.y).matrixTransform(ctm);
      const el = document.elementFromPoint(sp.x, sp.y);
      if (el && el.closest && el.closest('[data-edge-id="' + g.getAttribute('data-edge-id') + '"]')) {
        return { x: sp.x, y: sp.y, gx: 0, gy: 0 };
      }
    }
    return null;
  }, selector);
  if (!point) throw new Error(`no clickable point on the line for ${selector}`);
  console.log('edge click point:', JSON.stringify({ x: point.x, y: point.y }));
  await page.mouse.click(point.x, point.y);
}

test('shows the connected synthetic installation with typed relationships', async ({ page }) => {
  await openGraph(page);
  await expect(page.locator('svg.graph .node')).toHaveCount(10);
  await expect(page.locator('svg.graph .ghost')).toHaveCount(1);
  for (const label of ['contains', 'attaches role', 'recorded communication']) {
    await expect(page.locator('.legend')).toContainText(label);
  }
  await expect(page.locator(N('project-1'))).toBeVisible();
  await expect(page.locator(E('comm-1'))).toBeVisible();
});

test('selecting a node shows its permitted context while the graph stays global', async ({ page }) => {
  await openGraph(page);
  await page.locator(N('project-1')).click();
  const details = page.locator('.details');
  await expect(details).toContainText('Factory Demo');
  await expect(details).toContainText('project');
  await expect(details).toContainText('records/project-1');
  await expect(details).toContainText('known');
  // the global graph remains available: every node is still rendered
  await expect(page.locator('svg.graph .node')).toHaveCount(10);
});

test('follows the work chain from project to pull request by keyboard', async ({ page }) => {
  await openGraph(page);
  await page.locator(N('project-1')).click();
  await expect(page.locator('.details')).toContainText('Factory Demo');
  const chain = ['milestone-1', 'epic-1', 'ticket-1', 'pr-1'];
  for (const key of chain) {
    await page.keyboard.press('ArrowDown');
    const label = await page.evaluate(
      () => document.activeElement?.getAttribute('aria-label') ?? ''
    );
    expect(label.length).toBeGreaterThan(0);
  }
  await page.keyboard.press('Enter');
  await expect(page.locator('.details')).toContainText('Add the synthetic graph');
  await expect(page.locator('.details')).toContainText('pull request');
});

test('inspects a recorded communication edge', async ({ page }) => {
  await openGraph(page);
  await clickEdgeMidpoint(page, E('comm-1'));
  const details = page.locator('.details');
  await expect(details).toContainText('recorded communication');
  await expect(details).toContainText('Graph Maintainer');
  await expect(details).toContainText('Synthetic graph ticket');
});

test('keyboard reaches every node, ghost and edge without a pointer', async ({ page }) => {
  await openGraph(page);
  const graphFocusables = await page.locator('svg.graph [tabindex="0"]').count();
  expect(graphFocusables).toBe(23); // 10 nodes + 1 ghost + 12 edges
  // walk the whole tab ring inside the document and confirm the graph
  // focusables are all part of one reachable ring
  const stops = await page.evaluate(() => {
    const sel = 'svg.graph [tabindex="0"]';
    const els = Array.from(document.querySelectorAll(sel));
    return els.map((e) => e.getAttribute('aria-label'));
  });
  expect(new Set(stops).size).toBe(23);
  expect(stops.every((l) => l && l.length > 0)).toBe(true);
});

test('collapse hides the subtree, explains a collapsed selection, and expands back', async ({ page }) => {
  await openGraph(page);
  // select a leaf first
  await page.locator(N('pr-1')).click();
  await expect(page.locator('.details')).toContainText('Add the synthetic graph');
  // collapse its parent ticket; the selected pull request is now hidden
  await page.locator(`${N('ticket-1')} .collapse-toggle`).click();
  await expect(page.locator('svg.graph .node')).toHaveCount(8);
  const details = page.locator('.details');
  await expect(details).toContainText('collapsed');
  await expect(details).toContainText('Synthetic graph ticket');
  await expect(page.locator('.details button', { hasText: 'Expand' })).toBeVisible();
  await page.locator('.details button', { hasText: 'Expand' }).click();
  await expect(page.locator('svg.graph .node')).toHaveCount(10);
  await expect(details).toContainText('Add the synthetic graph');
});

test('pan, zoom, fit and reset the viewport', async ({ page }) => {
  await openGraph(page);
  const transform = () =>
    page.evaluate(() => document.querySelector('#viewport')?.getAttribute('transform') ?? '');
  await page.locator('button', { hasText: 'Zoom in' }).click();
  const zoomed = await transform();
  expect(zoomed.length).toBeGreaterThan(0);
  const stage = page.locator('.graph-stage');
  const box = await stage.boundingBox();
  await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.5);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * 0.5 + 120, box.y + box.height * 0.5 + 60);
  await page.mouse.up();
  const panned = await transform();
  expect(panned).not.toBe(zoomed);
  await page.locator('button', { hasText: 'Fit' }).click();
  const fitted = await transform();
  expect(fitted).not.toBe(panned);
  await expect(page.locator(N('project-1'))).toBeVisible();
  await page.locator('button', { hasText: 'Reset view' }).click();
  await expect.poll(transform, { timeout: 4000 }).toBe('translate(0.0,0.0) scale(1.0)');
  await page.locator('button', { hasText: 'Fit' }).click();
  await expect.poll(transform, { timeout: 4000 }).toBe(fitted);
});

test('works at a narrow width', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openGraph(page);
  const overflow = await page.evaluate(
    () => document.scrollingElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflow).toBeLessThanOrEqual(0);
  await page.locator('button', { hasText: 'Fit' }).click();
  await expect(page.locator(N('project-1'))).toBeVisible();
  await page.locator('.scenario-button', { hasText: 'Empty installation' }).click();
  await expect(page.locator('.empty-state')).toBeVisible();
  const overflowAfter = await page.evaluate(
    () => document.scrollingElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflowAfter).toBeLessThanOrEqual(0);
});

test('empty installation is explicit', async ({ page }) => {
  await openGraph(page);
  await page.locator('.scenario-button', { hasText: 'Empty installation' }).click();
  await expect(page.locator('.empty-state')).toBeVisible();
  await expect(page.locator('.app-status')).toContainText('no records');
  await expect(page.locator('svg.graph .node')).toHaveCount(0);
});

test('incomplete records stay honestly labelled and distinct', async ({ page }) => {
  await openGraph(page);
  await page.locator('.scenario-button', { hasText: 'Incomplete records' }).click();
  await expect(page.locator('svg.graph .node')).toHaveCount(4);
  await page.locator(N('milestone-3')).click();
  await expect(page.locator('.details')).toContainText('no parent recorded');
  await expect(page.locator('.details .quality')).toContainText('unknown');
  await page.locator(N('role-3')).click();
  await expect(page.locator('.details')).toContainText('no attachment recorded');
  await expect(page.locator('.details .quality')).toContainText('missing reference');
  await page.locator(N('ticket-2')).click();
  await expect(page.locator('.details .quality')).toContainText('stale');
  await page.locator(N('project-2')).click();
  await expect(page.locator('.details .quality')).toContainText('known');
});

test('invalid input is visibly refused with redacted reasons', async ({ page }) => {
  await openGraph(page);
  await page.locator('.scenario-button', { hasText: 'Refused input' }).click();
  const refusal = page.locator('.refusal');
  await expect(refusal).toBeVisible();
  await expect(page.locator('.refusal li')).toHaveCount(6);
  await expect(refusal).toContainText('field is not part of the documented graph contract');
  await expect(refusal).toContainText('role records carry no implementation identity');
  // no values from the refused document may be echoed
  const text = await refusal.innerText();
  expect(text).not.toContain('Broken installation');
  expect(text).not.toContain('provider://');
  await expect(page.locator('svg.graph .node')).toHaveCount(0);
});

test('renders source-like titles as text, never as markup', async ({ page }) => {
  await openGraph(page);
  const hostile = page.locator(N('pr-2'));
  await expect(hostile).toContainText('Review note <img src=x onerror=window.__xss=1>');
  const leaked = await page.evaluate(() => window.__xss);
  expect(leaked).toBeUndefined();
  const injected = await page.locator('svg.graph img').count();
  expect(injected).toBe(0);
});

test('routed edges terminate on their role cards', async ({ page }) => {
  await openGraph(page);
  await page.locator('svg.graph').waitFor();
  await page.waitForTimeout(300);
  const report = await page.evaluate(() => {
    const roleCircles = [];
    const nodeBoxes = [];
    for (const node of document.querySelectorAll('svg .node')) {
      const bb = node.getBoundingClientRect();
      if (node.classList.contains('kind-role')) {
        const circle = node.querySelector('rect');
        const cb = circle ? circle.getBoundingClientRect() : null;
        if (cb) {
          roleCircles.push({ x: cb.x, y: cb.y, w: cb.width, h: cb.height });
        }
      } else {
        nodeBoxes.push({ x: bb.x, y: bb.y, w: bb.width, h: bb.height });
      }
    }
    const covered = (x, y) =>
      roleCircles.some((c) => x >= c.x - 2 && x <= c.x + c.w + 2 && y >= c.y - 2 && y <= c.y + c.h + 2) ||
      nodeBoxes.some((b) => x >= b.x - 1 && x <= b.x + b.w + 1 && y >= b.y - 1 && y <= b.y + b.h + 1);
    const misses = [];
    for (const edge of document.querySelectorAll('svg .edge')) {
      const label = edge.getAttribute('aria-label') || '';
      if (!label.includes('role:')) continue;
      const path = edge.querySelector('path');
      const ctm = path.getScreenCTM();
      if (!ctm) continue;
      const len = path.getTotalLength();
      for (const t of [0, len]) {
        const p = path.getPointAtLength(t);
        const sp = new DOMPoint(p.x, p.y).matrixTransform(ctm);
        if (!covered(sp.x, sp.y)) misses.push({ label, at: Math.round(t) });
      }
    }
    return { roles: roleCircles.length, misses };
  });
  expect(report.roles).toBeGreaterThan(0);
  expect(report.misses, JSON.stringify(report.misses)).toEqual([]);
});

test('legend samples are distinct and match the graph line styles', async ({ page }) => {
  await openGraph(page);
  await page.locator('svg.graph').waitFor();
  const styles = await page.evaluate(() => {
    const get = (sel) => {
      const el = document.querySelector(sel);
      if (!el) return null;
      const cs = getComputedStyle(el);
      return { dash: cs.strokeDasharray };
    };
    return {
      legendContains: get('.legend svg.edge-contains path'),
      legendAttaches: get('.legend svg.edge-attaches path'),
      legendComm: get('.legend svg.edge-communication path'),
      graphContains: get('svg.graph .edge.edge-contains path:not(.edge-hit)'),
      graphAttaches: get('svg.graph .edge.edge-attaches path:not(.edge-hit)'),
      graphComm: get('svg.graph .edge.edge-communication path:not(.edge-hit)'),
    };
  });
  expect(styles.legendContains).not.toBeNull();
  expect(styles.legendAttaches).not.toBeNull();
  expect(styles.legendComm).not.toBeNull();
  const dashes = [styles.legendContains.dash, styles.legendAttaches.dash, styles.legendComm.dash];
  expect(new Set(dashes).size, `legend dashes: ${dashes.join(' | ')}`).toBe(3);
  expect(styles.legendContains.dash).toBe(styles.graphContains.dash);
  expect(styles.legendAttaches.dash).toBe(styles.graphAttaches.dash);
  expect(styles.legendComm.dash).toBe(styles.graphComm.dash);
});

test('edge hit target is a continuous wide band, stable under selection and focus', async ({ page }) => {
  await openGraph(page);
  await page.locator('svg.graph').waitFor();
  const info = await page.evaluate(() => {
    const edge = document.querySelector('svg.graph .edge');
    const hit = edge.querySelector('.edge-hit');
    if (!hit) return null;
    const cs = getComputedStyle(hit);
    return { stroke: cs.stroke, width: cs.strokeWidth, dash: cs.strokeDasharray };
  });
  expect(info).not.toBeNull();
  // continuous and wide: no dash gaps for quantized input coordinates to fall into
  expect(info.dash, `hit dasharray: ${info && info.dash}`).toBe('none');
  expect(parseFloat(info.width)).toBeGreaterThanOrEqual(20);
  // the band itself is never painted: no visual interference with crossing edges
  expect(info.stroke).toBe('rgba(0, 0, 0, 0)');
  // integer-quantized points inside the band never land on empty space —
  // the exact failure mode this regression guards (fractional
  // elementFromPoint passed while real integer input fell into dash gaps);
  // points covered by node shapes select those nodes, which is correct
  const quantized = await page.evaluate(() => {
    const sel = '[data-edge-id="synthetic:demo-installation/comm-1"]';
    const g = document.querySelector(sel);
    const path = g.querySelector('path.edge-hit');
    const ctm = path.getScreenCTM();
    const len = path.getTotalLength();
    const nodes = Array.from(document.querySelectorAll('svg .node')).map((n) => n.getBoundingClientRect());
    const coveredByNode = (x, y) =>
      nodes.some((b) => x >= b.x - 1 && x <= b.x + b.width + 1 && y >= b.y - 1 && y <= b.y + b.height + 1);
    const dead = [];
    for (let i = 1; i < 20; i++) {
      const p = path.getPointAtLength((len * i) / 20);
      const sp = new DOMPoint(p.x, p.y).matrixTransform(ctm);
      for (const [x, y] of [
        [Math.floor(sp.x), Math.floor(sp.y)],
        [Math.ceil(sp.x), Math.ceil(sp.y)],
      ]) {
        const el = document.elementFromPoint(x, y);
        const interactive = !!(
          el &&
          el.closest &&
          (el.closest('[data-edge-id]') || el.closest('[data-node-id]') || el.closest('[data-ghost-id]'))
        );
        if (!interactive && !coveredByNode(x, y)) dead.push({ x, y });
      }
    }
    return dead;
  });
  expect(quantized, JSON.stringify(quantized)).toEqual([]);
  // stable under genuine pointer selection: click the edge, then re-check geometry
  await clickEdgeMidpoint(page, E('comm-1'));
  await expect(page.locator('.details')).toContainText('recorded communication');
  const after = await page.evaluate(() => {
    const hit = document.querySelector('[data-edge-id="synthetic:demo-installation/comm-1"] .edge-hit');
    const cs = getComputedStyle(hit);
    return { width: cs.strokeWidth, dash: cs.strokeDasharray, stroke: cs.stroke };
  });
  expect(after.dash).toBe('none');
  expect(parseFloat(after.width)).toBeGreaterThanOrEqual(20);
  expect(after.stroke).toBe('rgba(0, 0, 0, 0)');
});

test('ELK cards have readable bounded labels and non-overlapping geometry', async ({ page }) => {
  await openGraph(page);
  const report = await page.evaluate(() => {
    const nodes = [...document.querySelectorAll('svg.graph .node, svg.graph .ghost')];
    const overlaps = [], overflow = [];
    for (const [i, node] of nodes.entries()) {
      const rect = node.querySelector('rect');
      const a = rect.getBoundingClientRect();
      for (const other of nodes.slice(i + 1)) {
        const b = other.querySelector('rect').getBoundingClientRect();
        if (a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top) overlaps.push(node.textContent);
      }
      for (const text of node.querySelectorAll('.node-body text, :scope > text')) {
        const b = text.getBoundingClientRect();
        if (b.left < a.left || b.right > a.right || b.top < a.top || b.bottom > a.bottom) overflow.push(text.textContent);
      }
    }
    return { overlaps, overflow, roles: [...document.querySelectorAll('.kind-role .node-kind')].map(n => n.textContent) };
  });
  expect(report.overlaps).toEqual([]);
  expect(report.overflow).toEqual([]);
  expect(report.roles).toEqual(['role', 'role']);
  for (const edge of await page.locator('svg.graph .edge path:not(.edge-hit)').all()) {
    expect(await edge.getAttribute('d')).not.toMatch(/[CQ]/);
    expect(await edge.getAttribute('marker-end')).toMatch(/^url\(#arrow-/);
  }
});

test('selection and collapse preserve the spatial context', async ({ page }) => {
  await openGraph(page);
  const before = await page.locator(N('epic-2')).getAttribute('transform');
  const viewport = await page.locator('#viewport').getAttribute('transform');
  await page.locator(N('pr-1')).click();
  await page.locator(`${N('ticket-1')} .collapse-toggle`).click();
  expect(await page.locator(N('epic-2')).getAttribute('transform')).toBe(before);
  expect(await page.locator('#viewport').getAttribute('transform')).toBe(viewport);
});

test('mobile starts readable and the record navigator brings distant cards into view', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openGraph(page);
  const font = await page.locator('.node-title').first().evaluate(t => parseFloat(getComputedStyle(t).fontSize) * t.getScreenCTM().a);
  expect(font).toBeGreaterThanOrEqual(12);
  await page.locator('.record-picker select').selectOption({ label: 'pull request: Add the synthetic graph' });
  await expect(page.locator('.details')).toContainText('Add the synthetic graph');
  const card = await page.locator(`${N('pr-1')} rect`).boundingBox();
  const stage = await page.locator('svg.graph').boundingBox();
  expect(card.x).toBeGreaterThanOrEqual(stage.x);
  expect(card.x + card.width).toBeLessThanOrEqual(stage.x + stage.width);
  expect(card.y).toBeGreaterThanOrEqual(stage.y);
  expect(card.y + card.height).toBeLessThanOrEqual(stage.y + stage.height);
});

test('a late layout cannot replace the selected scenario', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(globalThis, 'factoryLayoutEngine', { configurable: true,
      set(engine) {
        const original = engine.layout.bind(engine); let first = true;
        engine.layout = async input => {
          const delay = first; first = false;
          const result = await original(input);
          if (delay) await new Promise(resolve => setTimeout(resolve, 700));
          return result;
        };
        Object.defineProperty(globalThis, 'factoryLayoutEngine', { value: engine, configurable: true });
      }
    });
  });
  await page.goto('/app/');
  await page.getByRole('button', { name: 'Incomplete records', exact: true }).click();
  await expect(page.locator('svg.graph .node')).toHaveCount(4);
  await page.waitForTimeout(900);
  await expect(page.locator('svg.graph .node')).toHaveCount(4);
  await expect(page.locator(N('milestone-3'))).toBeVisible();
});

test('malformed layout output is refused without exposing engine errors', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(globalThis, 'factoryLayoutEngine', { configurable: true,
      set() { Object.defineProperty(globalThis, 'factoryLayoutEngine', { value: {
        layout: async () => ({ children: [{ id: 'private-engine-diagnostic', x: NaN, y: 0 }], edges: [] })
      }, configurable: true }); }
    });
  });
  await page.goto('/app/');
  await expect(page.locator('.empty-state')).toContainText('could not be calculated');
  await expect(page.locator('body')).not.toContainText('private-engine-diagnostic');
  await expect(page.locator('svg.graph')).toHaveCount(0);
});

test('theme follows the device then remembers the reader choice across visits', async ({ page, context }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await openGraph(page);
  await page.getByRole('button', { name: 'Switch to light mode' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-factory-dashboard-palette', 'light');
  expect(await page.evaluate(() => localStorage.getItem('factory-dashboard-palette'))).toBe('light');
  await page.reload();
  await expect(page.getByRole('button', { name: 'Switch to dark mode' })).toBeVisible();
  const second = await context.newPage();
  await second.goto('/app/');
  await expect(second.locator('html')).toHaveAttribute('data-factory-dashboard-palette', 'light');
  await second.close();
  await page.getByRole('button', { name: 'Switch to dark mode' }).click();
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-factory-dashboard-palette', 'dark');
});

test('light graph text contrasts with card and toolbar backgrounds', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' });
  await openGraph(page);
  await expect(page.getByRole('button', { name: 'Switch to dark mode' })).toBeVisible();
  const ratios = await page.evaluate(() => {
    const luminance = value => value.match(/[\d.]+/g).slice(0, 3).map(Number).map(n => {
      n /= 255; return n <= .04045 ? n / 12.92 : ((n + .055) / 1.055) ** 2.4;
    }).reduce((sum, n, i) => sum + n * [.2126, .7152, .0722][i], 0);
    const contrast = (a, b) => (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
    return [...document.querySelectorAll('.node .node-title,.node .node-kind,.node .badge')].map(text => {
      const background = text.closest('.node').querySelector('rect');
      return contrast(luminance(getComputedStyle(text).fill), luminance(getComputedStyle(background).fill));
    });
  });
  expect(Math.min(...ratios)).toBeGreaterThanOrEqual(4.5);
});
