// Unit tests for the console policy. Samples are REAL Godot 4.7.2 Web (debug template) console events
// captured during design verification (Chromium 156 / Playwright 1.64.1).
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyStream,
  classifyRequestFailure,
  classifyHttpStatus,
  extractEngineEvidence,
} from './console-policy.mjs';

const log = (text) => ({ type: 'log', text });
const err = (text) => ({ type: 'error', text });
const warn = (text) => ({ type: 'warning', text });
const levels = (msgs, allow = []) => classifyStream(msgs, allow).map((m) => m.level);

test('healthy startup banner and print() output are info', () => {
  const msgs = [
    log('Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org'),
    log('OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility - Using Device: WebKit - WebKit WebGL'),
    log('Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.'),
    log('SELFTEST_READY'),
  ];
  assert.deepEqual(levels(msgs), ['info', 'info', 'info', 'info']);
});

test('SwiftShader GL driver warnings (console type warning) are warnings, never fatal', () => {
  const m = warn('[.WebGL-0x71d40c37dc00]GL Driver Message (OpenGL, Performance, GL_CLOSE_PATH_NV, High): GPU stall due to ReadPixels');
  assert.deepEqual(levels([m]), ['warn']);
});

test('Godot WARNING block (header + indented continuation lines delivered as separate console.error) is warn', () => {
  const msgs = [
    err('WARNING: SELFTEST_INTENTIONAL_WARNING'),
    err('   at: push_warning (core/variant/variant_utility.cpp:1033)'),
    err('   GDScript backtrace (most recent call first):'),
    err('       [0] _ready (res://main.gd:26)'),
  ];
  assert.deepEqual(levels(msgs), ['warn', 'warn', 'warn', 'warn']);
});

test('SCRIPT ERROR block is fatal including continuation lines', () => {
  const msgs = [
    err("SCRIPT ERROR: Invalid call. Nonexistent function 'selftest_nonexistent_method' in base 'Nil'."),
    err('   at: _ready (res://main.gd:27)'),
    err('   GDScript backtrace (most recent call first):'),
    err('       [0] _ready (res://main.gd:27)'),
  ];
  assert.deepEqual(levels(msgs), ['fatal', 'fatal', 'fatal', 'fatal']);
});

test('push_error output (ERROR: ...) is fatal', () => {
  assert.deepEqual(levels([err('ERROR: SELFTEST_INTENTIONAL_STARTUP_ERROR')]), ['fatal']);
});

test('plain console.error is fatal; plain console.warn is not', () => {
  assert.deepEqual(levels([err('something broke')]), ['fatal']);
  assert.deepEqual(levels([warn('The AudioContext was not allowed to start.')]), ['warn']);
});

test('a WARNING block does not leak its level onto a following unrelated console.error', () => {
  const msgs = [err('WARNING: a'), err('   at: x'), err('unrelated failure')];
  assert.deepEqual(levels(msgs), ['warn', 'warn', 'fatal']);
});

test('missing-web-features notice and wasm runtime errors are fatal even when logged as log', () => {
  assert.deepEqual(levels([log('Error\nThe following features required to run Godot projects on the Web are missing:\nCross-Origin Isolation')]), ['fatal']);
  assert.deepEqual(levels([log('RuntimeError: memory access out of bounds')]), ['fatal']);
  assert.deepEqual(levels([log('WebGL: CONTEXT_LOST_WEBGL: loseContext: context lost')]), ['fatal']);
});

test('allowlist downgrades a matching message and its continuation lines', () => {
  const allow = [{ pattern: '^ERROR: known benign thing', reason: 'tracked in issue #1' }];
  const msgs = [err('ERROR: known benign thing happened'), err('   at: somewhere (x.cpp:1)')];
  assert.deepEqual(levels(msgs, allow), ['info', 'info']);
});

test('request failures: ERR_ABORTED (Godot streaming wasm) is benign, other failures are fatal', () => {
  assert.equal(classifyRequestFailure({ url: 'http://127.0.0.1:1/index.wasm', errorText: 'net::ERR_ABORTED' }).level, 'info');
  assert.equal(classifyRequestFailure({ url: 'http://127.0.0.1:1/index.pck', errorText: 'net::ERR_CONNECTION_REFUSED' }).level, 'fatal');
});

test('HTTP statuses: >=400 fatal except favicon', () => {
  assert.equal(classifyHttpStatus({ url: 'http://h/index.pck', status: 200 }).level, 'info');
  assert.equal(classifyHttpStatus({ url: 'http://h/index.pck', status: 404 }).level, 'fatal');
  assert.equal(classifyHttpStatus({ url: 'http://h/index.wasm', status: 503 }).level, 'fatal');
  assert.equal(classifyHttpStatus({ url: 'http://h/favicon.ico', status: 404 }).level, 'warn');
});

test('engine evidence extraction', () => {
  const ev = extractEngineEvidence([
    log('Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org'),
    log('OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility - Using Device: WebKit - WebKit WebGL'),
    log('Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.'),
  ]);
  assert.equal(ev.singleThreaded, true);
  assert.equal(ev.compatibilityRenderer, true);
  const bad = extractEngineEvidence([log('Build configuration: Emscripten 4.0.20, multi-threaded, no GDExtension support.')]);
  assert.equal(bad.singleThreaded, false);
  assert.equal(extractEngineEvidence([]).singleThreaded, null);
});
