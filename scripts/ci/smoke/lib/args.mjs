// Argument + config parsing for smoke.mjs. Pure (no process.exit) so it can be unit tested.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';

export const DEFAULTS = {
  canvas_selector: 'canvas',
  settle_ms: 3000,
  input_sequence: [],
  require_input_effect: false,
  require_ready_hook: false,
  startup_timeout_ms: 90000,
};

export class UsageError extends Error {}

/**
 * @param {string[]} argv process.argv.slice(2)
 * @param {{here: string, env?: Record<string,string|undefined>}} ctx here = directory of smoke.mjs
 */
export function parseCli(argv, { here, env = {} }) {
  const { values: cli } = parseArgs({
    args: argv,
    options: {
      'serve-dir': { type: 'string' },
      'base-url': { type: 'string' },
      'expected-sha': { type: 'string' },
      'expected-kind': { type: 'string', default: 'game' },
      'out-dir': { type: 'string' },
      label: { type: 'string', default: 'smoke' },
      config: { type: 'string', default: path.join(here, 'smoke-config.json') },
      allowlist: { type: 'string', default: path.join(here, 'console-allowlist.json') },
      'startup-timeout-ms': { type: 'string' },
      'settle-ms': { type: 'string' },
      'canvas-selector': { type: 'string' },
      'input-sequence': { type: 'string' },
      'require-input-effect': { type: 'boolean' },
      'require-ready-hook': { type: 'boolean' },
      'propagation-timeout-ms': { type: 'string', default: '300000' },
      'global-timeout-ms': { type: 'string', default: '900000' },
      'skip-file-verification': { type: 'boolean', default: false },
      'summary-file': { type: 'string', default: env.GITHUB_STEP_SUMMARY ?? '' },
    },
  });
  if (!cli['out-dir']) throw new UsageError('--out-dir is required');
  if (Boolean(cli['serve-dir']) === Boolean(cli['base-url'])) throw new UsageError('exactly one of --serve-dir or --base-url is required');
  const mode = cli['serve-dir'] ? 'local' : 'deployed';
  const sha = cli['expected-sha'];
  if (sha !== undefined && !/^[0-9a-f]{40}$/.test(sha)) throw new UsageError('--expected-sha must be 40 lowercase hex characters');
  if (mode === 'deployed' && !sha) throw new UsageError('--expected-sha is required with --base-url');
  if (mode === 'deployed' && !/^https:\/\//.test(cli['base-url'])) throw new UsageError('--base-url must be https:// for a deployed target');

  const fileConfig = existsSync(cli.config) ? JSON.parse(readFileSync(cli.config, 'utf8')) : {};
  const cfg = { ...DEFAULTS, ...fileConfig };
  if (cli['canvas-selector'] !== undefined) cfg.canvas_selector = cli['canvas-selector'];
  if (cli['settle-ms'] !== undefined) cfg.settle_ms = Number(cli['settle-ms']);
  if (cli['startup-timeout-ms'] !== undefined) cfg.startup_timeout_ms = Number(cli['startup-timeout-ms']);
  if (cli['input-sequence'] !== undefined) cfg.input_sequence = cli['input-sequence'].split(',').map((s) => s.trim()).filter(Boolean);
  if (cli['require-input-effect'] !== undefined) cfg.require_input_effect = cli['require-input-effect'];
  if (cli['require-ready-hook'] !== undefined) cfg.require_ready_hook = cli['require-ready-hook'];
  for (const key of ['settle_ms', 'startup_timeout_ms']) {
    if (!Number.isFinite(cfg[key]) || cfg[key] < 0) throw new UsageError(`${key} must be a non-negative number`);
  }
  for (const step of cfg.input_sequence) {
    if (!/^[A-Za-z0-9+]+(:\d{1,5})?$/.test(step)) throw new UsageError(`invalid input step ${JSON.stringify(step)} (expected Key[:holdMs], e.g. KeyD:500)`);
  }
  const allowlist = existsSync(cli.allowlist) ? JSON.parse(readFileSync(cli.allowlist, 'utf8')) : { console: [], requests: [] };
  return { cli, cfg, allowlist, mode, outDir: path.resolve(cli['out-dir']) };
}
