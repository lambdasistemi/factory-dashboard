import { expect } from '@playwright/test';
import { test } from '@playwright/test';

// Local-only request boundary over the built artifact. Every request the
// page makes — under every scenario and interaction, including a post-load
// window — must stay on the serving origin and inside the known asset set.
// A deliberately mutated copy of the page (with one injected external
// fetch) must be flagged by the same detector, proving the instrument can
// fail. Service workers and web workers must never be requested.

const LOCAL = 'http://127.0.0.1:4173';
const KNOWN_ASSETS = new Set(['/app/', '/app/index.html', '/app/index.js']);

function tracker(context) {
  const requests = [];
  context.on('request', (r) => requests.push(r.url()));
  return requests;
}

test('the page makes no requests beyond its own static assets', async ({ context, page }) => {
  const requests = tracker(context);
  await page.goto('/app/');
  await page.locator(N('project-1')).click();
  await page.locator('button', { hasText: 'Zoom in' }).click();
  await page.locator('button', { hasText: 'Fit' }).click();
  await page.locator('.scenario-button', { hasText: 'Incomplete records' }).click();
  await page.locator(N('ticket-2')).click();
  await page.locator('.scenario-button', { hasText: 'Empty installation' }).click();
  await page.locator('.scenario-button', { hasText: 'Refused input' }).click();
  await page.locator('.scenario-button', { hasText: 'Complete installation' }).click();
  await page.locator(N('project-1')).click().catch(() => {});
  // post-load quiet window: nothing may phone home after interactions
  await page.waitForTimeout(1200);
  const foreign = requests.filter((u) => !u.startsWith(LOCAL));
  const unknownAssets = requests.filter(
    (u) => u.startsWith(LOCAL) && !KNOWN_ASSETS.has(new URL(u).pathname)
  );
  expect(foreign, `non-local requests: ${foreign.join(', ')}`).toEqual([]);
  expect(unknownAssets, `unknown local assets: ${unknownAssets.join(', ')}`).toEqual([]);
  expect(context.serviceWorkers()).toEqual([]);
  expect(page.workers()).toEqual([]);
});

test('no worker scripts or websocket connections are opened', async ({ context, page }) => {
  const sockets = [];
  page.on('websocket', (ws) => sockets.push(ws.url()));
  await page.goto('/app/');
  await page.locator('.scenario-button', { hasText: 'Incomplete records' }).click();
  await page.waitForTimeout(500);
  expect(sockets).toEqual([]);
  expect(page.workers()).toEqual([]);
});

// Instrument falsification: the same detector must flag a seeded forbidden
// request. The mutated page is a harness artifact, never product output.
test('detector flags a seeded external request on the mutated copy', async ({ context, page }) => {
  const requests = tracker(context);
  await page.goto('/mutated/');
  await page.waitForTimeout(800);
  const foreign = requests.filter((u) => !u.startsWith(LOCAL));
  console.log('detector observed foreign requests:', JSON.stringify(foreign));
  expect(foreign, 'the detector must observe the seeded external request').toEqual(['https://example.invalid/beacon']);
});

const N = (key) => `[data-node-id="synthetic:demo-installation/${key}"]`;
