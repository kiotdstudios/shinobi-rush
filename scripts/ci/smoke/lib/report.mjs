// Evidence helpers: sanitising untrusted text and rendering the Markdown summary. Pure functions.

/** Untrusted text (browser console, page content) must never inject workflow commands (::error::, ::stop-commands::). */
export function sanitize(text, max = 300) {
  return String(text)
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '')
    .replace(/\r/g, '')
    .replace(/(^|\n)(\s*)::/g, '$1$2:\u200b:')
    .slice(0, max);
}

export function mdCell(text) {
  return sanitize(text).replace(/\|/g, '\\|').replace(/\n/g, ' ').replace(/`/g, "'");
}

/**
 * @param {{label: string, mode: string, baseUrl: string, verdict: string, durationMs: number,
 *          checks: {name: string, status: string, detail: string}[],
 *          events: {level: string, rule: string, text: string}[]}} r
 */
export function summaryMarkdown(r) {
  const lines = [];
  lines.push(`## Browser smoke test: ${mdCell(r.label)} (${r.mode})`);
  lines.push('');
  lines.push(`**Verdict: ${r.verdict}** | target \`${mdCell(r.baseUrl ?? '')}\` | ${(r.durationMs / 1000).toFixed(1)} s`);
  lines.push('');
  lines.push('| Check | Result | Detail |');
  lines.push('| --- | --- | --- |');
  for (const c of r.checks) lines.push(`| ${c.name} | ${c.status.toUpperCase()} | ${mdCell(c.detail)} |`);
  const fatal = r.events.filter((e) => e.level === 'fatal');
  const warns = r.events.filter((e) => e.level === 'warn');
  lines.push('');
  lines.push(`Console/network events: ${r.events.length}, warnings: ${warns.length}, fatal: ${fatal.length}.`);
  if (fatal.length) {
    lines.push('');
    lines.push('First fatal events:');
    for (const e of fatal.slice(0, 10)) lines.push(`- \`[${mdCell(e.rule)}]\` ${mdCell(e.text)}`);
  }
  return lines.join('\n') + '\n';
}
