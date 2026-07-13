const http = require('http');
const os = require('os');
const WebSocket = require('ws');

const PORT = Number(process.env.PORT || 8080);
const rooms = new Map();

function getLocalIp() {
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) return net.address;
    }
  }
  return '127.0.0.1';
}

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}

function roomMembers(code) {
  if (!rooms.has(code)) rooms.set(code, new Set());
  return rooms.get(code);
}

function removeFromRoom(ws) {
  if (!ws.roomCode) return;
  const room = rooms.get(ws.roomCode);
  if (!room) return;
  room.delete(ws);
  for (const client of room) send(client, { type: 'peer_left', role: ws.role || 'unknown' });
  if (room.size === 0) rooms.delete(ws.roomCode);
}

function htmlPage() {
  const ip = getLocalIp();
  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>SW Air Link</title>
<style>
body{margin:0;background:#05060a;color:#f7f8ff;font-family:system-ui,Arial,sans-serif}
.wrap{width:min(920px,92vw);margin:24px auto}
.card{background:#0b0d14;border:1px solid #202432;border-radius:26px;padding:28px;margin-bottom:24px}
h1{font-size:42px;margin:0 0 18px} h2{font-size:28px;margin:0 0 4px}
p{color:#aeb6c7;font-size:18px;line-height:1.45}
.code{background:#000;border:1px solid #1e2432;border-radius:22px;padding:28px;text-align:center;font-size:48px;letter-spacing:16px;font-weight:900;margin:28px 0}
button{width:100%;border:0;border-radius:18px;padding:18px;font-size:18px;font-weight:900;background:#5670b2;color:white}
.status,.hint{background:#101726;border:1px solid #202a3c;border-radius:18px;padding:18px;color:#b8c1d4;margin-top:18px}
.mirror{position:relative;background:#000;border:1px solid #262c3a;border-radius:22px;min-height:430px;overflow:hidden;display:flex;align-items:center;justify-content:center}
.badge{position:absolute;left:22px;top:22px;border:1px solid #2a3142;border-radius:999px;padding:10px 16px;color:#b8c1d4;background:#06080d}
.counter{float:right;color:#aeb6c7}.empty{text-align:center;padding:48px;color:#b8c1d4}.empty strong{display:block;font-size:30px;color:#d5dbea;margin-bottom:18px}
#screen{max-width:100%;max-height:78vh;display:none}
.small{font-size:14px;color:#8f98aa}
</style>
</head>
<body>
<div class="wrap">
<section class="card">
<h1>SW Air Link</h1>
<p>Abra o app no celular, informe o servidor WebSocket e digite o código abaixo.</p>
<div class="code" id="code">000000</div>
<button id="newCode">Gerar novo código</button>
<div class="status" id="status">Aguardando telefone...</div>
<div class="hint">No app use: ws://${ip}:${PORT}</div>
</section>
<section class="card">
<h2>Tela do telefone <span class="counter" id="counter">0 frames</span></h2>
<p class="small">v0.3-r9 • frames reais experimentais</p>
<div class="mirror">
<div class="badge" id="badge">Aguardando telefone</div>
<img id="screen"/>
<div class="empty" id="empty"><strong>Nenhuma tela recebida ainda</strong>Conecte o app, toque em “Iniciar espelhamento experimental” e aceite a permissão do Android.</div>
</div>
</section>
</div>
<script>
let socket=null,frames=0,code="";
function generateCode(){code=String(Math.floor(100000+Math.random()*900000));document.getElementById("code").textContent=code.split("").join(" ");connect();}
function setStatus(t){document.getElementById("status").textContent=t}
function setBadge(t){document.getElementById("badge").textContent=t}
function connect(){
 if(socket){try{socket.close()}catch(e){}}
 frames=0;document.getElementById("counter").textContent="0 frames";
 const proto=location.protocol==="https:"?"wss:":"ws:";
 socket=new WebSocket(proto+"//"+location.host);
 socket.onopen=()=>{socket.send(JSON.stringify({type:"join",role:"web",roomCode:code}));setStatus("Navegador pronto. Digite o código no app.");setBadge("Aguardando telefone")};
 socket.onmessage=(event)=>{
  let msg={};try{msg=JSON.parse(event.data)}catch(e){return}
  if(msg.type==="peer_joined"&&msg.role==="phone"){setStatus("Telefone conectado. Agora inicie o espelhamento no app.");setBadge("Telefone conectado")}
  if(msg.type==="peer_left"){setStatus("Conexão encerrada.");setBadge("Telefone saiu")}
  if(msg.type==="frame"&&msg.frame){frames++;const img=document.getElementById("screen");img.src="data:image/jpeg;base64,"+msg.frame;img.style.display="block";document.getElementById("empty").style.display="none";document.getElementById("counter").textContent=frames+" frames";setBadge("Recebendo tela")}
 };
 socket.onclose=()=>setStatus("Conexão encerrada.");
 socket.onerror=()=>setStatus("Erro no WebSocket.");
}
document.getElementById("newCode").onclick=generateCode;generateCode();
</script>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(htmlPage());
    return;
  }
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('SW Air Link: rota não encontrada.');
});

const wss = new WebSocket.Server({ server });
wss.on('connection', (ws) => {
  ws.roomCode = null;
  ws.role = null;

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { send(ws, { type: 'error', message: 'Mensagem inválida.' }); return; }

    if (msg.type === 'join') {
      const roomCode = String(msg.roomCode || '').trim();
      const role = String(msg.role || 'unknown').trim();
      if (!roomCode) { send(ws, { type: 'error', message: 'Código ausente.' }); return; }
      removeFromRoom(ws);
      ws.roomCode = roomCode;
      ws.role = role;
      const room = roomMembers(roomCode);
      room.add(ws);
      send(ws, { type: 'joined', roomCode, role });
      for (const client of room) if (client !== ws) send(client, { type: 'peer_joined', role });
      return;
    }

    if (msg.type === 'frame') {
      const room = rooms.get(ws.roomCode || msg.roomCode);
      if (!room) return;
      for (const client of room) if (client !== ws && client.role === 'web') send(client, { type: 'frame', frame: msg.frame });
    }
  });

  ws.on('close', () => removeFromRoom(ws));
});

server.listen(PORT, '0.0.0.0', () => {
  const ip = getLocalIp();
  console.log('SW Air Link local server running.');
  console.log(`Abra no navegador: http://${ip}:${PORT}`);
  console.log(`No app use:       ws://${ip}:${PORT}`);
});
