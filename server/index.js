const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });
const rooms = new Map();

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function safeRoomCode(value) {
  return String(value || '').replace(/[^0-9A-Za-z_-]/g, '').slice(0, 32);
}

wss.on('connection', (ws) => {
  ws.roomCode = null;
  ws.role = 'unknown';

  ws.on('message', (raw) => {
    let message;

    try {
      message = JSON.parse(raw.toString());
    } catch {
      send(ws, { type: 'error', message: 'Mensagem inválida.' });
      return;
    }

    if (message.type === 'join') {
      const roomCode = safeRoomCode(message.roomCode);
      const role = String(message.role || 'unknown').slice(0, 32);

      if (!roomCode) {
        send(ws, { type: 'error', message: 'Código da sala ausente.' });
        return;
      }

      if (!rooms.has(roomCode)) {
        rooms.set(roomCode, new Set());
      }

      ws.roomCode = roomCode;
      ws.role = role;
      rooms.get(roomCode).add(ws);

      send(ws, { type: 'joined', roomCode, role });

      for (const client of rooms.get(roomCode)) {
        if (client !== ws) {
          send(client, { type: 'peer_joined', role });
        }
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
        if (client !== ws) {
          send(client, {
            type: 'signal',
            from: ws.role,
            payload: message.payload,
          });
        }
      }

      return;
    }

    send(ws, { type: 'error', message: 'Tipo de mensagem desconhecido.' });
  });

  ws.on('close', () => {
    const room = rooms.get(ws.roomCode);

    if (!room) {
      return;
    }

    room.delete(ws);

    for (const client of room) {
      send(client, { type: 'peer_left', role: ws.role });
    }

    if (room.size === 0) {
      rooms.delete(ws.roomCode);
    }
  });
});

console.log(`SW Air Link server running on port ${PORT}`);
