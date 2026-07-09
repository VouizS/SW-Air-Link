import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SW Air Link',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF516AA8)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const PairingPage(),
    );
  }
}

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _serverController = TextEditingController(text: 'ws://127.0.0.1:8080');
  final TextEditingController _codeController = TextEditingController();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String _status = 'Digite o código gerado no navegador.';
  bool _connected = false;

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _serverController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _setStatus(String text) {
    if (!mounted) return;
    setState(() => _status = text);
  }

  Future<void> _connect() async {
    final serverUrl = _serverController.text.trim();
    final code = _codeController.text.trim();

    if (serverUrl.isEmpty) {
      _setStatus('Informe o endereço do servidor WebSocket.');
      return;
    }

    if (code.length < 4) {
      _setStatus('Digite o código que aparece no navegador.');
      return;
    }

    final uri = Uri.tryParse(serverUrl);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      _setStatus('Endereço inválido. Use ws://IP:8080 ou wss://domínio.');
      return;
    }

    await _disconnect(silent: true);
    _setStatus('Conectando ao servidor...');

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _connected = true;

      _subscription = channel.stream.listen(
        (event) {
          final text = event.toString();
          Map<String, dynamic> data;
          try {
            data = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            _setStatus('Mensagem recebida, mas não entendi o formato.');
            return;
          }

          final type = data['type']?.toString() ?? '';
          if (type == 'hello') {
            _setStatus(data['message']?.toString() ?? 'Servidor conectado.');
            channel.sink.add(jsonEncode({
              'type': 'join_room',
              'role': 'mobile',
              'roomCode': code,
              'deviceName': 'Android Flutter',
            }));
            return;
          }

          if (type == 'joined') {
            _setStatus('Conectado à sala $code. Confira o navegador.');
            return;
          }

          if (type == 'peer_joined') {
            _setStatus('Outro dispositivo entrou na sala.');
            return;
          }

          if (type == 'peer_left') {
            _setStatus('O navegador saiu da sala.');
            return;
          }

          if (type == 'error') {
            _setStatus(data['message']?.toString() ?? 'Erro ao parear.');
            return;
          }
        },
        onError: (_) {
          _connected = false;
          _setStatus('Falha na conexão. Confira IP, Wi-Fi e servidor.');
        },
        onDone: () {
          _connected = false;
          _setStatus('Conexão encerrada.');
        },
      );
    } catch (_) {
      _connected = false;
      _setStatus('Não consegui abrir o WebSocket.');
    }
  }

  Future<void> _disconnect({bool silent = false}) async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    if (!silent) _setStatus('Desconectado.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFE),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE3E6EF)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A000000),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cast_connected_rounded,
                      size: 58,
                      color: Color(0xFF3467D6),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SW Air Link',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF151922),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'App simples para conectar o telefone ao navegador. A tela principal ficará no site.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF687184),
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.dns_rounded),
                        labelText: 'Servidor WebSocket',
                        hintText: 'ws://IP:8080',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.pin_rounded),
                        labelText: 'Código do navegador',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _connect,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text(
                          'Preparar conexão',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _connected ? () => _disconnect() : null,
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Desconectar'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF566178),
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'v0.2-r3 • pareamento real inicial, sem espelhamento falso',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9AA3B4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
