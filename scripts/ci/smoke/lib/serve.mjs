// Minimal static file server for smoke tests. Intentionally mirrors GitHub Pages:
// no COOP/COEP headers (so a threaded export fails here exactly as it would on Pages),
// correct application/wasm MIME type, GET/HEAD only, no directory listing.
import http from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.css': 'text/css; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.ogg': 'audio/ogg',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
};

export function startStaticServer(rootDir, { host = '127.0.0.1', port = 0 } = {}) {
  const root = path.resolve(rootDir);
  const requests = [];
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    let rel;
    try {
      rel = decodeURIComponent(url.pathname);
    } catch {
      res.writeHead(400);
      return res.end();
    }
    if (rel.endsWith('/')) rel += 'index.html';
    const file = path.resolve(root, '.' + rel);
    const record = { method: req.method, path: url.pathname, status: 0 };
    requests.push(record);
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      record.status = 405;
      res.writeHead(405, { Allow: 'GET, HEAD' });
      return res.end();
    }
    if (file !== root && !file.startsWith(root + path.sep)) {
      record.status = 403;
      res.writeHead(403);
      return res.end();
    }
    let st;
    try {
      st = statSync(file);
    } catch {
      record.status = 404;
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('not found');
    }
    if (!st.isFile()) {
      record.status = 404;
      res.writeHead(404);
      return res.end();
    }
    record.status = 200;
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': st.size,
      'Cache-Control': 'no-store',
    });
    if (req.method === 'HEAD') return res.end();
    createReadStream(file).pipe(res);
  });
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, () => {
      const addr = server.address();
      resolve({
        url: `http://${host}:${addr.port}/`,
        requests,
        close: () => new Promise((r) => server.close(r)),
      });
    });
  });
}

// CLI for manual play-testing of an export:  node scripts/ci/smoke/lib/serve.mjs <export dir> [port]
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const [dir, port = '8080'] = process.argv.slice(2);
  if (!dir) {
    console.error('usage: node serve.mjs <export dir> [port]');
    process.exit(2);
  }
  const srv = await startStaticServer(dir, { port: Number(port) });
  console.log(`Serving ${path.resolve(dir)} at ${srv.url} (Ctrl+C to stop; no COOP/COEP headers, like GitHub Pages)`);
}
