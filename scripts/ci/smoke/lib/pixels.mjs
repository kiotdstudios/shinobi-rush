// Pixel statistics are computed inside a throwaway about:blank page (no PNG decoder dependency).
// The function passed to page.evaluate must be self-contained.

export const BLANK_DOMINANT_RATIO = 0.999; // >= 99.9% of sampled pixels share one (4-bit quantised) colour
export const SAMPLE_W = 320;
export const SAMPLE_H = 180;
export const DIFF_PIXEL_THRESHOLD = 48; // summed |dR|+|dG|+|dB| to count a pixel as changed
export const MIN_CHANGED_RATIO = 0.001; // >= 0.1% changed pixels counts as a visible effect

/** Runs in the browser. Returns colour statistics and (optionally) the change ratio vs a previous PNG. */
export async function analyzeInPage({ pngBase64, prevPngBase64, w, h, diffThreshold }) {
  const load = async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const ctx = c.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, 0, 0, w, h);
    return { data: ctx.getImageData(0, 0, w, h).data, naturalWidth: img.naturalWidth, naturalHeight: img.naturalHeight };
  };
  const cur = await load(pngBase64);
  const counts = new Map();
  let transparent = 0;
  for (let i = 0; i < cur.data.length; i += 4) {
    if (cur.data[i + 3] === 0) transparent++;
    const key = ((cur.data[i] >> 4) << 8) | ((cur.data[i + 1] >> 4) << 4) | (cur.data[i + 2] >> 4);
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  let domKey = 0;
  let domCount = 0;
  for (const [k, n] of counts) if (n > domCount) { domCount = n; domKey = k; }
  const total = w * h;
  const hex = (v) => (v << 4 | v).toString(16).padStart(2, '0');
  const result = {
    sample: `${w}x${h}`,
    sourceSize: `${cur.naturalWidth}x${cur.naturalHeight}`,
    distinctColors: counts.size,
    dominantRatio: domCount / total,
    dominantColor: '#' + hex((domKey >> 8) & 15) + hex((domKey >> 4) & 15) + hex(domKey & 15),
    transparentRatio: transparent / total,
    changedRatio: null,
  };
  if (prevPngBase64) {
    const prev = await load(prevPngBase64);
    let changed = 0;
    for (let i = 0; i < cur.data.length; i += 4) {
      const d = Math.abs(cur.data[i] - prev.data[i]) + Math.abs(cur.data[i + 1] - prev.data[i + 1]) + Math.abs(cur.data[i + 2] - prev.data[i + 2]);
      if (d > diffThreshold) changed++;
    }
    result.changedRatio = changed / total;
  }
  return result;
}

export function isBlank(stats) {
  return stats.distinctColors <= 1 || stats.dominantRatio >= BLANK_DOMINANT_RATIO || stats.transparentRatio >= BLANK_DOMINANT_RATIO;
}
