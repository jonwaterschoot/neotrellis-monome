/**
 * serve.js – Monome Grid Emulator Dev Server
 *
 * Features:
 *   - Serves all static files from this directory
 *   - Watches the scripts/ folder for .lua file changes
 *   - Pushes WebSocket events to connected browsers on file change
 *   - Auto-detects a free port (default 3141)
 *
 * Usage:
 *   node serve.js           → serves on http://localhost:3141
 *   node serve.js 8080      → custom port
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = parseInt(process.argv[2] || '3141', 10);
const ROOT = __dirname;
const SCRIPTS_DIR = path.join(ROOT, 'scripts');

// ─── MIME TYPES ──────────────────────────────────────────────────────────────
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.lua':  'text/plain; charset=utf-8',
  '.md':   'text/markdown; charset=utf-8',
  '.ico':  'image/x-icon',
  '.png':  'image/png',
  '.svg':  'image/svg+xml',
  '.wasm': 'application/wasm',
};

// ─── HTTP SERVER ─────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  let urlPath = req.url.split('?')[0]; // Strip query string

  // Default to emulator.html for root
  if (urlPath === '/' || urlPath === '') urlPath = '/emulator.html';

  const filePath = path.join(ROOT, urlPath.replace(/\//g, path.sep));

  // Security: prevent path traversal outside ROOT
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403); res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end(`Not found: ${urlPath}`);
      } else {
        res.writeHead(500); res.end('Server error');
      }
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(data);
  });
});

// ─── WEBSOCKET SERVER ────────────────────────────────────────────────────────
const wss = new WebSocketServer({ server, path: '/ws' });
const clients = new Set();

wss.on('connection', (ws) => {
  clients.add(ws);
  ws.send(JSON.stringify({ type: 'connected', message: 'Hot-reload active' }));
  ws.on('close', () => clients.delete(ws));
  ws.on('error', () => clients.delete(ws));
});

function broadcast(msg) {
  const raw = JSON.stringify(msg);
  for (const ws of clients) {
    if (ws.readyState === 1) ws.send(raw);  // 1 = OPEN
  }
}

// ─── FILE WATCHER ─────────────────────────────────────────────────────────────
const DEBOUNCE_MS = 150;
const pending = new Map();  // filename → timer

function watchScripts() {
  if (!fs.existsSync(SCRIPTS_DIR)) {
    console.log(`  scripts/ directory not found — file watching disabled`);
    return;
  }

  fs.watch(SCRIPTS_DIR, { persistent: true }, (eventType, filename) => {
    if (!filename || !filename.endsWith('.lua')) return;
    // Debounce rapid saves (editors write multiple times on save)
    clearTimeout(pending.get(filename));
    pending.set(filename, setTimeout(() => {
      pending.delete(filename);
      console.log(`  ↻ Changed: scripts/${filename}`);
      broadcast({ type: 'file_changed', name: filename });
    }, DEBOUNCE_MS));
  });

  console.log(`  Watching: scripts/*.lua`);
}

// ─── START ───────────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log('');
  console.log('  ┌─────────────────────────────────────────────┐');
  console.log('  │  Monome Grid Emulator — Dev Server          │');
  console.log('  ├─────────────────────────────────────────────┤');
  console.log(`  │  http://localhost:${PORT}/                     │`);
  console.log(`  │  ws://localhost:${PORT}/ws  (hot-reload)       │`);
  console.log('  └─────────────────────────────────────────────┘');
  console.log('');
  watchScripts();
  console.log('  Ready. Edit any .lua in scripts/ to hot-reload.\n');
});
