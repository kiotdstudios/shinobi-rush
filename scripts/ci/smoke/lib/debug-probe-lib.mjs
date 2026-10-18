// Pure helpers for debug-probe.mjs (no browser needed, unit-tested in debug-probe-lib.test.mjs).
// They validate the JSONL debug log written by the BrowserDebug autoload (docs/development/DEBUG_LOG_INTERFACE.md).

export const HEADER_KEYS = ['type', 'schema', 'session', 'utc_start', 'build', 'env', 'limits', 'dropped'];
export const EVENT_KEYS = ['t_ms', 'utc', 'session', 'build', 'frame', 'type'];
export const BUILD_KEYS = ['commit_sha', 'run_id', 'godot', 'page_url'];
export const ENV_KEYS = ['userAgent', 'platform', 'language', 'screen', 'devicePixelRatio', 'hardwareConcurrency'];
export const LIMIT_KEYS = ['max_events', 'max_bytes', 'window_ms'];
/** Anything that looks like a secret or a private local path must never survive sanitizing. */
export const LEAK_PATTERNS = [
  /ghp_[A-Za-z0-9]{10,}/, /gho_[A-Za-z0-9]{10,}/, /github_pat_[A-Za-z0-9_]{10,}/, /AKIA[0-9A-Z]{12,}/,
  /Bearer\s+[A-Za-z0-9._~+/-]{8,}/i, /file:\/\/\/[A-Za-z]:/i, /[A-Za-z]:\\Users\\/i, /\/home\/[^/\s]+\//, /\/Users\/[^/\s]+\//,
];

/** Parse a JSONL string. Throws with the 1-based line number on bad JSON. Blank trailing line is allowed. */
export function parseJsonl(text) {
  const lines = String(text).split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  return lines.map((l, i) => {
    try { return JSON.parse(l); } catch (e) { throw new Error(`JSONL line ${i + 1} is not valid JSON: ${e.message}`); }
  });
}

/** Returns a list of problems (empty = ok) for the session header (first JSONL line). */
export function headerProblems(h) {
  const p = [];
  if (!h || typeof h !== 'object') return ['header is not an object'];
  for (const k of HEADER_KEYS) if (!(k in h)) p.push(`header missing "${k}"`);
  if (h.type !== 'session_header') p.push(`header type is "${h.type}", expected session_header`);
  if (typeof h.session !== 'string' || !/^[0-9a-f]{12}$/.test(h.session)) p.push(`session "${h.session}" is not 12 hex chars`);
  if (typeof h.utc_start !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(h.utc_start)) p.push(`utc_start "${h.utc_start}" is not ISO UTC`);
  for (const k of BUILD_KEYS) if (!(h.build && k in h.build)) p.push(`build missing "${k}"`);
  for (const k of ENV_KEYS) if (!(h.env && k in h.env)) p.push(`env missing "${k}"`);
  for (const k of LIMIT_KEYS) if (!(h.limits && Number.isFinite(h.limits[k]))) p.push(`limits.${k} missing or not a number`);
  if (!h.dropped || !Number.isFinite(h.dropped.total)) p.push('dropped.total missing or not a number');
  return p;
}

/**
 * Build identity of a downloaded log vs the SERVED build-info.json of the same export.
 * required=true (CI, GITHUB_SHA set): header.build.commit_sha must equal served.commit_sha and the filename must carry its first 7 chars.
 * required=false (local run without CI env): the header may be empty and the filename "unknown"; a non-empty SHA must still match.
 */
export function buildIdentityProblems({ header, served, filename, required }) {
  const p = [];
  const want = served && typeof served.commit_sha === 'string' ? served.commit_sha : '';
  if (!/^[0-9a-f]{40}$/.test(want)) return ['served build-info.json has no 40-hex commit_sha'];
  const got = header && header.build && typeof header.build.commit_sha === 'string' ? header.build.commit_sha : '';
  const m = /^shinobi-debug-\d{8}-\d{6}-([0-9a-z]+)\.(jsonl|txt)$/.exec(filename || '');
  const tag = m ? m[1] : '';
  if (!m) p.push(`filename "${filename}" does not match shinobi-debug-<UTC>-<short sha>.jsonl`);
  if (got !== '' && got !== want) p.push(`header build.commit_sha "${got}" != served build-info commit_sha "${want}"`);
  if (tag !== 'unknown' && tag !== want.slice(0, 7)) p.push(`filename tag "${tag}" is neither "unknown" nor the short SHA ${want.slice(0, 7)}`);
  if (required) {
    if (got !== want) p.push(`CI run: header build.commit_sha must equal "${want}" (got "${got}")`);
    if (tag !== want.slice(0, 7)) p.push(`CI run: filename must carry the short SHA ${want.slice(0, 7)} (got "${tag}")`);
  }
  return p;
}

/** Returns problems for the event lines: core keys present, one session id, t_ms non-decreasing. */
export function eventProblems(events, session) {
  const p = [];
  let prev = -Infinity;
  events.forEach((e, i) => {
    for (const k of EVENT_KEYS) if (!(k in e)) p.push(`event ${i} missing "${k}"`);
    if (session && e.session !== session) p.push(`event ${i} session "${e.session}" != header session`);
    if (typeof e.t_ms !== 'number') p.push(`event ${i} t_ms is not a number`);
    else if (e.t_ms < prev) p.push(`event ${i} t_ms ${e.t_ms} goes backwards (previous ${prev})`);
    else prev = e.t_ms;
  });
  return p.slice(0, 20);
}

/** First browser_error event whose message contains needle, or undefined. */
export function findBrowserError(events, needle) {
  return events.find((e) => e.type === 'browser_error' && String(e.message).includes(needle));
}

/** Problems for a stack string that must already be sanitized (no query/hash, no local paths, no secrets). */
export function stackProblems(stack) {
  const p = [];
  if (typeof stack !== 'string' || stack.length === 0) return ['stack is empty'];
  if (stack.length > 4000) p.push(`stack is ${stack.length} chars (cap expected)`);
  if (/https?:\/\/[^\s)]*[?#]/.test(stack)) p.push('stack still contains a URL query string or hash');
  for (const re of LEAK_PATTERNS) if (re.test(stack)) p.push(`stack matches leak pattern ${re}`);
  return p;
}

/** True when any leak pattern matches the text (used on the whole export and the bug report). */
export function leaks(text) {
  return LEAK_PATTERNS.filter((re) => re.test(text)).map(String);
}

/** Typed-text check: true when the marker, or its letters as consecutive key events, appear anywhere in the export. */
export function containsTyped(text, marker) {
  if (text.includes(marker)) return true;
  const lower = text.toLowerCase();
  return lower.includes(marker.toLowerCase());
}

/** Compare two storage snapshots {localStorage:{}, sessionStorage:{}, cookie:'', idb:[names]}. Returns problems. */
export function storageProblems(before, after, secretNeedles = []) {
  const p = [];
  for (const area of ['localStorage', 'sessionStorage']) {
    const b = before[area] || {};
    const a = after[area] || {};
    for (const k of Object.keys(a)) if (!(k in b)) p.push(`${area} gained key "${k}"`);
    for (const k of Object.keys(a)) if (k in b && b[k] !== a[k]) p.push(`${area} key "${k}" changed`);
  }
  if ((before.cookie || '') !== (after.cookie || '')) p.push('document.cookie changed');
  const bi = new Set(before.idb || []);
  for (const n of after.idb || []) if (!bi.has(n)) p.push(`IndexedDB database "${n}" was created`);
  const blob = JSON.stringify(after);
  for (const s of secretNeedles) if (s && blob.includes(s)) p.push(`storage contains "${s}"`);
  return p;
}

/** Classify requests seen after the page was ready. Anything not a same-origin GET is a violation. */
export function requestProblems(requests, origin) {
  const p = [];
  for (const r of requests) {
    let u;
    try { u = new URL(r.url); } catch { continue; }
    if (u.protocol !== 'http:' && u.protocol !== 'https:') continue; // blob:/data: are not network
    if (u.origin !== origin) p.push(`cross-origin request ${r.method} ${r.url}`);
    else if (r.method !== 'GET') p.push(`non-GET request ${r.method} ${r.url}`);
    else if (r.postData) p.push(`request with body ${r.url}`);
    else if (/debug|telemetry|beacon|report|upload/i.test(u.pathname + u.search)) p.push(`suspicious debug-looking request ${r.url}`);
  }
  return p;
}

/** Log-size bound: the file must stay near the documented max_bytes (plus header and slack). */
export function sizeProblems(bytes, header, slack = 64 * 1024) {
  const max = (header.limits && header.limits.max_bytes) || 0;
  return bytes <= max + slack ? [] : [`export is ${bytes} bytes, above limits.max_bytes ${max} + ${slack}`];
}

/** Clipboard bug report checks. */
export function reportProblems(text, maxBytes = 200 * 1024) {
  const p = [];
  if (!text.startsWith('SHINOBI RUSH BUG REPORT')) p.push('report does not start with the SHINOBI RUSH BUG REPORT title');
  if (!text.includes('LAST ERROR:')) p.push('report has no LAST ERROR line');
  if (!/LAST \d+ EVENTS:/.test(text)) p.push('report has no LAST n EVENTS section');
  const n = Buffer.byteLength(text, 'utf8');
  if (n > maxBytes) p.push(`report is ${n} bytes, above ${maxBytes}`);
  const m = /LAST (\d+) EVENTS:/.exec(text);
  if (m && Number(m[1]) > 100) p.push(`report lists ${m[1]} events, above 100`);
  return p;
}

/** Number of listeners the page registered per type, from the init-script log [{type}]. */
export function listenerCount(log, type) {
  return log.filter((e) => e === type).length;
}

/** Runs in the browser: counts pixels close to the indicator red (255,89,77) inside the clip. Self-contained. */
export async function countIndicatorPixels({ pngBase64, w, h }) {
  const img = new Image();
  img.src = 'data:image/png;base64,' + pngBase64;
  await img.decode();
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0, w, h);
  const d = ctx.getImageData(0, 0, w, h).data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) {
    if (Math.abs(d[i] - 255) < 24 && Math.abs(d[i + 1] - 89) < 24 && Math.abs(d[i + 2] - 77) < 24) n++;
  }
  return n;
}
