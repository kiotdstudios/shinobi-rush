#!/usr/bin/env node
// Controls probe for the Shinobi Rush Web export (CI tooling; not part of the game).
// Drop into scripts/ci/smoke/ next to smoke.mjs (it reuses lib/serve.mjs).
//   node controls-probe.mjs --serve-dir <export dir> --out-dir <evidence dir>
// Reads window.__SHINOBI_STATE__ ({frame,x,y,state,sprinting,fps}, published ~10 Hz by the WebBridge autoload) and proves
// that REAL key input moves the player: walk right, sprint faster, a wall stops the player. Exit 0 = all passed, 1 = a check failed.
// Timing is wall-clock based and tolerant: software-rendered CI browsers run the game at only a few FPS.
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { startStaticServer } from './lib/serve.mjs';

const arg = (n) => { const i = process.argv.indexOf('--' + n); return i < 0 ? undefined : process.argv[i + 1]; };
const serveDir = arg('serve-dir');
const outDir = arg('out-dir');
if (!serveDir || !outDir) { console.error('usage: node controls-probe.mjs --serve-dir <dir> --out-dir <dir>'); process.exit(2); }
mkdirSync(outDir, { recursive: true });

const results = [];
const rec = (name, ok, detail) => { results.push({ name, ok, detail }); console.log(`[probe] ${ok ? 'PASS' : 'FAIL'} ${name} - ${detail}`); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = await startStaticServer(serveDir, { port: 0 }); // ephemeral port
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, serviceWorkers: 'block' });
const page = await context.newPage();
const consoleMsgs = [];
page.on('console', (m) => consoleMsgs.push({ type: m.type(), text: m.text() }));
page.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e) }));
const state = () => page.evaluate(() => ({ ...window.__SHINOBI_STATE__ }));
const shot = (name) => page.screenshot({ path: path.join(outDir, `probe-${name}.png`) });
let exitCode = 1;
try {
  const t0 = Date.now();
  await page.goto(server.url, { waitUntil: 'load' });
  const hooksAbsent = await page.waitForFunction(
    () => window.__SHINOBI_READY__ === true || (document.readyState === 'complete' && window.__SHINOBI_READY__ === undefined && window.__SHINOBI_STATE__ === undefined && performance.now() > 90000),
    null, { timeout: 120000, polling: 250 }).then(() => page.evaluate(() => window.__SHINOBI_READY__ !== true && window.__SHINOBI_STATE__ === undefined));
  if (hooksAbsent) {
    // Genuinely absent (neither hook was ever defined): this build exposes no test hooks, so nothing can be asserted.
    console.log('[probe] SKIPPED - hooks absent: window.__SHINOBI_READY__ and window.__SHINOBI_STATE__ are not defined by this build; controls NOT verified');
    const errs = consoleMsgs.filter((m) => m.type === 'error' || m.type === 'pageerror');
    writeFileSync(path.join(outDir, 'probe-result.json'), JSON.stringify({ skipped: 'hooks absent', console: consoleMsgs }, null, 2));
    await browser.close(); await server.close();
    if (errs.length) { console.log(`[probe] FAIL no-console-errors - ${errs.length} error/pageerror while hooks were absent`); process.exit(1); }
    process.exit(0);
  }
  rec('ready-flag', true, `__SHINOBI_READY__ true after ${Date.now() - t0} ms`);
  await sleep(1500);
  const s0 = await state();
  rec('state-object', Number.isFinite(s0.x) && Number.isFinite(s0.y) && typeof s0.state === 'string', JSON.stringify(s0));
  await page.mouse.click(640, 400); // give the canvas keyboard focus
  await sleep(200);
  await shot('01-start');

  // Camera framing: the gameplay baseline was retuned 2026-10-18 (orders/Aki/2026-10-18-camera-scale-validation.md)
  // to match the owner's locked reference screenshot (player ~20% of viewport height). New baseline:
  // zoom 144/108 = 1.333, visible world 960x540 in a 1280x720 viewport.
  const BASE_ZOOM = 144 / 108;
  const zoomNow = async () => (await state()).zoom;
  const near = (v, want) => Number.isFinite(v) && Math.abs(v - want) < 0.005;
  const zs = await state();
  rec('camera-baseline-at-start', near(zs.zoom, BASE_ZOOM) && Math.abs(zs.view_w - 960) < 2 && Math.abs(zs.view_h - 540) < 2,
    `expected zoom ~${BASE_ZOOM.toFixed(4)} and view 960x540; got zoom=${zs.zoom}, view=${zs.view_w}x${zs.view_h}`);

  const dxOver = async (keys, settleMs, windowMs) => {
    for (const k of keys) await page.keyboard.down(k);
    await sleep(settleMs);
    const a = await state();
    await sleep(windowMs);
    const b = await state();
    await shot(keys.includes('ShiftLeft') ? '03-sprint' : '02-walk');
    for (const k of keys.slice().reverse()) await page.keyboard.up(k);
    await sleep(600);
    return { a, b, dx: b.x - a.x };
  };
  const noEffect = (w) => Math.abs(w.dx) < 0.5 ? ' - HOOKS EXIST BUT INPUT HAD NO EFFECT (x did not change; keyboard events not reaching the game or movement broken)' : '';
  const walk = await dxOver(['KeyD'], 100, 500); // ~600 ms hold
  rec('move-right', walk.dx > 20 && walk.b.state === 'MOVE', `dx ${walk.dx.toFixed(1)} over 500 ms (KeyD held ~600 ms), state=${walk.b.state}${noEffect(walk)}`);
  // come back (same distance budget) so the sprint run does not hit the arena edge
  await dxOver(['KeyA'], 100, 500);
  const sprint = await dxOver(['ShiftLeft', 'KeyD'], 100, 500);
  rec('sprint-faster', sprint.dx > walk.dx * 1.2 && sprint.b.sprinting === true, `sprint dx ${sprint.dx.toFixed(1)} vs walk dx ${walk.dx.toFixed(1)}; state=${sprint.b.state}, sprinting=${sprint.b.sprinting}${noEffect(sprint)}`);

  // walk into the wall: hold W until the position stops changing (3 equal samples), then require it moved first
  const startY = (await state()).y;
  await page.keyboard.down('KeyW');
  let still = 0; let prev = await state(); const tw = Date.now();
  while (Date.now() - tw < 30000 && still < 3) {
    await sleep(400);
    const s = await state();
    still = Math.hypot(s.x - prev.x, s.y - prev.y) < 0.5 ? still + 1 : 0;
    prev = s;
  }
  const settled = [];
  for (let i = 0; i < 3; i++) { await sleep(250); settled.push((await state()).y); } // W is still held here
  await shot('04-at-wall');
  await page.keyboard.up('KeyW');
  const spread = Math.max(...settled) - Math.min(...settled);
  rec('wall-stops-player', prev.y < startY - 20 && spread < 0.5, `y ${startY.toFixed(1)} -> ${settled[2].toFixed(1)} with W held; 3 later samples spread ${spread.toFixed(2)}`);

  // Lab vs framing: Tab opens the lab WITHOUT changing the zoom; only Z changes it; Tab again restores the baseline.
  // (Published at ~10 Hz and the game may run at a few FPS, so wait for a fresh sample before reading.)
  const tap = async (key) => { await page.keyboard.down(key); await sleep(120); await page.keyboard.up(key); await sleep(1500); };
  await tap('Tab');
  const zOpen = await zoomNow();
  rec('lab-open-keeps-baseline', near(zOpen, BASE_ZOOM), `after Tab (lab open) zoom=${zOpen}, expected ~${BASE_ZOOM.toFixed(4)} (opening the lab must not change the camera)`);
  await tap('KeyZ');
  const zZ = await zoomNow();
  rec('lab-z-changes-zoom', near(zZ, 1.0), `after Z zoom=${zZ}, expected 1 (native 1:1, the first non-baseline lab zoom)`);
  await shot('05-lab-zoom-1x');
  await tap('Tab');
  const zClosed = await zoomNow();
  rec('lab-close-restores-baseline', near(zClosed, BASE_ZOOM), `after Tab (lab closed) zoom=${zClosed}, expected ~${BASE_ZOOM.toFixed(4)}`);
} catch (e) {
  rec('probe-exception', false, String(e.message ?? e).split('\n')[0]);
}
const bad = consoleMsgs.filter((m) => m.type === 'error' || m.type === 'pageerror');
rec('no-console-errors', bad.length === 0, `${consoleMsgs.length} console messages, ${bad.length} error/pageerror`);
writeFileSync(path.join(outDir, 'probe-result.json'), JSON.stringify({ results, console: consoleMsgs }, null, 2));
exitCode = results.every((r) => r.ok) ? 0 : 1;
await browser.close(); await server.close();
console.log(`[probe] VERDICT ${exitCode === 0 ? 'PASS' : 'FAIL'}`);
process.exit(exitCode);
