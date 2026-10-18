// Individual smoke-test steps. Each takes plain inputs and returns plain data so smoke.mjs only orchestrates.
import { createHash } from 'node:crypto';

export async function probeWebGL2(context) {
  const page = await context.newPage();
  try {
    return await page.evaluate(() => {
      const c = document.createElement('canvas');
      const g = c.getContext('webgl2');
      if (!g) return null;
      const ext = g.getExtension('WEBGL_debug_renderer_info');
      return { version: g.getParameter(g.VERSION), renderer: ext ? g.getParameter(ext.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER) };
    });
  } finally {
    await page.close();
  }
}

/** GET build-info.json with cache busting; retries with backoff until the expected SHA is live (Pages propagation). */
export async function fetchBuildInfo(baseUrl, { expectedSha, timeoutMs }) {
  const attempts = [];
  const deadline = Date.now() + timeoutMs;
  let delay = 5000;
  let buildInfo = null;
  for (;;) {
    const url = new URL(`build-info.json?cb=${Date.now()}`, baseUrl).href;
    let status = 0;
    let sha = null;
    try {
      const res = await fetch(url, { cache: 'no-store' });
      status = res.status;
      if (res.ok) {
        buildInfo = await res.json();
        sha = buildInfo.commit_sha ?? null;
      }
    } catch {
      status = -1;
    }
    attempts.push({ at: new Date().toISOString(), status, sha });
    if (status === 200 && (!expectedSha || sha === expectedSha)) break;
    if (Date.now() >= deadline) break;
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(Math.round(delay * 1.5), 30000);
  }
  return { buildInfo, attempts };
}

/** The bytes being served must be the bytes that were built (sha256 per file listed in build-info.json). */
export async function verifyServedFiles(baseUrl, files) {
  const mismatches = [];
  for (const [name, meta] of Object.entries(files)) {
    let status = -1;
    let digest = null;
    try {
      const res = await fetch(new URL(`${name}?cb=${Date.now()}`, baseUrl).href, { cache: 'no-store' });
      status = res.status;
      if (res.ok) {
        const hash = createHash('sha256');
        for await (const chunk of res.body) hash.update(chunk);
        digest = hash.digest('hex');
      }
    } catch { /* leave digest null */ }
    if (digest !== meta.sha256) mismatches.push(`${name} (HTTP ${status})`);
  }
  return mismatches;
}

/**
 * Godot's default shell REMOVES #status on success and shows #status-notice on failure.
 * @returns {Promise<'started'|'timeout'|string>} 'notice:<text>' when the shell reported an error
 */
export async function waitForEngineStart(page, timeoutMs) {
  try {
    const handle = await page.waitForFunction(() => {
      const status = document.getElementById('status');
      if (!status) return 'started';
      const notice = document.getElementById('status-notice');
      if (notice && getComputedStyle(notice).display !== 'none' && notice.innerText.trim()) {
        return 'notice:' + notice.innerText.trim().replace(/\s*\n\s*/g, ' / ');
      }
      return false;
    }, null, { timeout: timeoutMs, polling: 250 });
    return await handle.jsonValue();
  } catch {
    return 'timeout';
  }
}

export async function inspectCanvas(canvas) {
  let box = null;
  try {
    await canvas.waitFor({ state: 'visible', timeout: 5000 });
    box = await canvas.boundingBox();
  } catch { /* reported by caller */ }
  const buffer = await canvas.evaluate((c) => ({ w: c.width, h: c.height })).catch(() => null);
  const ok = Boolean(box && box.width > 0 && box.height > 0 && buffer && buffer.w > 0 && buffer.h > 0);
  return { ok, box, buffer };
}

/** Optional readiness hook: window.__SHINOBI_READY__ === true. Returns 'ready' | 'absent' | 'not-ready'. */
export async function readReadyHook(page, graceMs = 5000) {
  try {
    await page.waitForFunction(() => window.__SHINOBI_READY__ === true, null, { timeout: graceMs });
    return 'ready';
  } catch {
    return (await page.evaluate(() => typeof window.__SHINOBI_READY__)) === 'undefined' ? 'absent' : 'not-ready';
  }
}

/**
 * The check record for a readiness-hook state. The first real game will define the hook, so every branch is pinned:
 * ready = pass; absent = skip, or fail when the hook is required (--require-ready-hook); defined but never true = fail.
 * @param {'ready'|'absent'|'not-ready'} state
 * @param {boolean} required
 * @returns {{status: 'pass'|'skip'|'fail', detail: string}}
 */
export function readyHookVerdict(state, required) {
  if (state === 'ready') return { status: 'pass', detail: 'window.__SHINOBI_READY__ === true' };
  if (state === 'absent') {
    return required
      ? { status: 'fail', detail: 'window.__SHINOBI_READY__ is not defined but the hook is required (--require-ready-hook)' }
      : { status: 'skip', detail: 'window.__SHINOBI_READY__ is not defined (optional hook)' };
  }
  return { status: 'fail', detail: 'window.__SHINOBI_READY__ is defined but never became true' };
}

/** Press each "Key[:holdMs]" step on the focused canvas. */
export async function pressSequence(page, steps) {
  await page.evaluate(() => document.querySelector('canvas')?.focus());
  for (const step of steps) {
    const [key, hold = '100'] = step.split(':');
    await page.keyboard.down(key);
    await page.waitForTimeout(Number(hold));
    await page.keyboard.up(key);
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(500);
}
