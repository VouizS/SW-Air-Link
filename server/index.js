const WebSocket = require('ws');

const PORT = Number(process.env.PORT || 8080);
const wss = new WebSocket.Server({ port: PORT });
const rooms = new Map();

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function getRoom(code) {
  if (!rooms.has(code)) rooms.set(code, new Set());
  return rooms.get(code);
}

wss.on('connection', (ws) => {
  ws.roomCode = null;
  ws.role = 'unknown';

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      send(ws, { type: 'error', message: 'Mensagem inválida.' });
      return;
    }

    if (msg.type === 'join') {
      const roomCode = String(msg.roomCode || '').trim();
      const role = String(msg.role || 'unknown').trim();

      if (!roomCode) {
        send(ws, { type: 'error', message: 'Código da sala ausente.' });
        return;
      }

      ws.roomCode = roomCode;
      ws.role = role;
      const room = getRoom(roomCode);
      room.add(ws);

      send(ws, { type: 'joined', roomCode, role, peers: room.size - 1 });

      for (const client of room) {
        if (client !== ws) send(client, { type: 'peer_joined', role });
      }
      return;
    }

    if (msg.type === 'signal') {
      const room = rooms.get(ws.roomCode);
      if (!room) {
        send(ws, { type: 'error', message: 'Sala não encontrada.' });
        return;
      }

      for (const client of room) {
        if (client !== ws) {
          send(client, { type: 'signal', from: ws.role, payload: msg.payload || null });
        }
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

console.log(`SW Air Link server running on port ${PORT}`);
