#!/usr/bin/env node
// Debug-log probe for the Shinobi Rush Web export (CI tooling; not part of the game).
//   node debug-probe.mjs --serve-dir <export dir> --out-dir <evidence dir>
// Proves the opt-in BrowserDebug layer (docs/development/DEBUG_LOG_INTERFACE.md) in a real browser: ?debug=1 captures induced browser
// errors, the Download / Copy actions produce a valid bounded log / report, nothing is sent over the network or persisted, typed text is
// never captured, and with debug OFF (default) nothing is installed. Exit 0 = all passed, 1 = a check failed.
// The panel buttons are drawn by Godot on the canvas, so the probe triggers the SAME actions through their bound keys
// (F7 = dbg_download_log, F8 = dbg_copy_report) with real key presses, which are valid user gestures for downloads and the clipboard.
// If the export has no test hooks at all (neither __SHINOBI_READY__ nor __SHINOBI_STATE__), the probe SKIPS and exits 0 like controls-probe.
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { startStaticServer } from './lib/serve.mjs';
import {
  parseJsonl, headerProblems, eventProblems, findBrowserError, stackProblems, leaks, containsTyped,
  storageProblems, requestProblems, sizeProblems, reportProblems, listenerCount, countIndicatorPixels, buildIdentityProblems,
} from './lib/debug-probe-lib.mjs';

const arg = (n) => { const i = process.argv.indexOf('--' + n); return i < 0 ? undefined : process.argv[i + 1]; };
const serveDir = arg('serve-dir');
const outDir = arg('out-dir');
if (!serveDir || !outDir) { console.error('usage: node debug-probe.mjs --serve-dir <dir> --out-dir <dir>'); process.exit(2); }
mkdirSync(outDir, { recursive: true });

const results = [];
const rec = (name, ok, detail) => { results.push({ name, ok, detail }); console.log(`[debug-probe] ${ok ? 'PASS' : 'FAIL'} ${name} - ${detail}`); };
const recProblems = (name, problems, okDetail) => rec(name, problems.length === 0, problems.length ? problems.slice(0, 5).join('; ') : okDetail);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const TAG = Math.random().toString(36).slice(2, 8);
const TYPED = 'qzxjkv' + Math.floor(Math.random() * 9000 + 1000); // unique string typed into the page
const MSG_ERR = `probe-induced-error-${TAG}`;
const MSG_REJ = `probe-induced-rejection-${TAG}`;
const FLOOD = 20000;

// Init script (runs before any page script): logs addEventListener registrations for error-ish types and keeps the
// original console.error/warn so we can tell whether they were wrapped.
const INIT = () => {
  window.__probeListeners = [];
  const add = window.addEventListener;
  window.addEventListener = function (type) {
    if (type === 'error' || type === 'unhandledrejection') window.__probeListeners.push(type);
    return add.apply(this, arguments);
  };
  window.__probeOrigConsole = { error: console.error, warn: console.warn };
};

const server = await startStaticServer(serveDir, { port: 0 }); // ephemeral port
const origin = new URL(server.url).origin;
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, serviceWorkers: 'block', acceptDownloads: true });
await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin });
await context.addInitScript(INIT);

const waitReady = (page) => page.waitForFunction(
  () => window.__SHINOBI_READY__ === true || (document.readyState === 'complete' && window.__SHINOBI_READY__ === undefined && window.__SHINOBI_STATE__ === undefined && performance.now() > 90000),
  null, { timeout: 120000, polling: 250 }).then(() => page.evaluate(() => window.__SHINOBI_READY__ === true));

const snapshotStorage = (page) => page.evaluate(async () => ({
  localStorage: Object.fromEntries(Object.entries(localStorage)),
  sessionStorage: Object.fromEntries(Object.entries(sessionStorage)),
  cookie: document.cookie,
  idb: indexedDB.databases ? (await indexedDB.databases()).map((d) => d.name) : [],
}));

/** Press a key and capture the download it triggers. */
async function downloadVia(page, key, name) {
  const dl = page.waitForEvent('download', { timeout: 20000 });
  await page.keyboard.press(key);
  const d = await dl;
  const file = path.join(outDir, name);
  await d.saveAs(file);
  return { suggested: d.suggestedFilename(), file, text: readFileSync(file, 'utf8'), bytes: readFileSync(file).length };
}

const consoleMsgs = [];
let exitCode = 1;
try {
  // ------------------------------------------------------------------ debug ON
  const page = await context.newPage();
  page.on('console', (m) => consoleMsgs.push({ type: m.type(), text: m.text() }));
  page.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e).split('\n')[0], expected: /probe-induced/.test(String(e)) }));
  await page.goto(server.url + '?debug=1', { waitUntil: 'load' });
  const hooks = await waitReady(page);
  if (!hooks) {
    console.log('[debug-probe] SKIPPED - hooks absent: __SHINOBI_READY__ was never defined by this build; debug log NOT verified');
    writeFileSync(path.join(outDir, 'debug-probe-result.json'), JSON.stringify({ skipped: 'hooks absent' }, null, 2));
    await browser.close(); await server.close();
    process.exit(0);
  }
  rec('ready-flag', true, '__SHINOBI_READY__ true with ?debug=1');
  await sleep(1500);
  await page.mouse.click(640, 400); // canvas keyboard focus
  await sleep(300);
  await page.screenshot({ path: path.join(outDir, 'debug-on.png') });
  const onShot = (await page.screenshot({ clip: { x: 880, y: 36, width: 400, height: 140 } })).toString('base64');

  const hooksOn = await page.evaluate(() => ({
    hooks: typeof window.__SHINOBI_DEBUG_HOOKS__, cb: typeof window.__SHINOBI_DEBUG_CB__,
    wrapped: console.error !== window.__probeOrigConsole.error && console.warn !== window.__probeOrigConsole.warn,
    listeners: window.__probeListeners.slice(),
  }));
  rec('debug-on-hooks-installed', hooksOn.hooks === 'object' && hooksOn.cb !== 'undefined' && hooksOn.wrapped,
    `hooks=${hooksOn.hooks} callback=${hooksOn.cb} console wrapped=${hooksOn.wrapped}`);

  // network + storage observation window starts here (after ready, before any debug action)
  const requests = [];
  page.on('request', (r) => requests.push({ method: r.method(), url: r.url(), postData: r.postData() }));
  const storageBefore = await snapshotStorage(page);

  // type a unique string (real key presses, no text field is focused)
  await page.keyboard.type(TYPED, { delay: 20 });

  // induce a browser error and an unhandled promise rejection
  await page.evaluate(([m1, m2]) => {
    setTimeout(() => { throw new Error(m1); }, 0);
    Promise.reject(new Error(m2));
  }, [MSG_ERR, MSG_REJ]);
  await sleep(1500);

  // ---- download #1
  const d1 = await downloadVia(page, 'F7', 'debug-log-1.jsonl');
  rec('download-event', /^shinobi-debug-\d{8}-\d{6}-[0-9a-z]+\.jsonl$/.test(d1.suggested), `suggested filename "${d1.suggested}", ${d1.bytes} bytes`);
  let lines = [];
  try { lines = parseJsonl(d1.text); rec('jsonl-parses', lines.length >= 2, `${lines.length} lines (header + ${lines.length - 1} events)`); } catch (e) { rec('jsonl-parses', false, e.message); }
  const header = lines[0];
  const events = lines.slice(1);
  recProblems('header-fields', headerProblems(header), `session ${header && header.session}, schema ${header && header.schema}, build ${header && header.build && header.build.commit_sha}`);
  // Build identity: header SHA and filename vs the SERVED build-info.json of the same export (read from disk, not over the network).
  // Enforced when GITHUB_SHA is set (CI, where godot_ci.py export bakes res://build-info.json); a local run may say "unknown".
  let served = {};
  try { served = JSON.parse(readFileSync(path.join(serveDir, 'build-info.json'), 'utf8')); } catch (e) { served = {}; }
  const idRequired = !!process.env.GITHUB_SHA;
  recProblems('build-identity', buildIdentityProblems({ header, served, filename: d1.suggested, required: idRequired }),
    `header sha "${header && header.build && header.build.commit_sha}" vs served ${String(served.commit_sha).slice(0, 7)}, file ${d1.suggested} (${idRequired ? 'CI: enforced' : 'local: unknown allowed'})`);
  recProblems('events-ordered', eventProblems(events, header && header.session), `${events.length} events with core keys, one session, t_ms non-decreasing`);
  const errEv = findBrowserError(events, MSG_ERR);
  const rejEv = findBrowserError(events, MSG_REJ);
  rec('induced-error-captured', !!errEv && errEv.kind === 'error' && Number.isFinite(errEv.t_ms) && typeof errEv.utc === 'string', errEv ? `kind=${errEv.kind} t_ms=${errEv.t_ms} utc=${errEv.utc}` : 'browser_error event not found');
  rec('induced-rejection-captured', !!rejEv && rejEv.kind === 'unhandledrejection' && Number.isFinite(rejEv.t_ms) && typeof rejEv.utc === 'string', rejEv ? `kind=${rejEv.kind} t_ms=${rejEv.t_ms} utc=${rejEv.utc}` : 'browser_error event not found');
  recProblems('stack-sanitized', [...(errEv ? stackProblems(errEv.stack) : ['no error event']), ...(rejEv ? stackProblems(rejEv.stack) : ['no rejection event'])], 'stacks non-empty, no query strings, local paths or token patterns');
  recProblems('no-leaks-in-log', leaks(d1.text).map((l) => `log matches ${l}`), 'whole export free of token/local-path patterns');
  rec('no-typed-text', !containsTyped(d1.text, TYPED), `unique typed string "${TYPED}" ${containsTyped(d1.text, TYPED) ? 'FOUND in' : 'absent from'} the export`);
  recProblems('size-bounded-1', sizeProblems(d1.bytes, header || {}), `${d1.bytes} bytes`);

  // ---- flood: 20k distinct errors
  const floodMs = await page.evaluate((n) => {
    const t0 = performance.now();
    for (let i = 0; i < n; i++) window.dispatchEvent(new ErrorEvent('error', { message: `flood-${i}-xxxxxxxxxxxxxxxxxxxxxxxx`, filename: 'flood.js', lineno: i % 50, colno: 1 }));
    return performance.now() - t0;
  }, FLOOD);
  await sleep(500);
  const d2 = await downloadVia(page, 'F7', 'debug-log-2-flood.jsonl');
  const lines2 = parseJsonl(d2.text);
  const h2 = lines2[0];
  const floodEvents = lines2.slice(1).filter((e) => e.type === 'browser_error' && String(e.message).startsWith('flood-')).length;
  recProblems('size-bounded-flood', sizeProblems(d2.bytes, h2), `${FLOOD} errors dispatched in ${Math.round(floodMs)} ms -> ${d2.bytes} bytes, ${lines2.length - 1} events, ${floodEvents} flood events kept`);
  rec('flood-dropped', Number(h2.dropped && h2.dropped.total) > 0 && floodEvents < FLOOD, `dropped=${JSON.stringify(h2.dropped)} coalesced=${h2.coalesced}`);
  recProblems('events-ordered-flood', eventProblems(lines2.slice(1), h2.session), 'ordering holds after the flood');

  // ---- Copy Bug Report (clipboard permission granted in the context)
  await page.evaluate(() => navigator.clipboard.writeText('probe-clipboard-sentinel'));
  await page.keyboard.press('F8');
  let clip = '';
  for (let i = 0; i < 40 && (clip === '' || clip === 'probe-clipboard-sentinel'); i++) {
    await sleep(250);
    clip = await page.evaluate(() => navigator.clipboard.readText()).catch(() => '');
  }
  writeFileSync(path.join(outDir, 'bug-report.txt'), clip);
  recProblems('bug-report-copied', reportProblems(clip), `${Buffer.byteLength(clip, 'utf8')} bytes in clipboard`);
  recProblems('bug-report-no-leaks', leaks(clip).map((l) => `report matches ${l}`), 'report free of token/local-path patterns');
  rec('bug-report-no-typed-text', !containsTyped(clip, TYPED), 'typed string absent from the report');

  // ---- privacy: network + storage
  recProblems('no-debug-network', requestProblems(requests, origin), `${requests.length} http(s) requests observed after ready, none cross-origin / non-GET / debug-looking`);
  const storageAfter = await snapshotStorage(page);
  recProblems('no-storage-writes', storageProblems(storageBefore, storageAfter, [header && header.session]),
    `localStorage ${Object.keys(storageAfter.localStorage).length} keys, sessionStorage ${Object.keys(storageAfter.sessionStorage).length} keys, cookie ${storageAfter.cookie ? 'set' : 'empty'}, IndexedDB [${storageAfter.idb.join(',')}] unchanged`);
  await page.close();

  // ------------------------------------------------------------------ debug OFF (default)
  const off = await context.newPage();
  off.on('pageerror', (e) => consoleMsgs.push({ type: 'pageerror', text: String(e).split('\n')[0], expected: /probe-induced/.test(String(e)) }));
  const offDownloads = [];
  off.on('download', (d) => offDownloads.push(d.suggestedFilename()));
  await off.goto(server.url, { waitUntil: 'load' });
  await waitReady(off);
  await sleep(1500);
  await off.mouse.click(640, 400);
  await sleep(300);
  const offShot = (await off.screenshot({ clip: { x: 880, y: 36, width: 400, height: 140 } })).toString('base64');
  const offHooks = await off.evaluate(() => ({
    hooks: typeof window.__SHINOBI_DEBUG_HOOKS__, cb: typeof window.__SHINOBI_DEBUG_CB__,
    wrapped: console.error !== window.__probeOrigConsole.error || console.warn !== window.__probeOrigConsole.warn,
    listeners: window.__probeListeners.slice(),
  }));
  rec('off-no-hooks', offHooks.hooks === 'undefined' && offHooks.cb === 'undefined' && !offHooks.wrapped, `hooks=${offHooks.hooks} callback=${offHooks.cb} console wrapped=${offHooks.wrapped}`);
  const onL = listenerCount(hooksOn.listeners, 'error') + listenerCount(hooksOn.listeners, 'unhandledrejection');
  const offL = listenerCount(offHooks.listeners, 'error') + listenerCount(offHooks.listeners, 'unhandledrejection');
  rec('off-no-listeners', offL < onL && onL - offL === 2, `error+unhandledrejection listeners registered: debug ON ${onL}, OFF ${offL} (debug adds exactly 2)`);
  const pxOn = await off.evaluate(countIndicatorPixels, { pngBase64: onShot, w: 400, h: 140 });
  const pxOff = await off.evaluate(countIndicatorPixels, { pngBase64: offShot, w: 400, h: 140 });
  rec('off-no-indicator', pxOn - pxOff >= 20, `DEBUG ON indicator-coloured pixels in the top-right panel area: ON ${pxOn}, OFF ${pxOff}`);
  await off.evaluate((m) => { setTimeout(() => { throw new Error(m); }, 0); }, `probe-induced-off-${TAG}`);
  await off.keyboard.press('F7');
  await off.keyboard.press('F8');
  await sleep(2000);
  rec('off-no-export', offDownloads.length === 0, offDownloads.length ? `unexpected downloads: ${offDownloads.join(',')}` : 'F7/F8 do nothing while debug is off (no download)');
  await off.screenshot({ path: path.join(outDir, 'debug-off.png') });
  await off.close();
} catch (e) {
  rec('probe-exception', false, String(e.message ?? e).split('\n')[0]);
}
const bad = consoleMsgs.filter((m) => (m.type === 'pageerror' && !m.expected));
rec('no-unexpected-page-errors', bad.length === 0, `${consoleMsgs.length} console messages, ${bad.length} unexpected pageerror (induced errors are expected)`);
writeFileSync(path.join(outDir, 'debug-probe-result.json'), JSON.stringify({ results, console: consoleMsgs.slice(0, 200) }, null, 2));
exitCode = results.every((r) => r.ok) ? 0 : 1;
await browser.close(); await server.close();
console.log(`[debug-probe] VERDICT ${exitCode === 0 ? 'PASS' : 'FAIL'}`);
process.exit(exitCode);
