const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');

const PORT = Number(process.env.PORT || 8080);
const webDir = path.resolve(__dirname, '..', 'web');
const rooms = new Map();

function json(res, status, payload) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(payload, null, 2));
}

function serveFile(req, res) {
  if (req.url === '/health') {
    json(res, 200, {
      ok: true,
      app: 'SW Air Link',
      version: 'v0.2-r2',
      rooms: rooms.size,
    });
    return;
  }

  let requested = decodeURIComponent((req.url || '/').split('?')[0]);
  if (requested === '/') requested = '/index.html';

  const filePath = path.resolve(webDir, `.${requested}`);
  if (!filePath.startsWith(webDir)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Arquivo não encontrado');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const type = ext === '.html'
      ? 'text/html; charset=utf-8'
      : ext === '.css'
        ? 'text/css; charset=utf-8'
        : ext === '.js'
          ? 'application/javascript; charset=utf-8'
          : 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
    res.end(data);
  });
}

const server = http.createServer(serveFile);
const wss = new WebSocket.Server({ server });

function send(ws, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function broadcast(roomCode, payload, except = null) {
  const room = rooms.get(roomCode);
  if (!room) return;
  for (const client of room.clients) {
    if (client !== except) send(client, payload);
  }
}

function makeCode() {
  for (let i = 0; i < 30; i += 1) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    if (!rooms.has(code)) return code;
  }
  return String(Date.now()).slice(-6);
}

function roomSummary(roomCode) {
  const room = rooms.get(roomCode);
  if (!room) return null;
  return {
    roomCode,
    clients: room.clients.size,
    hasWeb: Boolean(room.web),
    hasMobile: Boolean(room.mobile),
    createdAt: room.createdAt,
  };
}

wss.on('connection', (ws, req) => {
  ws.role = 'unknown';
  ws.roomCode = null;

  send(ws, {
    type: 'hello',
    app: 'SW Air Link',
    version: 'v0.2-r2',
    message: 'Servidor de pareamento conectado.',
  });

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (error) {
      send(ws, { type: 'error', code: 'invalid_json', message: 'Mensagem inválida.' });
      return;
    }

    if (message.type === 'create_room') {
      const roomCode = makeCode();
      const room = {
        createdAt: new Date().toISOString(),
        clients: new Set([ws]),
        web: ws,
        mobile: null,
      };
      rooms.set(roomCode, room);
      ws.role = String(message.role || 'web');
      ws.roomCode = roomCode;
      send(ws, {
        type: 'room_created',
        roomCode,
        summary: roomSummary(roomCode),
      });
      return;
    }

    if (message.type === 'join_room') {
      const roomCode = String(message.roomCode || '').trim();
      if (!roomCode || !rooms.has(roomCode)) {
        send(ws, {
          type: 'error',
          code: 'room_not_found',
          message: 'Código não encontrado ou expirado.',
        });
        return;
      }

      const room = rooms.get(roomCode);
      room.clients.add(ws);
      ws.role = String(message.role || 'mobile');
      ws.roomCode = roomCode;

      if (ws.role === 'mobile') room.mobile = ws;
      if (ws.role === 'web') room.web = ws;

      send(ws, {
        type: 'joined',
        roomCode,
        role: ws.role,
        summary: roomSummary(roomCode),
      });

      broadcast(roomCode, {
        type: 'peer_joined',
        role: ws.role,
        deviceName: message.deviceName || 'Dispositivo',
        summary: roomSummary(roomCode),
      }, ws);
      return;
    }

    if (message.type === 'signal') {
      if (!ws.roomCode) {
        send(ws, { type: 'error', code: 'not_in_room', message: 'Entre em uma sala primeiro.' });
        return;
      }
      broadcast(ws.roomCode, {
        type: 'signal',
        from: ws.role,
        payload: message.payload || null,
      }, ws);
      return;
    }

    if (message.type === 'ping') {
      send(ws, { type: 'pong', now: new Date().toISOString() });
      return;
    }

    send(ws, { type: 'error', code: 'unknown_type', message: 'Tipo de mensagem desconhecido.' });
  });

  ws.on('close', () => {
    const roomCode = ws.roomCode;
    if (!roomCode || !rooms.has(roomCode)) return;

    const room = rooms.get(roomCode);
    room.clients.delete(ws);
    if (room.web === ws) room.web = null;
    if (room.mobile === ws) room.mobile = null;

    broadcast(roomCode, {
      type: 'peer_left',
      role: ws.role,
      summary: roomSummary(roomCode),
    });

    if (room.clients.size === 0) {
      rooms.delete(roomCode);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('SW Air Link server v0.2-r2');
  console.log(`HTTP/WebSocket port: ${PORT}`);
  console.log('Abra o endereço do seu IP local no navegador.');
});
