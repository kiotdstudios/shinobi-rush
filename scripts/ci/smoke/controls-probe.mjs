#!/usr/bin/env node
// Controls probe for the Shinobi Rush Web export (CI tooling; not part of the game).
// Drop into scripts/ci/smoke/ next to smoke.mjs (it reuses lib/serve.mjs).
//   node controls-probe.mjs --serve-dir <export dir> --out-dir <evidence dir>
// Reads window.__SHINOBI_STATE__ ({frame,x,y,state,sprinting,fps}, published ~10 Hz by the WebBridge autoload) and proves
// that REAL key input moves the player: walk right, sprint faster, a wall stops the player. It also drives the camera-impact lab demo keys
// and reads the cfx_* telemetry. It also toggles the Bandit vision debug overlay (Settings panel button, ?vision=1) and reads the vision_* telemetry.
// Exit 0 = all passed, 1 = a check failed.
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
  await page.goto(server.url + '?debug=1', { waitUntil: 'load' }); // the public page hides Settings; ?debug=1 shows it
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

  // Camera framing: the gameplay baseline is the wide view (zoom 0.6650, visible world 1924.8x1082.7 in a 1280x720 viewport; the camera is permanently locked).
  const BASE_ZOOM = 0.665;
  const zoomNow = async () => (await state()).zoom;
  const near = (v, want) => Number.isFinite(v) && Math.abs(v - want) < 0.005;
  const zs = await state();
  rec('camera-preset-default-is-wide', zs.camera_preset === 'wide', `no ?camera= parameter: state.camera_preset=${JSON.stringify(zs.camera_preset)}, expected "wide"`);
  rec('camera-baseline-at-start', near(zs.zoom, BASE_ZOOM) && Math.abs(zs.view_w - 1924.81) < 2 && Math.abs(zs.view_h - 1082.71) < 2,
    `expected zoom ~${BASE_ZOOM.toFixed(4)} and view 1924.8x1082.7; got zoom=${zs.zoom}, view=${zs.view_w}x${zs.view_h}`);

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

  // Proximity "power level" sense telemetry (owner: "when naruto running and near enemy ... player will
  // auto detect and pull their kunai out"): published fields exist with sane types/values regardless of
  // whether the real training-arena bandit happens to be in range right now (that is a gameplay event,
  // not something this smoke probe forces -- see tests/test_proximity_sense.gd for the behavioral checks).
  const sense = sprint.b;
  rec('player-sense-telemetry', typeof sense.player_kunai_drawn === 'boolean' && Number.isFinite(sense.player_sense_radius) && sense.player_sense_radius > 0,
    `player_kunai_drawn=${sense.player_kunai_drawn} (bool) player_sense_radius=${sense.player_sense_radius}`);
  rec('bandit-sense-telemetry', typeof sense.bandit_senses_player === 'boolean' && Number.isFinite(sense.bandit_sense_radius) && sense.bandit_sense_radius > 0,
    `bandit_senses_player=${sense.bandit_senses_player} (bool) bandit_sense_radius=${sense.bandit_sense_radius}`);

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
  rec('lab-z-second-step-is-quarter', near(zZ2, 1.25), `after a second Z zoom=${zZ2}, expected 1.25 (quarter steps: baseline, 1, 1.25, 1.5, 1.75, 2, ...)`);
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
  rec('camera-close-query-is-ignored-locked', sc.camera_preset === 'wide' && near(sc.zoom, BASE_ZOOM) && Math.abs(sc.view_w - 1280 / BASE_ZOOM) < 2 && Math.abs(sc.view_h - 720 / BASE_ZOOM) < 2,
    `?camera=close is ignored (camera locked): expected preset=wide zoom ~${BASE_ZOOM.toFixed(4)} view ${(1280 / BASE_ZOOM).toFixed(1)}x${(720 / BASE_ZOOM).toFixed(1)}; got preset=${sc.camera_preset} zoom=${sc.zoom} view=${sc.view_w}x${sc.view_h}`);
  const sg = await cameraPage('?camera=bogus', 'bogus');
  rec('camera-garbage-falls-back-to-wide', sg.camera_preset === 'wide' && near(sg.zoom, BASE_ZOOM) && Math.abs(sg.view_w - 1924.81) < 2 && Math.abs(sg.view_h - 1082.71) < 2,
    `?camera=bogus expected preset=wide zoom ~${BASE_ZOOM.toFixed(4)} view 1924.8x1082.7; got preset=${sg.camera_preset} zoom=${sg.zoom} view=${sg.view_w}x${sg.view_h}`);

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
  rec('camera-impact-close-zoom', kickOk(cl, 1, 2, 3, BASE_ZOOM) && kickOk(ch, 1, 4, 6, BASE_ZOOM),
    `?camera=close ignored, locked zoom ~${BASE_ZOOM.toFixed(4)}, same bands in screen px: light ${kick(cl)}; heavy ${kick(ch)}`);
  const koff = await kickRun('?camera_impact=off', [['Digit7', 0], ['Digit8', 0], ['Digit9', 0]]);
  const fo = koff[2].after;
  rec('camera-impact-off', koff[0].before.cfx_enabled === false && fo.cfx_enabled === false && fo.cfx_count === 0 && fo.cfx_peak_px === 0
    && fo.cfx_active === false && fo.cfx_offset_x === 0 && fo.cfx_offset_y === 0,
    `?camera_impact=off, keys 7 8 9 pressed: enabled=${fo.cfx_enabled}, count=${fo.cfx_count}, peak=${fo.cfx_peak_px}, active=${fo.cfx_active}, offset (${fo.cfx_offset_x}, ${fo.cfx_offset_y})`);
  const [kr] = await kickRun('?camera_impact=reduced', [['Digit8', 1]]);
  rec('camera-impact-reduced', kr.after.cfx_scale === 0.5 && kickOk(kr, 1, 2, 3, BASE_ZOOM), `?camera_impact=reduced halves the heavy kick (5 -> 2.5 px), scale=${kr.after.cfx_scale}: ${kick(kr)}`);

  // Bandit vision debug overlay (BanditVisionToggle / BanditVisionOverlay): default OFF, toggled by clicking its button in the bottom-edge Settings tab (no hotkeys)
  // and started by ?vision=1. Telemetry only: every wait is on the published state, never on a sleep (the game runs at 4 to 9 FPS here).
  // vision_nodes is the scene tree's node count: ON must add exactly the one overlay node and OFF must take it away again, which is how
  // "OFF leaves no geometry behind" is proven on the real export. The overlay numbers are compared with the Bandit's own (bandit_*) of the SAME publish.
  const VISION_FIELDS = ['vision_on', 'vision_bandits', 'vision_points', 'vision_rays', 'vision_ms', 'vision_state', 'vision_ai_state', 'vision_sees', 'vision_can_see',
    'vision_player_in', 'vision_cone', 'vision_range', 'vision_close', 'vision_fov_deg', 'vision_facing_x', 'vision_facing_y', 'vision_mismatch', 'vision_capped',
    'vision_nodes', 'vision_origin_x', 'vision_origin_y'];
  const VISION_CATS = ['not_alert', 'suspicious', 'detected', 'lost_sight', 'searching', 'returning'];
  // The switches live in the bottom-edge Settings tab: click the Settings tab (positions come from the settings_* telemetry), then the row.
  const visionOpen = async (query) => {
    const p = await context.newPage();
    p.on('console', (m) => consoleMsgs.push({ type: m.type(), text: m.text() }));
    p.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e) }));
    await p.goto(server.url + query, { waitUntil: 'load' });
    await p.waitForFunction(() => window.__SHINOBI_READY__ === true && typeof window.__SHINOBI_STATE__?.vision_on === 'boolean',
      null, { timeout: 120000, polling: 250 });
    await p.mouse.click(640, 400); // canvas keyboard focus (no game action uses the mouse)
    const st = () => p.evaluate(() => ({ ...window.__SHINOBI_STATE__ }));
    const until = async (pred, arg) => { // the first published state that satisfies pred, or null after 30 s
      try { await p.waitForFunction(pred, arg, { timeout: 30000, polling: 100 }); return await st(); } catch (e) { return null; }
    };
    const clickRow = async (xf, yf) => { // open the Settings list if it is closed, click the row
      let s = await st();
      if (!s.settings_open) { await p.mouse.click(s.settings_tab_x, s.settings_tab_y, { delay: 80 }); s = (await until(() => window.__SHINOBI_STATE__.settings_open === true)) ?? (await st()); }
      await p.mouse.click(s[xf], s[yf], { delay: 80 }); // the list stays open (the tab tucks away while open); later rows reuse it
      await sleep(150);
      await p.mouse.move(640, 400); // move away: no tooltip popup node
    };
    const click = () => clickRow('settings_bandit_x', 'settings_bandit_y');
    const clickSense = () => clickRow('settings_sense_x', 'settings_sense_y');
    const key = async (code) => { await p.keyboard.down(code); await sleep(120); await p.keyboard.up(code); };
    return { p, st, until, key, click, clickSense };
  };
  const visionIsOn = () => window.__SHINOBI_STATE__.vision_on === true && window.__SHINOBI_STATE__.vision_points > 0;
  const visionIsOff = () => window.__SHINOBI_STATE__.vision_on === false;
  const onOk = (s, base) => !!s && s.vision_on === true && s.vision_bandits === 1 && s.vision_points >= 8 && s.vision_rays >= 8 && s.vision_nodes === base + 1;
  const offOk = (s, base) => !!s && s.vision_on === false && s.vision_bandits === 0 && s.vision_points === 0 && s.vision_rays === 0 && s.vision_state === '' && s.vision_nodes === base;
  const vsum = (s) => (s ? `on=${s.vision_on} bandits=${s.vision_bandits} points=${s.vision_points} rays=${s.vision_rays} nodes=${s.vision_nodes}` : 'timed out waiting for the published state');
  const vp = await visionOpen('');
  try {
    const f0 = (await vp.st()).frame;
    const v0 = (await vp.until(([want]) => window.__SHINOBI_STATE__.frame >= want, [f0 + 6])) ?? (await vp.st()); // a few published frames after READY: the scene has settled
    const missing = VISION_FIELDS.filter((f) => !(f in v0));
    const base = v0.vision_nodes;
    rec('vision-default-off', missing.length === 0 && offOk(v0, base) && Number.isInteger(base) && base > 10,
      `no ?vision= parameter: all ${VISION_FIELDS.length} vision_* fields present (missing: ${missing.join(',') || 'none'}); ${vsum(v0)}`);
    // no hotkeys any more: F1, F2 and F3 pressed on the real canvas change nothing
    for (const code of ['F1', 'F2', 'F3']) await vp.key(code);
    await sleep(600);
    const nk = await vp.st();
    rec('vision-hotkeys-removed', offOk(nk, base) && nk.sense_vision_on === false, `F1/F2/F3 pressed: ${vsum(nk)} sense_vision_on=${nk.sense_vision_on} (expect everything still off)`);
    // Settings tab -> Bandit vision row on, again off
    await vp.click();
    const b1 = await vp.until(visionIsOn);
    await vp.p.screenshot({ path: path.join(outDir, 'probe-vision-on.png') });
    await vp.click();
    const b2 = await vp.until(visionIsOff);
    rec('vision-button-toggles-on-off', onOk(b1, base) && offOk(b2, base), `Settings > Bandit vision click: ON ${vsum(b1)}; click again: OFF ${vsum(b2)}`);
    // live: ON for >= 20 published frames while the Bandit patrols; every sample compares the overlay with the AI's own numbers of the same publish
    await vp.click();
    await vp.until(visionIsOn);
    const samples = [];
    let lastFrame = -1;
    while (samples.length < 80 && !(samples.length >= 20 && Math.hypot(samples[samples.length - 1].bandit_x - samples[0].bandit_x, samples[samples.length - 1].bandit_y - samples[0].bandit_y) > 30)) {
      const s = await vp.st();
      if (s.frame !== lastFrame) { samples.push(s); lastFrame = s.frame; } else { await sleep(60); }
    }
    const issues = [];
    let worstOrigin = 0;
    for (const s of samples) {
      const bad = [];
      if (s.vision_ai_state !== s.bandit_state) bad.push(`overlay state ${s.vision_ai_state} vs AI ${s.bandit_state}`);
      if (s.vision_sees !== s.bandit_sees) bad.push(`overlay sees ${s.vision_sees} vs AI ${s.bandit_sees}`);
      if (s.vision_can_see !== s.vision_player_in) bad.push(`polygon contains player ${s.vision_player_in} vs can_see ${s.vision_can_see}`);
      const off = Math.hypot(s.vision_origin_x - s.bandit_x, s.vision_origin_y - s.bandit_y);
      worstOrigin = Math.max(worstOrigin, off);
      if (!(off < 0.01)) bad.push(`polygon apex ${off.toFixed(3)} px from the Bandit`);
      if (s.vision_on !== true || s.vision_mismatch !== 0 || s.vision_capped !== false) bad.push(`on=${s.vision_on} mismatch=${s.vision_mismatch} capped=${s.vision_capped}`);
      if (!VISION_CATS.includes(s.vision_state)) bad.push(`unknown category ${JSON.stringify(s.vision_state)}`);
      if (!(s.vision_range > s.vision_close && s.vision_close > 0 && s.vision_fov_deg > 0 && s.vision_fov_deg < 360 && s.vision_points >= 8)) bad.push(`range ${s.vision_range} close ${s.vision_close} fov ${s.vision_fov_deg} points ${s.vision_points}`);
      if (bad.length) issues.push(`frame ${s.frame}: ${bad.join('; ')}`);
    }
    const first = samples[0] ?? {};
    const last = samples[samples.length - 1] ?? {};
    const moved = samples.length ? Math.hypot(last.bandit_x - first.bandit_x, last.bandit_y - first.bandit_y) : 0;
    const cats = [...new Set(samples.map((s) => `${s.bandit_state}/${s.vision_state}`))].join(',');
    rec('vision-follows-and-agrees-with-ai', samples.length >= 20 && moved > 30 && issues.length === 0,
      `${samples.length} published frames, Bandit moved ${moved.toFixed(0)} px, states ${cats}; ${issues.length} disagreements${issues.length ? ': ' + issues.slice(0, 3).join(' | ') : ''}; ` +
      `polygon apex vs Bandit worst ${worstOrigin.toFixed(4)} px; last sample cone=${last.vision_cone} range=${last.vision_range} ${last.vision_rays} rays ${last.vision_ms} ms/rebuild`);
    await vp.click();
    const stepOff = await vp.until(visionIsOff);
    // repeated toggling through the key and the button, alternating: every ON has exactly one overlay node, every OFF has none, the end state is the start state
    const cycleBad = [];
    const CYCLES = 12;
    for (let i = 0; i < CYCLES; i++) {
      const press = vp.click;
      await press();
      const on = await vp.until(visionIsOn);
      await press();
      const off = await vp.until(visionIsOff);
      if (!onOk(on, base) || on.vision_mismatch !== 0) cycleBad.push(`#${i} button ON ${vsum(on)}`);
      if (!offOk(off, base)) cycleBad.push(`#${i} button OFF ${vsum(off)}`);
    }
    const fin = await vp.st();
    rec('vision-repeat-toggle-stable', offOk(stepOff, base) && cycleBad.length === 0 && offOk(fin, base),
      `${CYCLES} ON/OFF cycles through the Settings button (${CYCLES * 2} toggles): ${cycleBad.length} bad states${cycleBad.length ? ': ' + cycleBad.slice(0, 3).join(' | ') : ''}; after the last OFF ${vsum(fin)} (start nodes=${base})`);
  } finally { await vp.p.close(); }
  // ?vision=1 starts ON with the Bandit drawn; clicking the Settings button then switches it OFF and takes the overlay node away
  const vq = await visionOpen('?vision=1');
  try {
    const q0 = await vq.until(visionIsOn);
    rec('vision-url-starts-on', !!q0 && q0.vision_on === true && q0.vision_bandits === 1 && q0.vision_points >= 8 && VISION_CATS.includes(q0.vision_state), `?vision=1: ${vsum(q0)}, state ${q0 ? q0.vision_state : '?'}`);
    await vq.click();
    const q1 = await vq.until(visionIsOff);
    rec('vision-url-on-then-off-leaves-nothing', !!q0 && !!q1 && offOk(q1, q0.vision_nodes - 1), `Settings click after ?vision=1: ${vsum(q1)} (expect zero geometry and nodes=${q0 ? q0.vision_nodes - 1 : '?'}, one less than ON)`);
  } finally { await vq.p.close(); }
  // Proximity "power level" sense debug overlay toggle (owner 2026-10-22: "make sure the intelligence
  // vision have a toggle on and off like the bandit vision"), now a Settings-panel button (no hotkey).
  const sv = await visionOpen('');
  try {
    const sv0 = await sv.st();
    rec('sense-vision-default-off', sv0.sense_vision_on === false && Number.isInteger(sv0.sense_vision_nodes) && sv0.sense_vision_nodes > 10,
      `no toggle pressed: sense_vision_on=${sv0.sense_vision_on} sense_vision_views=${sv0.sense_vision_views} sense_vision_nodes=${sv0.sense_vision_nodes}`);
    await sv.clickSense();
    const sv1 = await sv.until(() => window.__SHINOBI_STATE__.sense_vision_on === true);
    rec('sense-vision-button-toggles-on', !!sv1 && sv1.sense_vision_on === true && sv1.sense_vision_views >= 1,
      `Settings > Sense vision click: sense_vision_on=${sv1 ? sv1.sense_vision_on : '?'} sense_vision_views=${sv1 ? sv1.sense_vision_views : '?'}`);
    await sv.clickSense();
    const sv2 = await sv.until(() => window.__SHINOBI_STATE__.sense_vision_on === false);
    rec('sense-vision-button-toggles-off', !!sv2 && sv2.sense_vision_on === false && sv2.sense_vision_nodes === sv0.sense_vision_nodes,
      `click again: sense_vision_on=${sv2 ? sv2.sense_vision_on : '?'} sense_vision_nodes=${sv2 ? sv2.sense_vision_nodes : '?'} (expect back to ${sv0.sense_vision_nodes})`);
  } finally { await sv.p.close(); }
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
