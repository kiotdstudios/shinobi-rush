// Unit tests for the debug probe helpers (no browser).
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseJsonl, headerProblems, eventProblems, findBrowserError, stackProblems, leaks, containsTyped,
  storageProblems, requestProblems, sizeProblems, reportProblems, listenerCount, buildIdentityProblems,
} from './debug-probe-lib.mjs';

const header = () => ({
  type: 'session_header', schema: 1, session: 'abcdef012345', utc_start: '2026-10-18T12:00:00Z',
  build: { commit_sha: 'a', run_id: '', godot: '4.7', page_url: 'http://x/' },
  env: { userAgent: 'u', platform: 'p', language: 'en', screen: {}, devicePixelRatio: 1, hardwareConcurrency: 2 },
  limits: { max_events: 5000, max_bytes: 2097152, window_ms: 600000 }, dropped: { total: 0 },
});
const ev = (t, type = 'state', extra = {}) => ({ t_ms: t, utc: 'x', session: 'abcdef012345', build: 'a', frame: 1, type, ...extra });

test('parseJsonl parses lines and reports the failing line', () => {
  assert.deepEqual(parseJsonl('{"a":1}\n{"b":2}\n'), [{ a: 1 }, { b: 2 }]);
  assert.throws(() => parseJsonl('{"a":1}\nnope\n'), /line 2/);
});

test('headerProblems accepts a good header and flags missing parts', () => {
  assert.deepEqual(headerProblems(header()), []);
  const h = header(); delete h.limits.max_bytes; delete h.env.userAgent; h.session = 'zz';
  const p = headerProblems(h).join('|');
  assert.match(p, /limits\.max_bytes/); assert.match(p, /env missing "userAgent"/); assert.match(p, /12 hex/);
  assert.deepEqual(headerProblems(null), ['header is not an object']);
});

test('eventProblems checks core keys, session and ordering', () => {
  assert.deepEqual(eventProblems([ev(1), ev(1), ev(5)], 'abcdef012345'), []);
  assert.match(eventProblems([ev(5), ev(3)], 'abcdef012345').join('|'), /goes backwards/);
  assert.match(eventProblems([{ t_ms: 1 }], null).join('|'), /missing "utc"/);
  assert.match(eventProblems([ev(1)], 'other').join('|'), /session/);
});

test('findBrowserError matches type and message', () => {
  const evs = [ev(1, 'state', { message: 'boom' }), ev(2, 'browser_error', { message: 'Error: boom-1' })];
  assert.equal(findBrowserError(evs, 'boom-1').t_ms, 2);
  assert.equal(findBrowserError(evs, 'nope'), undefined);
});

test('stackProblems accepts sanitized stacks and rejects leaks', () => {
  assert.deepEqual(stackProblems('Error: x\n    at f (app.js:1:2)'), []);
  assert.match(stackProblems('at f (http://h/a.js?v=1:1:2)').join(), /query/);
  assert.match(stackProblems('at f (file:///C:/Users/bob/a.js:1:2)').join(), /leak/);
  assert.match(stackProblems('token ghp_abcdefghijklmnop').join(), /leak/);
  assert.deepEqual(stackProblems(''), ['stack is empty']);
  assert.match(stackProblems('a'.repeat(5000)).join(), /cap/);
});

test('leaks and containsTyped', () => {
  assert.deepEqual(leaks('plain text'), []);
  assert.equal(leaks('Authorization: Bearer abcdefghijkl').length, 1);
  assert.equal(containsTyped('x XQZV7733 y', 'xqzv7733'), true);
  assert.equal(containsTyped('nothing here', 'xqzv7733'), false);
});

test('storageProblems flags new keys, changes, cookies, IndexedDB and secrets', () => {
  const base = { localStorage: { a: '1' }, sessionStorage: {}, cookie: '', idb: ['/userfs'] };
  assert.deepEqual(storageProblems(base, structuredClone(base)), []);
  const after = { localStorage: { a: '2', b: 'x' }, sessionStorage: { s: '1' }, cookie: 'c=1', idb: ['/userfs', 'dbg'] };
  const p = storageProblems(base, after, ['abcdef012345']).join('|');
  assert.match(p, /gained key "b"/); assert.match(p, /key "a" changed/); assert.match(p, /sessionStorage gained/);
  assert.match(p, /cookie/); assert.match(p, /"dbg" was created/);
  assert.match(storageProblems(base, { ...base, localStorage: { a: '1', n: 'abcdef012345' } }, ['abcdef012345']).join(), /contains/);
});

test('requestProblems allows same-origin GET and ignores blob/data', () => {
  const o = 'http://127.0.0.1:5000';
  assert.deepEqual(requestProblems([
    { method: 'GET', url: o + '/index.pck' }, { method: 'GET', url: 'blob:http://127.0.0.1:5000/uuid' }, { method: 'GET', url: 'data:text/plain,x' },
  ], o), []);
  const p = requestProblems([
    { method: 'POST', url: o + '/x' }, { method: 'GET', url: 'https://evil.example/log' },
    { method: 'GET', url: o + '/api/debug-upload' }, { method: 'GET', url: o + '/a', postData: 'x' },
  ], o).join('|');
  assert.match(p, /non-GET/); assert.match(p, /cross-origin/); assert.match(p, /suspicious/); assert.match(p, /with body/);
});

test('sizeProblems bounds the export by limits.max_bytes', () => {
  const h = header();
  assert.deepEqual(sizeProblems(1000, h), []);
  assert.deepEqual(sizeProblems(2097152 + 1000, h), []);
  assert.match(sizeProblems(5 * 1024 * 1024, h).join(), /above/);
});

test('reportProblems checks title, sections and size', () => {
  const ok = 'SHINOBI RUSH BUG REPORT\n{}\nLAST ERROR: none\nLAST 3 EVENTS:\n{}\n';
  assert.deepEqual(reportProblems(ok), []);
  assert.match(reportProblems('hello').join('|'), /title/);
  assert.match(reportProblems(ok + 'x'.repeat(300000)).join(), /bytes/);
  assert.match(reportProblems(ok.replace('LAST 3', 'LAST 400')).join(), /above 100/);
});

test('listenerCount counts registrations by type', () => {
  assert.equal(listenerCount(['error', 'load', 'error', 'unhandledrejection'], 'error'), 2);
  assert.equal(listenerCount([], 'error'), 0);
});

test('buildIdentityProblems: CI needs header SHA == served SHA and the short SHA in the filename', () => {
  const sha = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const good = { header: { build: { commit_sha: sha } }, served: { commit_sha: sha }, filename: 'shinobi-debug-20261018-153016-a1b2c3d.jsonl', required: true };
  assert.deepEqual(buildIdentityProblems(good), []);
  assert.ok(buildIdentityProblems({ ...good, header: { build: { commit_sha: '' } } }).length >= 1);
  assert.ok(buildIdentityProblems({ ...good, header: { build: { commit_sha: 'f'.repeat(40) } } }).length >= 1);
  assert.ok(buildIdentityProblems({ ...good, filename: 'shinobi-debug-20261018-153016-unknown.jsonl' }).length >= 1);
  assert.ok(buildIdentityProblems({ ...good, filename: 'shinobi-debug-20261018-153016-deadbee.jsonl' }).length >= 1);
  assert.ok(buildIdentityProblems({ ...good, served: {} }).length >= 1);
});

test('buildIdentityProblems: local runs may say unknown but never a wrong SHA', () => {
  const sha = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const local = { header: { build: { commit_sha: '' } }, served: { commit_sha: sha }, filename: 'shinobi-debug-20261018-153016-unknown.jsonl', required: false };
  assert.deepEqual(buildIdentityProblems(local), []);
  assert.ok(buildIdentityProblems({ ...local, header: { build: { commit_sha: 'f'.repeat(40) } } }).length >= 1);
  assert.ok(buildIdentityProblems({ ...local, filename: 'weird.jsonl' }).length >= 1);
});
