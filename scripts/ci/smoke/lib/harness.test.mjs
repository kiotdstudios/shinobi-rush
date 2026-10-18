// Unit tests for the harness building blocks that do not need a browser.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { parseCli, UsageError, DEFAULTS } from './args.mjs';
import { sanitize, mdCell, summaryMarkdown } from './report.mjs';
import { isBlank, BLANK_DOMINANT_RATIO } from './pixels.mjs';
import { startStaticServer } from './serve.mjs';
import { readReadyHook, readyHookVerdict } from './steps.mjs';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const SHA = '0123456789abcdef0123456789abcdef01234567';
const parse = (argv) => parseCli(argv, { here: path.join(here, '..'), env: {} });

test('args: --out-dir is required; exactly one target is required', () => {
  assert.throws(() => parse(['--serve-dir', 'x']), UsageError);
  assert.throws(() => parse(['--out-dir', 'o']), UsageError);
  assert.throws(() => parse(['--out-dir', 'o', '--serve-dir', 'x', '--base-url', 'https://h/']), UsageError);
});

test('args: deployed mode needs https and a 40-hex expected sha', () => {
  assert.throws(() => parse(['--out-dir', 'o', '--base-url', 'https://h/']), UsageError);
  assert.throws(() => parse(['--out-dir', 'o', '--base-url', 'http://h/', '--expected-sha', SHA]), UsageError);
  assert.throws(() => parse(['--out-dir', 'o', '--base-url', 'https://h/', '--expected-sha', 'ABC']), UsageError);
  assert.equal(parse(['--out-dir', 'o', '--base-url', 'https://h/', '--expected-sha', SHA]).mode, 'deployed');
});

test('args: an EMPTY --expected-sha (a renamed or unset workflow variable) is a usage error in both modes, never a skipped check', () => {
  assert.throws(() => parse(['--out-dir', 'o', '--serve-dir', 'x', '--expected-sha', '']), UsageError);
  assert.throws(() => parse(['--out-dir', 'o', '--base-url', 'https://h/', '--expected-sha', '']), UsageError);
});

test('args: config file defaults are overridden by CLI flags; input steps are validated', () => {
  const p = parse(['--out-dir', 'o', '--serve-dir', 'x', '--input-sequence', 'ArrowRight:150', '--require-input-effect', '--settle-ms', '10']);
  assert.deepEqual(p.cfg.input_sequence, ['ArrowRight:150']);
  assert.equal(p.cfg.require_input_effect, true);
  assert.equal(p.cfg.settle_ms, 10);
  assert.equal(p.cfg.canvas_selector, DEFAULTS.canvas_selector);
  assert.throws(() => parse(['--out-dir', 'o', '--serve-dir', 'x', '--input-sequence', 'Key D:abc']), UsageError);
});

test('report: sanitize defuses workflow commands and control characters', () => {
  assert.equal(sanitize('::error::boom'), ':\u200b:error::boom');
  assert.equal(sanitize('a\n  ::stop-commands::x'), 'a\n  :\u200b:stop-commands::x');
  assert.equal(sanitize('a\u0000b\r'), 'ab');
  assert.equal(mdCell('a|b`c\nd'), "a\\|b'c d");
});

test('report: summary contains verdict, checks and first fatal events', () => {
  const md = summaryMarkdown({
    label: 'x', mode: 'local', baseUrl: 'http://127.0.0.1:1/', verdict: 'FAIL', durationMs: 1500,
    checks: [{ name: 'engine-start', status: 'fail', detail: 'status notice shown' }],
    events: [{ level: 'fatal', rule: 'godot-error', text: 'SCRIPT ERROR: boom' }, { level: 'warn', rule: 'w', text: 'w' }],
  });
  assert.match(md, /Verdict: FAIL/);
  assert.match(md, /\| engine-start \| FAIL \|/);
  assert.match(md, /fatal: 1/);
  assert.match(md, /SCRIPT ERROR: boom/);
});

test('pixels: blank detection thresholds', () => {
  assert.equal(isBlank({ distinctColors: 1, dominantRatio: 1, transparentRatio: 0 }), true);
  assert.equal(isBlank({ distinctColors: 5, dominantRatio: BLANK_DOMINANT_RATIO, transparentRatio: 0 }), true);
  assert.equal(isBlank({ distinctColors: 5, dominantRatio: 0.2, transparentRatio: 1 }), true);
  assert.equal(isBlank({ distinctColors: 22, dominantRatio: 0.25, transparentRatio: 0 }), false);
});

// The real game will announce itself with window.__SHINOBI_READY__ = true (JavaScriptBridge), so this path is pinned without a browser.
const fakePage = ({ becomesTrue, typeofHook }) => ({
  waitForFunction: async () => { if (!becomesTrue) throw new Error('Timeout 5000ms exceeded'); },
  evaluate: async () => typeofHook,
});

test('ready hook: readReadyHook tells ready / absent / defined-but-never-true apart', async () => {
  assert.equal(await readReadyHook(fakePage({ becomesTrue: true, typeofHook: 'boolean' }), 10), 'ready');
  assert.equal(await readReadyHook(fakePage({ becomesTrue: false, typeofHook: 'undefined' }), 10), 'absent');
  assert.equal(await readReadyHook(fakePage({ becomesTrue: false, typeofHook: 'boolean' }), 10), 'not-ready');
  assert.equal(await readReadyHook(fakePage({ becomesTrue: false, typeofHook: 'string' }), 10), 'not-ready');
});

test('ready hook: verdict per state, optional or required', () => {
  assert.equal(readyHookVerdict('ready', false).status, 'pass');
  assert.equal(readyHookVerdict('ready', true).status, 'pass');
  assert.equal(readyHookVerdict('absent', false).status, 'skip');
  assert.equal(readyHookVerdict('absent', true).status, 'fail');
  assert.match(readyHookVerdict('absent', true).detail, /--require-ready-hook/);
  assert.equal(readyHookVerdict('not-ready', false).status, 'fail', 'a defined hook that never becomes true is always a failure');
  assert.equal(readyHookVerdict('not-ready', true).status, 'fail');
  assert.match(readyHookVerdict('not-ready', false).detail, /never became true/);
});

test('ready hook: --require-ready-hook and the config key reach the verdict', () => {
  // --config points at a missing file so the DEFAULTS are tested, not whatever smoke-config.json currently ships.
  const noConfig = ['--config', path.join(here, 'no-such-smoke-config.json')];
  assert.equal(parse(['--out-dir', 'o', '--serve-dir', 'x', ...noConfig]).cfg.require_ready_hook, false);
  assert.equal(parse(['--out-dir', 'o', '--serve-dir', 'x', ...noConfig, '--require-ready-hook']).cfg.require_ready_hook, true);
});

test('serve: mirrors GitHub Pages (wasm MIME, no COOP/COEP, no traversal, GET/HEAD only)', async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'serve-test-'));
  try {
    mkdirSync(path.join(dir, 'sub'));
    writeFileSync(path.join(dir, 'index.html'), '<html>ok</html>');
    writeFileSync(path.join(dir, 'index.wasm'), Buffer.from([0, 0x61, 0x73, 0x6d]));
    writeFileSync(path.join(path.dirname(dir), 'secret.txt'), 'outside');
    const srv = await startStaticServer(dir);
    try {
      const root = await fetch(srv.url);
      assert.equal(root.status, 200);
      assert.match(root.headers.get('content-type'), /text\/html/);
      assert.equal(root.headers.get('cross-origin-opener-policy'), null);
      assert.equal(root.headers.get('cross-origin-embedder-policy'), null);
      const wasm = await fetch(new URL('index.wasm', srv.url));
      assert.equal(wasm.headers.get('content-type'), 'application/wasm');
      assert.equal((await fetch(new URL('missing.js', srv.url))).status, 404);
      assert.notEqual((await fetch(new URL('..%2Fsecret.txt', srv.url))).status, 200);
      assert.equal((await fetch(srv.url, { method: 'POST' })).status, 405);
      assert.equal((await fetch(srv.url, { method: 'HEAD' })).status, 200);
    } finally {
      await srv.close();
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(path.join(path.dirname(dir), 'secret.txt'), { force: true });
  }
});
