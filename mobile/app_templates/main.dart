import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SWAirLinkApp());
}

class SWAirLinkApp extends StatefulWidget {
  const SWAirLinkApp({super.key});

  @override
  State<SWAirLinkApp> createState() => _SWAirLinkAppState();
}

class _SWAirLinkAppState extends State<SWAirLinkApp> {
  bool amoled = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => amoled = prefs.getBool('amoled') ?? false);
  }

  Future<void> _setAmoled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('amoled', value);
    setState(() => amoled = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(amoled: amoled);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SW Air Link',
      theme: ThemeData(
        useMaterial3: true,
        brightness: amoled ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.background,
      ),
      home: HomeScreen(
        amoled: amoled,
        colors: colors,
        onThemeChanged: _setAmoled,
      ),
    );
  }
}

class AppColors {
  final bool amoled;
  late final Color background;
  late final Color card;
  late final Color input;
  late final Color border;
  late final Color text;
  late final Color muted;
  late final Color soft;
  late final Color primary;
  late final Color success;
  late final Color danger;

  AppColors({required this.amoled}) {
    background = amoled ? const Color(0xFF000000) : const Color(0xFFF7F8FC);
    card = amoled ? const Color(0xFF05060A) : const Color(0xFFFFFFFF);
    input = amoled ? const Color(0xFF0B0D14) : const Color(0xFFF8F9FD);
    border = amoled ? const Color(0xFF222633) : const Color(0xFFE0E4EE);
    text = amoled ? const Color(0xFFF5F7FF) : const Color(0xFF11141C);
    muted = amoled ? const Color(0xFFA4ABBA) : const Color(0xFF687083);
    soft = amoled ? const Color(0xFF101726) : const Color(0xFFEEF3FF);
    primary = const Color(0xFF5670B2);
    success = const Color(0xFF2D8B61);
    danger = const Color(0xFFB65757);
  }
}

class HomeScreen extends StatefulWidget {
  final bool amoled;
  final AppColors colors;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.amoled,
    required this.colors,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _mirrorChannel = MethodChannel('sw_air_link/mirror');
  static const EventChannel _frameEvents = EventChannel('sw_air_link/frames');

  final TextEditingController _serverController =
      TextEditingController(text: 'ws://127.0.0.1:8080');
  final TextEditingController _codeController = TextEditingController();

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  StreamSubscription? _frameSub;

  bool _connected = false;
  bool _connecting = false;
  bool _mirroring = false;
  int _framesSent = 0;
  String _status = 'Digite o código gerado no navegador.';

  @override
  void initState() {
    super.initState();
    _loadSavedFields();
    _listenNativeFrames();
  }

  Future<void> _loadSavedFields() async {
    final prefs = await SharedPreferences.getInstance();
    _serverController.text = prefs.getString('server') ?? _serverController.text;
    _codeController.text = prefs.getString('code') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _saveFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', _serverController.text.trim());
    await prefs.setString('code', _codeController.text.trim());
  }

  void _listenNativeFrames() {
    _frameSub?.cancel();
    _frameSub = _frameEvents.receiveBroadcastStream().listen(
      (event) {
        if (!mounted) return;

        if (event is Map) {
          final type = '${event['type'] ?? ''}';

          if (type == 'frame') {
            final data = '${event['data'] ?? ''}';
            if (data.isNotEmpty && _channel != null && _connected) {
              _channel!.sink.add(jsonEncode({
                'type': 'frame',
                'role': 'phone',
                'roomCode': _codeController.text.trim(),
                'frame': data,
              }));
              setState(() {
                _framesSent++;
                _mirroring = true;
                _status = 'Transmitindo frames reais: $_framesSent';
              });
            }
            return;
          }

          if (type == 'status') {
            setState(() => _status = '${event['message'] ?? ''}');
            return;
          }

          if (type == 'error') {
            setState(() {
              _status = '${event['message'] ?? 'Erro desconhecido na captura.'}';
              _mirroring = false;
            });
            return;
          }
        }

        setState(() => _status = 'Evento nativo recebido.');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = 'Erro no canal de frames: $error';
          _mirroring = false;
        });
      },
    );
  }

  Future<void> _connect() async {
    final server = _serverController.text.trim();
    final code = _codeController.text.trim();

    if (server.isEmpty || code.isEmpty) {
      setState(() => _status = 'Informe o servidor WebSocket e o código.');
      return;
    }

    await _saveFields();

    setState(() {
      _connecting = true;
      _status = 'Conectando ao navegador...';
    });

    try {
      final channel = IOWebSocketChannel.connect(Uri.parse(server));
      _channel = channel;

      _socketSub?.cancel();
      _socketSub = channel.stream.listen(
        (raw) {
          if (!mounted) return;
          try {
            final message = jsonDecode(raw.toString());
            final type = message['type'];

            if (type == 'joined') {
              setState(() {
                _connected = true;
                _connecting = false;
                _status = 'Telefone conectado. Agora inicie o espelhamento.';
              });
            } else if (type == 'peer_joined') {
              setState(() => _status = 'Navegador conectado.');
            } else if (type == 'peer_left') {
              setState(() => _status = 'Navegador saiu da sessão.');
            } else if (type == 'error') {
              setState(() => _status = 'Servidor: ${message['message']}');
            }
          } catch (_) {
            setState(() => _status = 'Mensagem recebida do servidor.');
          }
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _mirroring = false;
            _status = 'Conexão encerrada.';
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _mirroring = false;
            _status = 'Falha no WebSocket: $error';
          });
        },
      );

      channel.sink.add(jsonEncode({
        'type': 'join',
        'role': 'phone',
        'roomCode': code,
      }));
    } catch (e) {
      setState(() {
        _connecting = false;
        _status = 'Não conectou: $e';
      });
    }
  }

  Future<void> _startMirror() async {
    if (!_connected || _channel == null) {
      setState(() => _status = 'Conecte ao navegador antes de espelhar.');
      return;
    }

    try {
      setState(() {
        _status = 'Abrindo permissão do Android...';
        _framesSent = 0;
      });

      await _mirrorChannel.invokeMethod('startProjection');

      setState(() {
        _mirroring = true;
        _status = 'Permissão solicitada. Toque em “Iniciar agora” e aguarde o primeiro frame.';
      });
    } on PlatformException catch (e) {
      setState(() {
        _mirroring = false;
        _status = 'Erro ao solicitar captura: ${e.message ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _mirroring = false;
        _status = 'Erro inesperado ao iniciar captura: $e';
      });
    }
  }

  Future<void> _stopMirror() async {
    try {
      await _mirrorChannel.invokeMethod('stopProjection');
    } catch (_) {}
    setState(() {
      _mirroring = false;
      _status = 'Espelhamento parado.';
    });
  }

  Future<void> _disconnect() async {
    await _stopMirror();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    setState(() {
      _connected = false;
      _connecting = false;
      _mirroring = false;
      _status = 'Desconectado.';
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    _socketSub?.cancel();
    _frameSub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              width: 430,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: c.border),
                boxShadow: [
                  if (!widget.amoled)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cast_connected_rounded, size: 54, color: c.primary),
                  const SizedBox(height: 14),
                  Text(
                    'SW Air Link',
                    style: TextStyle(
                      fontSize: 34,
                      height: 1,
                      color: c.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'App simples para conectar o telefone ao navegador. A tela principal ficará no site.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      color: c.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ThemeToggle(
                    amoled: widget.amoled,
                    colors: c,
                    onChanged: widget.onThemeChanged,
                  ),
                  const SizedBox(height: 18),
                  _InputBox(
                    label: 'Servidor WebSocket',
                    icon: Icons.dns_rounded,
                    controller: _serverController,
                    colors: c,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),
                  _InputBox(
                    label: 'Código do navegador',
                    icon: Icons.pin_rounded,
                    controller: _codeController,
                    colors: c,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  _ActionButton(
                    label: _connecting ? 'Conectando...' : 'Preparar conexão',
                    icon: Icons.link_rounded,
                    enabled: !_connecting && !_connected,
                    color: c.primary,
                    onTap: _connect,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Iniciar espelhamento experimental',
                    icon: Icons.image_rounded,
                    enabled: _connected && !_mirroring,
                    color: c.success,
                    onTap: _startMirror,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Parar espelhamento',
                    icon: Icons.hide_image_rounded,
                    enabled: _mirroring,
                    color: c.danger,
                    outlined: true,
                    onTap: _stopMirror,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Desconectar',
                    icon: Icons.link_off_rounded,
                    enabled: _connected,
                    color: c.danger,
                    outlined: true,
                    onTap: _disconnect,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: c.soft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'v0.3-r9 • templates restaurados + Crash Guard',
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool amoled;
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  const _ThemeToggle({
    required this.amoled,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(String text, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: active ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.white : colors.muted,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          item('Claro', !amoled, () => onChanged(false)),
          item('AMOLED', amoled, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final AppColors colors;
  final TextInputType keyboardType;

  const _InputBox({
    required this.label,
    required this.icon,
    required this.controller,
    required this.colors,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.text, fontSize: 20, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.muted),
        prefixIcon: Icon(icon, color: colors.muted),
        filled: true,
        fillColor: colors.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 1.8),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled
        ? (outlined ? Colors.transparent : color)
        : Colors.grey.withValues(alpha: 0.12);
    final fg = enabled
        ? (outlined ? color : Colors.white)
        : Colors.grey.withValues(alpha: 0.55);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: outlined ? Border.all(color: fg.withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 19),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
