const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');

const PORT = Number(process.env.PORT || 8080);
const WEB_DIR = path.resolve(__dirname, '..', 'web');
const rooms = new Map();

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function localAddresses() {
  const nets = os.networkInterfaces();
  const list = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) list.push(net.address);
    }
  }
  return list;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let filePath = path.join(WEB_DIR, url.pathname === '/' ? 'index.html' : url.pathname);
  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    const type = ext === '.html' ? 'text/html; charset=utf-8' : 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type });
    res.end(data);
  });
});

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  ws.roomCode = null;
  ws.role = 'unknown';

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_) {
      send(ws, { type: 'error', message: 'Mensagem inválida.' });
      return;
    }

    if (message.type === 'join') {
      const roomCode = String(message.roomCode || '').trim();
      const role = String(message.role || 'unknown').trim();
      if (!roomCode) {
        send(ws, { type: 'error', message: 'Código da sala ausente.' });
        return;
      }

      if (!rooms.has(roomCode)) rooms.set(roomCode, new Set());
      ws.roomCode = roomCode;
      ws.role = role;
      rooms.get(roomCode).add(ws);

      send(ws, { type: 'joined', roomCode, role });
      for (const client of rooms.get(roomCode)) {
        if (client !== ws) send(client, { type: 'peer_joined', role });
      }
      return;
    }

    if (message.type === 'signal') {
      const room = rooms.get(ws.roomCode);
      if (!room) {
        send(ws, { type: 'error', message: 'Sala não encontrada.' });
        return;
      }
      for (const client of room) {
        if (client !== ws) send(client, { type: 'signal', from: ws.role, payload: message.payload });
      }
      return;
    }

    send(ws, { type: 'error', message: 'Tipo de mensagem desconhecido.' });
  });

  ws.on('close', () => {
    const room = rooms.get(ws.roomCode);
    if (!room) return;
    room.delete(ws);
    for (const client of room) send(client, { type: 'peer_left', role: ws.role });
    if (room.size === 0) rooms.delete(ws.roomCode);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('SW Air Link local server running.');
  console.log('Abra no navegador:');
  for (const address of localAddresses()) console.log(`  http://${address}:${PORT}`);
  console.log('No app use:');
  for (const address of localAddresses()) console.log(`  ws://${address}:${PORT}`);
});
