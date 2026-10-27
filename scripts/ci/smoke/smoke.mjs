#!/usr/bin/env node
// Browser smoke test for the Godot Web export (CI tooling; not part of the game).
//
//   node smoke.mjs --serve-dir <export dir> --out-dir <evidence dir> [options]     (starts a local static server)
//   node smoke.mjs --base-url <https://...> --expected-sha <40 hex> --out-dir ...   (real deployment)
//
// Exit codes: 0 all checks passed | 1 a check failed | 2 usage error | 3 environment problem
// (browser could not launch / WebGL2 unavailable: not a game defect).
import { chromium } from 'playwright';
import { createRequire } from 'node:module';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseCli, UsageError } from './lib/args.mjs';
import { classifyHttpStatus, classifyRequestFailure, classifyStream, extractEngineEvidence } from './lib/console-policy.mjs';
import { analyzeInPage, DIFF_PIXEL_THRESHOLD, isBlank, MIN_CHANGED_RATIO, SAMPLE_H, SAMPLE_W } from './lib/pixels.mjs';
import { sanitize, summaryMarkdown } from './lib/report.mjs';
import { startStaticServer } from './lib/serve.mjs';
import { fetchBuildInfo, inspectCanvas, pressSequence, probeWebGL2, readReadyHook, readyHookVerdict, verifyServedFiles, waitForEngineStart } from './lib/steps.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

let parsed;
try {
  parsed = parseCli(process.argv.slice(2), { here, env: process.env });
} catch (e) {
  if (e instanceof UsageError || e.code?.startsWith('ERR_PARSE_ARGS')) {
    console.error(`smoke: ${e.message}`);
    process.exit(2);
  }
  throw e;
}
const { cli, cfg, allowlist, mode, outDir } = parsed;
mkdirSync(path.join(outDir, 'screenshots'), { recursive: true });

const t0 = Date.now();
const rel = () => Date.now() - t0;
const checks = [];
const events = []; // pageerror / crash / requestfailed / http / dialog / dom; console events are classified as a stream at the end
const consoleMsgs = [];
let server = null;
let browser = null;
let baseUrl = cli['base-url'];

function record(name, status, detail = '') {
  checks.push({ name, status, detail: sanitize(detail, 600) });
  console.log(`[smoke] ${status.toUpperCase().padEnd(4)} ${name}${detail ? ' - ' + sanitize(detail, 300).split('\n')[0] : ''}`);
}

function finalize(code, reason = '') {
  if (code === 0 && checks.some((c) => c.status === 'fail')) code = 1;
  const verdict = code === 0 ? 'PASS' : 'FAIL';
  const environment = {
    node: process.version,
    playwright: (() => { try { return require('playwright/package.json').version; } catch { return null; } })(),
    browser: browser?.version?.() ?? null,
    platform: process.platform,
    github_run_id: process.env.GITHUB_RUN_ID ?? null,
    github_sha: process.env.GITHUB_SHA ?? null,
  };
  try {
    writeFileSync(path.join(outDir, 'smoke-result.json'), JSON.stringify({ label: cli.label, mode, baseUrl, verdict, exitCode: code, reason, durationMs: rel(), checks, environment, config: cfg }, null, 2));
    writeFileSync(path.join(outDir, 'console-log.json'), JSON.stringify([...consoleMsgs, ...events.filter((e) => e.kind !== 'console')], null, 2));
    const md = summaryMarkdown({ label: cli.label, mode, baseUrl, verdict, durationMs: rel(), checks, events });
    writeFileSync(path.join(outDir, 'summary.md'), md);
    if (cli['summary-file']) appendFileSync(cli['summary-file'], md);
  } catch (e) {
    console.error(`[smoke] could not write evidence: ${e.message}`);
  }
  console.log(`[smoke] VERDICT ${verdict} (exit ${code}) label=${cli.label}`);
  return code;
}

const watchdog = setTimeout(async () => {
  record('global-timeout', 'fail', `exceeded --global-timeout-ms=${cli['global-timeout-ms']}`);
  const code = finalize(1, 'global timeout');
  await browser?.close().catch(() => {});
  await server?.close().catch(() => {});
  process.exit(code);
}, Number(cli['global-timeout-ms']));
watchdog.unref();

async function sampleAndCheckCanvas(page, context, canvas) {
  const analysis = await context.newPage();
  const stats = (b64, prev) => analysis.evaluate(analyzeInPage, { pngBase64: b64, prevPngBase64: prev, w: SAMPLE_W, h: SAMPLE_H, diffThreshold: DIFF_PIXEL_THRESHOLD });
  const shot = async (name) => {
    const png = await canvas.screenshot({ type: 'png' });
    writeFileSync(path.join(outDir, 'screenshots', name), png);
    return png.toString('base64');
  };
  const samples = [];
  let before = await shot('01-settled.png');
  samples.push(await stats(before));
  for (let i = 0; i < 2 && isBlank(samples.at(-1)); i++) { // tolerate a fade-in: two more samples, 2 s apart
    await page.waitForTimeout(2000);
    before = await shot(`01-settled-retry${i + 1}.png`);
    samples.push(await stats(before));
  }
  const good = samples.find((s) => !isBlank(s));
  if (good) record('canvas-not-blank', 'pass', `distinct colours=${good.distinctColors}, dominant colour ${good.dominantColor} covers ${(good.dominantRatio * 100).toFixed(1)}%`);
  else record('canvas-not-blank', 'fail', `canvas looks uniform in ${samples.length} samples: dominant colour ${samples.at(-1).dominantColor} covers ${(samples.at(-1).dominantRatio * 100).toFixed(2)}%, distinct colours=${samples.at(-1).distinctColors}`);

  if (cfg.input_sequence.length === 0) {
    record('input-effect', 'skip', 'no input sequence configured (scripts/ci/smoke/smoke-config.json)');
  } else {
    await pressSequence(page, cfg.input_sequence);
    const after = await shot('02-after-input.png');
    const s = await stats(after, before);
    const effect = s.changedRatio >= MIN_CHANGED_RATIO;
    record('input-effect', effect ? 'pass' : (cfg.require_input_effect ? 'fail' : 'warn'),
      `${(s.changedRatio * 100).toFixed(3)}% of sampled pixels changed after ${cfg.input_sequence.join(',')} (needs >= ${(MIN_CHANGED_RATIO * 100).toFixed(2)}%${cfg.require_input_effect ? '' : '; warning only unless require_input_effect=true'})`);
  }
  await recordMovement(page);
  await analysis.close();
}

// Short bounded movement assertion (about 3 s worst case): real key input must change the player's x in
// window.__SHINOBI_STATE__ (published ~10 Hz by the WebBridge autoload). Tries right, then left, in case a wall is in the way.
async function recordMovement(page) {
  const readX = () => page.evaluate(() => window.__SHINOBI_STATE__?.x);
  let x0;
  for (let i = 0; i < 20 && !Number.isFinite(x0); i++) { // up to 5 s for the first published state
    x0 = await readX();
    if (!Number.isFinite(x0)) await page.waitForTimeout(250);
  }
  if (!Number.isFinite(x0)) {
    record('player-moves', cfg.require_player_movement ? 'fail' : 'skip', 'window.__SHINOBI_STATE__.x was never published, so movement cannot be asserted' + (cfg.require_player_movement ? '' : ' (--require-player-movement not set)'));
    return;
  }
  await page.evaluate(() => document.querySelector('canvas')?.focus());
  const tried = [];
  for (const key of ['KeyD', 'KeyA']) {
    const before = await readX();
    await page.keyboard.down(key);
    await page.waitForTimeout(700);
    await page.keyboard.up(key);
    await page.waitForTimeout(400); // let the next 10 Hz publish land
    const after = await readX();
    const dx = after - before;
    tried.push(`${key}: x ${before?.toFixed?.(1)} -> ${after?.toFixed?.(1)}`);
    if (Number.isFinite(dx) && Math.abs(dx) >= 0.5) {
      record('player-moves', 'pass', `${tried.join('; ')} (moved ${dx.toFixed(1)} px)`);
      return;
    }
  }
  record('player-moves', cfg.require_player_movement ? 'fail' : 'warn', `holding KeyD then KeyA never changed the player's x (${tried.join('; ')}): input is not reaching the game or movement is broken`);
}

async function main() {
  if (mode === 'local') {
    server = await startStaticServer(cli['serve-dir']);
    baseUrl = server.url;
  }
  if (!baseUrl.endsWith('/')) baseUrl += '/';

  // Browser + WebGL2 preflight. Known early risk: headless Chromium on a GPU-less CI runner.
  try {
    const extra = (process.env.SMOKE_CHROMIUM_ARGS ?? '').split(/\s+/).filter(Boolean);
    browser = await chromium.launch({ headless: true, args: ['--autoplay-policy=no-user-gesture-required', ...extra] });
  } catch (e) {
    record('browser-launch', 'fail', `Chromium failed to launch: ${String(e.message).split('\n')[0]} (run: npx playwright install --with-deps --only-shell chromium)`);
    return 3;
  }
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, serviceWorkers: 'block' });
  const gl = await probeWebGL2(context);
  if (!gl) {
    record('webgl2-available', 'fail', 'WebGL2 context could not be created in headless Chromium (environment problem, not a game defect). Try SMOKE_CHROMIUM_ARGS="--use-angle=swiftshader", then "--use-gl=angle --use-angle=swiftshader".');
    return 3;
  }
  record('webgl2-available', 'pass', `${gl.version}; ${gl.renderer}`);

  // build-info.json (+ SHA propagation retry against a real deployment)
  const { buildInfo, attempts } = await fetchBuildInfo(baseUrl, {
    expectedSha: cli['expected-sha'],
    timeoutMs: mode === 'deployed' ? Number(cli['propagation-timeout-ms']) : 0,
  });
  if (!buildInfo) {
    record('build-info', 'fail', `build-info.json not retrievable (last HTTP status ${attempts.at(-1)?.status}) after ${attempts.length} attempt(s)`);
    return 1;
  }
  writeFileSync(path.join(outDir, 'build-info.json'), JSON.stringify(buildInfo, null, 2));
  const shaOk = !cli['expected-sha'] || buildInfo.commit_sha === cli['expected-sha'];
  const kindOk = buildInfo.kind === cli['expected-kind'];
  record('build-info', shaOk && kindOk ? 'pass' : 'fail',
    `kind=${buildInfo.kind} (expected ${cli['expected-kind']}), commit=${buildInfo.commit_sha} (expected ${cli['expected-sha'] ?? 'any'}), attempts=${attempts.length}`);
  if (mode === 'deployed') {
    writeFileSync(path.join(outDir, 'deploy-info.json'), JSON.stringify({
      page_url: baseUrl,
      expected_sha: cli['expected-sha'],
      live_sha: buildInfo.commit_sha,
      matched: shaOk,
      attempts,
      repository: process.env.GITHUB_REPOSITORY ?? null,
      run_id: process.env.GITHUB_RUN_ID ?? null,
      run_attempt: process.env.GITHUB_RUN_ATTEMPT ?? null,
      checked_at: new Date().toISOString(),
    }, null, 2));
  }
  if (!shaOk || !kindOk) return 1;

  if (!cli['skip-file-verification'] && buildInfo.files) {
    const mismatches = await verifyServedFiles(baseUrl, buildInfo.files);
    record('served-files-match-build', mismatches.length ? 'fail' : 'pass',
      mismatches.length ? `served bytes differ from build-info.json for: ${mismatches.join(', ')}` : `${Object.keys(buildInfo.files).length} files verified by sha256`);
    if (mismatches.length) return 1;
  }

  // Load the game.
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__SMOKE_EVENTS__ = [];
    window.addEventListener('webglcontextlost', () => window.__SMOKE_EVENTS__.push({ type: 'webglcontextlost' }), true);
  });
  page.on('console', (m) => consoleMsgs.push({ t: rel(), kind: 'console', type: m.type(), text: m.text(), url: m.location().url }));
  page.on('pageerror', (e) => events.push({ t: rel(), kind: 'pageerror', type: 'pageerror', text: String(e?.message ?? e), level: 'fatal', rule: 'pageerror' }));
  page.on('crash', () => events.push({ t: rel(), kind: 'crash', type: 'crash', text: 'page crashed', level: 'fatal', rule: 'crash' }));
  page.on('requestfailed', (r) => {
    const entry = { url: r.url(), errorText: r.failure()?.errorText };
    events.push({ t: rel(), kind: 'requestfailed', type: 'requestfailed', text: `${entry.url} ${entry.errorText}`, ...classifyRequestFailure(entry, allowlist.requests) });
  });
  const responses = [];
  page.on('response', (r) => {
    const entry = { url: r.url(), status: r.status() };
    responses.push({ ...entry, contentType: r.headers()['content-type'] ?? null });
    const c = classifyHttpStatus(entry, allowlist.requests);
    if (c.level !== 'info') events.push({ t: rel(), kind: 'http', type: 'http', text: `${entry.status} ${entry.url}`, ...c });
  });
  page.on('dialog', (d) => { events.push({ t: rel(), kind: 'dialog', type: d.type(), text: d.message(), level: 'warn', rule: 'dialog' }); d.dismiss().catch(() => {}); });

  const nav = await page.goto(baseUrl, { waitUntil: 'load', timeout: cfg.startup_timeout_ms });
  record('page-load', nav && nav.ok() ? 'pass' : 'fail', `HTTP ${nav?.status()} ${nav?.headers()['content-type'] ?? ''}`);

  const start = await waitForEngineStart(page, cfg.startup_timeout_ms);
  if (start === 'started') record('engine-start', 'pass', `status overlay removed after ${rel()} ms`);
  else if (start.startsWith('notice:')) record('engine-start', 'fail', `status notice shown: ${start.slice(7)}`);
  else record('engine-start', 'fail', `status overlay still visible after ${cfg.startup_timeout_ms} ms`);

  if (start !== 'started') {
    await page.screenshot({ path: path.join(outDir, 'screenshots', '99-engine-start-failed.png') }).catch(() => {});
    for (const name of ['canvas-visible', 'ready-hook', 'canvas-not-blank', 'input-effect', 'player-moves', 'engine-evidence']) record(name, 'skip', 'engine did not start');
  } else {
    const canvas = page.locator(cfg.canvas_selector).first();
    const c = await inspectCanvas(canvas);
    record('canvas-visible', c.ok ? 'pass' : 'fail',
      c.ok ? `${Math.round(c.box.width)}x${Math.round(c.box.height)} css px, drawing buffer ${c.buffer.w}x${c.buffer.h}` : `canvas "${cfg.canvas_selector}" missing or zero-sized (box=${JSON.stringify(c.box)} buffer=${JSON.stringify(c.buffer)})`);

    const hook = readyHookVerdict(await readReadyHook(page), cfg.require_ready_hook);
    record('ready-hook', hook.status, hook.detail);

    await page.waitForTimeout(cfg.settle_ms);
    await sampleAndCheckCanvas(page, context, canvas);

    const ev = extractEngineEvidence(consoleMsgs);
    if (ev.singleThreaded === false || ev.compatibilityRenderer === false) record('engine-evidence', 'fail', `engine reports build="${ev.build}" gl="${ev.gl}"`);
    else if (ev.singleThreaded && ev.compatibilityRenderer) record('engine-evidence', 'pass', `${ev.build} | Compatibility renderer confirmed`);
    else record('engine-evidence', 'warn', 'engine banner / build-configuration lines not found in the console');
  }

  events.push(...classifyStream(consoleMsgs, allowlist.console));
  const dom = await page.evaluate(() => window.__SMOKE_EVENTS__ ?? []).catch(() => []);
  for (const d of dom) events.push({ t: rel(), kind: 'dom', type: d.type, text: d.type, level: 'fatal', rule: d.type });
  events.sort((a, b) => a.t - b.t);
  const fatal = events.filter((e) => e.level === 'fatal');
  const warns = events.filter((e) => e.level === 'warn');
  if (fatal.length) record('no-fatal-console', 'fail', `${fatal.length} fatal event(s); first: [${fatal[0].rule}] ${String(fatal[0].text).split('\n')[0].slice(0, 200)}`);
  else record('no-fatal-console', 'pass', `${events.length} events, ${warns.length} warning(s), 0 fatal`);
  writeFileSync(path.join(outDir, 'network-summary.json'), JSON.stringify(responses, null, 2));
  return 0;
}

let code = 0;
try {
  code = await main();
} catch (e) {
  record('harness', 'fail', String(e?.stack ?? e).split('\n').slice(0, 4).join(' | '));
  code = 1;
} finally {
  code = finalize(code);
  await browser?.close().catch(() => {});
  await server?.close().catch(() => {});
}
process.exit(code);
