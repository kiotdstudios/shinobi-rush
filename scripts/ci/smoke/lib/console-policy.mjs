// Pure functions (no Playwright import) so they can be unit tested with `node --test`.

/** Console text patterns that are fatal regardless of console message type. */
export const FATAL_TEXT_PATTERNS = [
  { id: 'godot-error', re: /(^|\n)\s*(USER )?(SCRIPT )?ERROR:/ },
  { id: 'webgl-context-lost', re: /webgl.*context.*lost|CONTEXT_LOST_WEBGL/i },
  { id: 'wasm-runtime', re: /RuntimeError:|Aborted\(|\babort\(|WebAssembly\.(instantiate|compile)\w*\(\)|\bCompileError\b|\bLinkError\b|memory access out of bounds|unreachable executed/i },
  { id: 'missing-web-features', re: /following features required to run Godot projects on the Web are missing/i },
  { id: 'resource-load', re: /Failed to load resource|Failed to fetch|Failed loading resource|Couldn't load project data|Failed to load \.pck|\.pck.*(not found|failed)/i },
  { id: 'uncaught', re: /\bUncaught\b/ },
];

/** Godot prints WARNING: lines through console.error; they are recorded but never fatal. */
export const GODOT_WARNING_RE = /^\s*WARNING:/;

/**
 * Classify one browser console message.
 * @returns {{level: 'fatal'|'warn'|'info', rule: string}}
 */
export function classifyConsoleMessage({ type, text }, allowlist = []) {
  for (const entry of allowlist) {
    if (new RegExp(entry.pattern).test(text)) return { level: 'info', rule: `allowlisted: ${entry.reason ?? entry.pattern}` };
  }
  if (GODOT_WARNING_RE.test(text) && !/(^|\n)\s*(USER )?(SCRIPT )?ERROR:/.test(text)) {
    return { level: 'warn', rule: 'godot-warning' };
  }
  for (const { id, re } of FATAL_TEXT_PATTERNS) {
    if (re.test(text)) return { level: 'fatal', rule: id };
  }
  if (type === 'error') return { level: 'fatal', rule: 'console.error' };
  if (type === 'warning') return { level: 'warn', rule: 'console.warning' };
  return { level: 'info', rule: 'log' };
}

const GODOT_HEADER_RE = /^\s*(USER )?(SCRIPT )?(ERROR|WARNING):/;

/**
 * Classify a whole console stream in order. Godot prints multi-line diagnostics
 * ("WARNING: msg", "   at: ...", "   GDScript backtrace ...", "       [0] ...") as SEPARATE
 * console.error events, so indented continuation lines inherit the level of the header line.
 * @param {{type: string, text: string}[]} messages
 */
export function classifyStream(messages, allowlist = []) {
  const out = [];
  let block = null;
  for (const m of messages) {
    let cls;
    if (GODOT_HEADER_RE.test(m.text)) {
      cls = classifyConsoleMessage(m, allowlist);
      block = { level: cls.level, rule: cls.rule };
    } else if (block && m.type === 'error' && /^\s+\S/.test(m.text)) {
      cls = { level: block.level, rule: `${block.rule} (continuation)` };
    } else {
      block = null;
      cls = classifyConsoleMessage(m, allowlist);
    }
    out.push({ ...m, ...cls });
  }
  return out;
}

/** Request failures: Godot's streaming wasm fetch is reported as ERR_ABORTED even on success. */
export function classifyRequestFailure({ url, errorText }, allowlist = []) {
  if (/net::ERR_ABORTED/.test(errorText ?? '')) return { level: 'info', rule: 'client-abort (benign)' };
  for (const entry of allowlist) if (new RegExp(entry.pattern).test(url)) return { level: 'info', rule: `allowlisted: ${entry.reason ?? entry.pattern}` };
  return { level: 'fatal', rule: 'request-failed' };
}

/** HTTP status >= 400 on any response. */
export function classifyHttpStatus({ url, status }, allowlist = []) {
  if (status < 400) return { level: 'info', rule: 'ok' };
  for (const entry of allowlist) if (new RegExp(entry.pattern).test(url)) return { level: 'warn', rule: `allowlisted: ${entry.reason ?? entry.pattern}` };
  if (/\/favicon\.ico$/.test(url)) return { level: 'warn', rule: 'favicon (benign)' };
  return { level: 'fatal', rule: `http-${status}` };
}

/** Pull the engine's own build/renderer evidence from the console log. */
export function extractEngineEvidence(messages) {
  const texts = messages.map((m) => m.text);
  const build = texts.find((t) => /^Build configuration:/.test(t)) ?? null;
  const gl = texts.find((t) => /^OpenGL API /.test(t)) ?? null;
  const version = texts.find((t) => /^Godot Engine v\d/.test(t)) ?? null;
  return {
    version,
    build,
    gl,
    singleThreaded: build ? /single-threaded/.test(build) : null,
    compatibilityRenderer: gl ? /- Compatibility -/.test(gl) : null,
  };
}
