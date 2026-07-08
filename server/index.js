const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });
const rooms = new Map();

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function broadcast(roomCode, sender, data) {
  const room = rooms.get(roomCode);
  if (!room) return;

  for (const client of room) {
    if (client !== sender) send(client, data);
  }
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
      broadcast(roomCode, ws, { type: 'peer_joined', role });
      return;
    }

    if (message.type === 'signal') {
      if (!ws.roomCode) {
        send(ws, { type: 'error', message: 'Cliente ainda não entrou em uma sala.' });
        return;
      }

      broadcast(ws.roomCode, ws, {
        type: 'signal',
        from: ws.role,
        payload: message.payload || null
      });
      return;
    }

    send(ws, { type: 'error', message: 'Tipo de mensagem desconhecido.' });
  });

  ws.on('close', () => {
    if (!ws.roomCode) return;

    const room = rooms.get(ws.roomCode);
    if (!room) return;

    room.delete(ws);
    broadcast(ws.roomCode, ws, { type: 'peer_left', role: ws.role });

    if (room.size === 0) rooms.delete(ws.roomCode);
  });
});

console.log(`SW Air Link server running on port ${PORT}`);
