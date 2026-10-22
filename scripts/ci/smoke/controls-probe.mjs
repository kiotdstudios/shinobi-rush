#!/usr/bin/env node
// Controls probe for the Shinobi Rush Web export (CI tooling; not part of the game).
// Drop into scripts/ci/smoke/ next to smoke.mjs (it reuses lib/serve.mjs).
//   node controls-probe.mjs --serve-dir <export dir> --out-dir <evidence dir>
// Reads window.__SHINOBI_STATE__ ({frame,x,y,state,sprinting,fps}, published ~10 Hz by the WebBridge autoload) and proves
// that REAL key input moves the player: walk right, sprint faster, a wall stops the player. It also drives the camera-impact lab demo keys
// and reads the cfx_* telemetry. Exit 0 = all passed, 1 = a check failed.
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

  // Camera framing: the gameplay baseline is the wide view (zoom 1/2.25, visible world 2880x1620 in a 1280x720 viewport).
  const BASE_ZOOM = 1 / 2.25;
  const zoomNow = async () => (await state()).zoom;
  const near = (v, want) => Number.isFinite(v) && Math.abs(v - want) < 0.005;
  const zs = await state();
  rec('camera-preset-default-is-wide', zs.camera_preset === 'wide', `no ?camera= parameter: state.camera_preset=${JSON.stringify(zs.camera_preset)}, expected "wide"`);
  rec('camera-baseline-at-start', near(zs.zoom, BASE_ZOOM) && Math.abs(zs.view_w - 2880) < 2 && Math.abs(zs.view_h - 1620) < 2,
    `expected zoom ~${BASE_ZOOM.toFixed(4)} and view 2880x1620; got zoom=${zs.zoom}, view=${zs.view_w}x${zs.view_h}`);

  const dxOver = async (keys, settleMs, windowMs) => {
    for (const k of keys) await page.keyboard.down(k);
    await sleep(settleMs);
    const a = await state();
    await sleep(windowMs);
    const b = await state();
    await shot(keys.includes('ShiftLeft') ? '03-sprint' : '02-walk');
    for (const k of keys.slice().reverse()) await page.keyboard.up(k);
    await sleep(600);
    const ticks = b.physics_frame - a.physics_frame;
    return { a, b, dx: b.x - a.x, speed: ticks > 0 ? (b.x - a.x) * 60 / ticks : NaN };
  };
  const noEffect = (w) => Math.abs(w.dx) < 0.5 ? ' - HOOKS EXIST BUT INPUT HAD NO EFFECT (x did not change; keyboard events not reaching the game or movement broken)' : '';
  const walk = await dxOver(['KeyD'], 300, 700); // settle then measure using simulation-frame timestamps
  rec('move-right', walk.dx > 20 && walk.b.state === 'MOVE', `dx ${walk.dx.toFixed(1)} over a700ms sample (KeyD held ~1000ms), state=${walk.b.state}${noEffect(walk)}`);
  // come back (same distance budget) so the sprint run does not hit the arena edge
  await dxOver(['KeyA'], 100, 500);
  const sprint = await dxOver(['ShiftLeft', 'KeyD'], 300, 700);
  rec('sprint-faster', sprint.dx > 20 && sprint.speed > walk.speed * 1.2 && sprint.b.sprinting === true, `sprint ${sprint.speed.toFixed(1)}px/physics-sec vs walk ${walk.speed.toFixed(1)}px/physics-sec; state=${sprint.b.state}, sprinting=${sprint.b.sprinting}${noEffect(sprint)}`);

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
  await tap('KeyZ');
  const zZ2 = await zoomNow();
  rec('lab-z-second-step-is-half', near(zZ2, 1.5), `after a second Z zoom=${zZ2}, expected 1.5 (the lab list is baseline, 1, 1.5, 2, 2.5, 3, 3.5, 4)`);
  await tap('Tab');
  const zClosed = await zoomNow();
  rec('lab-close-restores-baseline', near(zClosed, BASE_ZOOM), `after Tab (lab closed) zoom=${zClosed}, expected ~${BASE_ZOOM.toFixed(4)}`);

  // Actual accepted one-shot assets must also load in the in-game review lab.
  if ((await state()).sprite_set_id === 'player_128') {
    await tap('Tab');
    for (const target of ['jump', 'dodge']) {
      for (let i = 0; i < 8 && (await state()).lab_animation !== target; i++) await tap('Period');
      rec(`lab-${target}-available`, (await state()).lab_animation === target, `selected ${(await state()).lab_animation}`);
      await shot(`lab-${target}`);
    }
    await tap('Tab');
  }

  // Camera preset from the URL (PROVISIONAL close-combat framing). The default run above stays wide; here each query gets a fresh page.
  // close uses the loaded figure height, including real sprite sets rather than only the placeholder.
  await page.goto('about:blank'); // free the CPU of the finished page before booting another copy of the game

  const cameraPage = async (query, tag) => {
    const p = await context.newPage();
    p.on('console', (m) => consoleMsgs.push({ type: m.type(), text: m.text() }));
    p.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e) }));
    try {
      await p.goto(server.url + query, { waitUntil: 'load' });
      await p.waitForFunction(() => window.__SHINOBI_READY__ === true && window.__SHINOBI_STATE__ && typeof window.__SHINOBI_STATE__.camera_preset === 'string',
        null, { timeout: 120000, polling: 250 });
      const s = await p.evaluate(() => ({ ...window.__SHINOBI_STATE__ }));
      await p.screenshot({ path: path.join(outDir, `probe-camera-${tag}.png`) });
      return s;
    } finally { await p.close(); }
  };
  const sc = await cameraPage('?camera=close', 'close');
  const figureHeight = Number(sc.figure_height_px);
  const nativeFraction = figureHeight / 720;
  const CLOSE_ZOOM = nativeFraction >= 0.16 && nativeFraction <= 0.19 ? 1 : Math.min(4, Math.max(0.25, (0.175 * 720) / figureHeight));
  rec('camera-figure-height', Number.isFinite(figureHeight) && figureHeight > 0, `loaded figure height=${figureHeight}px`);
  rec('camera-close-via-query', sc.camera_preset === 'close' && near(sc.zoom, CLOSE_ZOOM) && Math.abs(sc.view_w - 1280 / CLOSE_ZOOM) < 2 && Math.abs(sc.view_h - 720 / CLOSE_ZOOM) < 2,
    `?camera=close expected preset=close zoom ~${CLOSE_ZOOM.toFixed(4)} view ${(1280 / CLOSE_ZOOM).toFixed(1)}x${(720 / CLOSE_ZOOM).toFixed(1)}; got preset=${sc.camera_preset} zoom=${sc.zoom} view=${sc.view_w}x${sc.view_h}`);
  const sg = await cameraPage('?camera=bogus', 'bogus');
  rec('camera-garbage-falls-back-to-wide', sg.camera_preset === 'wide' && near(sg.zoom, BASE_ZOOM) && Math.abs(sg.view_w - 2880) < 2 && Math.abs(sg.view_h - 1620) < 2,
    `?camera=bogus expected preset=wide zoom ~${BASE_ZOOM.toFixed(4)} view 2880x1620; got preset=${sg.camera_preset} zoom=${sg.zoom} view=${sg.view_w}x${sg.view_h}`);

  // Camera hit kick (CameraImpact): lab demo keys Digit7 light / Digit8 heavy / Digit9 burst of three, telemetry cfx_* in SCREEN px. A fresh page per
  // query starts at the spawn (idle, facing down, room on every side), so the edge clamp cannot cut a kick. The game runs at 4 to 9 FPS here, so an
  // 80-140 ms effect spans 0 or 1 rendered frames: never sample the live offset. Wait on cfx_count, then on cfx_active false, and read cfx_peak_px
  // (the game samples it on 60 Hz sub-steps, so it is the same at any frame rate).
  const kickRun = async (query, plan) => {
    const p = await context.newPage();
    p.on('console', (m) => consoleMsgs.push({ type: m.type(), text: m.text() }));
    p.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e) }));
    const st = () => p.evaluate(() => ({ ...window.__SHINOBI_STATE__ }));
    const press = async (key) => { await p.keyboard.down(key); await sleep(120); await p.keyboard.up(key); };
    const runs = [];
    try {
      await p.goto(server.url + query, { waitUntil: 'load' });
      await p.waitForFunction(() => window.__SHINOBI_READY__ === true && typeof window.__SHINOBI_STATE__?.cfx_count === 'number',
        null, { timeout: 120000, polling: 250 });
      await p.mouse.click(640, 400);
      await press('Tab'); // the demo keys only work while the lab is open
      await p.waitForFunction(() => window.__SHINOBI_STATE__.lab_open === true, null, { timeout: 60000, polling: 100 });
      for (const [key, hits] of plan) {
        const before = await st();
        await press(key);
        if (hits > 0) {
          await p.waitForFunction(([n]) => { const s = window.__SHINOBI_STATE__; return s.cfx_count >= n && s.cfx_active === false; },
            [before.cfx_count + hits], { timeout: 60000, polling: 100 });
        } else { // effect disabled: there is nothing to wait for, so let 8 published frames pass instead
          await p.waitForFunction(([f]) => window.__SHINOBI_STATE__.frame >= f, [before.frame + 8], { timeout: 60000, polling: 100 });
        }
        runs.push({ before, after: await st() });
      }
    } finally { await p.close(); }
    return runs;
  };
  const kick = (r) => `count ${r.before.cfx_count}->${r.after.cfx_count}, peak ${Number(r.after.cfx_peak_px).toFixed(3)} px, active=${r.after.cfx_active}, offset (${r.after.cfx_offset_x}, ${r.after.cfx_offset_y}), zoom ${r.before.zoom} -> ${r.after.zoom}`;
  // `hits` impulses counted, peak in [lo, hi] screen px, the effect over, offset exactly 0 and the zoom untouched on the preset baseline
  const kickOk = (r, hits, lo, hi, baseline) => r.after.cfx_count === r.before.cfx_count + hits
    && r.after.cfx_peak_px >= lo && r.after.cfx_peak_px <= hi && r.after.cfx_active === false
    && r.after.cfx_offset_x === 0 && r.after.cfx_offset_y === 0 && r.after.zoom === r.before.zoom && near(r.after.zoom, baseline);
  const [kl, kh, kb] = await kickRun('', [['Digit7', 1], ['Digit8', 1], ['Digit9', 3]]);
  rec('camera-impact-light', kickOk(kl, 1, 2, 3, BASE_ZOOM), `wide, order band 2-3 screen px: ${kick(kl)}`);
  rec('camera-impact-heavy', kickOk(kh, 1, 4, 6, BASE_ZOOM), `wide, order band 4-6 screen px: ${kick(kh)}`);
  rec('camera-impact-burst-capped', kickOk(kb, 3, 2, 6, BASE_ZOOM), `wide, three light hits: the peak stays at or under the 6 px cap: ${kick(kb)}`);
  const [cl, ch] = await kickRun('?camera=close', [['Digit7', 1], ['Digit8', 1]]);
  rec('camera-impact-close-zoom', kickOk(cl, 1, 2, 3, CLOSE_ZOOM) && kickOk(ch, 1, 4, 6, CLOSE_ZOOM),
    `close zoom ~${CLOSE_ZOOM.toFixed(4)}, same bands in screen px: light ${kick(cl)}; heavy ${kick(ch)}`);
  const koff = await kickRun('?camera_impact=off', [['Digit7', 0], ['Digit8', 0], ['Digit9', 0]]);
  const fo = koff[2].after;
  rec('camera-impact-off', koff[0].before.cfx_enabled === false && fo.cfx_enabled === false && fo.cfx_count === 0 && fo.cfx_peak_px === 0
    && fo.cfx_active === false && fo.cfx_offset_x === 0 && fo.cfx_offset_y === 0,
    `?camera_impact=off, keys 7 8 9 pressed: enabled=${fo.cfx_enabled}, count=${fo.cfx_count}, peak=${fo.cfx_peak_px}, active=${fo.cfx_active}, offset (${fo.cfx_offset_x}, ${fo.cfx_offset_y})`);
  const [kr] = await kickRun('?camera_impact=reduced', [['Digit8', 1]]);
  rec('camera-impact-reduced', kr.after.cfx_scale === 0.5 && kickOk(kr, 1, 2, 3, BASE_ZOOM), `?camera_impact=reduced halves the heavy kick (5 -> 2.5 px), scale=${kr.after.cfx_scale}: ${kick(kr)}`);
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
