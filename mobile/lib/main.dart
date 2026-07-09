import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _amoled = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _amoled = prefs.getBool('sw_air_link_amoled') ?? false;
    });
  }

  Future<void> _setAmoled(bool value) async {
    setState(() {
      _amoled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sw_air_link_amoled', value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(amoled: _amoled);

    return MaterialApp(
      title: 'SW Air Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: _amoled ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.background,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: _amoled ? Brightness.dark : Brightness.light,
        ),
      ),
      home: HomeScreen(
        amoled: _amoled,
        colors: colors,
        onThemeChanged: _setAmoled,
      ),
    );
  }
}

class AppColors {
  AppColors({required this.amoled});

  final bool amoled;

  Color get background => amoled ? const Color(0xFF000000) : const Color(0xFFF6F7FB);
  Color get card => amoled ? const Color(0xFF07080B) : const Color(0xFFFFFFFF);
  Color get field => amoled ? const Color(0xFF0E1015) : const Color(0xFFFAFBFF);
  Color get border => amoled ? const Color(0xFF2A2D36) : const Color(0xFFE0E3EC);
  Color get text => amoled ? const Color(0xFFF8FAFC) : const Color(0xFF171A22);
  Color get muted => amoled ? const Color(0xFFA5ADBA) : const Color(0xFF687083);
  Color get soft => amoled ? const Color(0xFF101522) : const Color(0xFFF0F4FF);
  Color get primary => const Color(0xFF4F68A8);
  Color get blueIcon => const Color(0xFF2D6BDB);
  Color get disabled => amoled ? const Color(0xFF1A1D24) : const Color(0xFFF5F6FA);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.amoled,
    required this.colors,
    required this.onThemeChanged,
  });

  final bool amoled;
  final AppColors colors;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _serverController = TextEditingController(text: 'ws://127.0.0.1:8080');
  final TextEditingController _codeController = TextEditingController();

  WebSocket? _socket;
  bool _connecting = false;
  bool _connected = false;
  String _status = 'Digite o código gerado no navegador.';

  AppColors get colors => widget.colors;

  @override
  void dispose() {
    _socket?.close();
    _serverController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final server = _serverController.text.trim();
    final code = _codeController.text.trim().replaceAll(' ', '');

    if (server.isEmpty || code.isEmpty) {
      setState(() {
        _status = 'Informe o servidor WebSocket e o código do navegador.';
      });
      return;
    }

    setState(() {
      _connecting = true;
      _status = 'Preparando conexão real...';
    });

    try {
      final socket = await WebSocket.connect(server).timeout(const Duration(seconds: 10));
      _socket = socket;

      socket.add(jsonEncode({
        'type': 'join',
        'role': 'phone',
        'roomCode': code,
        'version': 'v0.2-r4',
      }));

      socket.listen(
        _handleSocketMessage,
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _status = 'Conexão encerrada.';
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _status = 'Erro na conexão WebSocket.';
          });
        },
      );

      setState(() {
        _connected = true;
        _connecting = false;
        _status = 'Telefone conectado à sala $code. A tela ainda não será espelhada nesta versão.';
      });
    } catch (_) {
      setState(() {
        _connected = false;
        _connecting = false;
        _status = 'Não consegui conectar. Confira se o servidor local está aberto e se ambos estão na mesma rede.';
      });
    }
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      final message = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = message['type']?.toString() ?? '';

      if (type == 'joined') {
        setState(() {
          _status = 'Pareamento confirmado. Aguardando próximos recursos reais.';
        });
        return;
      }

      if (type == 'peer_joined') {
        final role = message['role']?.toString() ?? 'outro dispositivo';
        setState(() {
          _status = 'Dispositivo conectado: $role.';
        });
        return;
      }

      if (type == 'peer_left') {
        setState(() {
          _status = 'O navegador saiu da sala.';
        });
        return;
      }

      if (type == 'error') {
        setState(() {
          _status = message['message']?.toString() ?? 'Erro recebido do servidor.';
        });
      }
    } catch (_) {
      setState(() {
        _status = 'Mensagem recebida, mas não reconhecida.';
      });
    }
  }

  Future<void> _disconnect() async {
    await _socket?.close();
    _socket = null;
    setState(() {
      _connected = false;
      _connecting = false;
      _status = 'Desconectado. Digite outro código para conectar novamente.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: colors.border),
                  boxShadow: widget.amoled
                      ? const []
                      : const [
                          BoxShadow(
                            blurRadius: 28,
                            offset: Offset(0, 16),
                            color: Color(0x16000000),
                          ),
                        ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cast_connected_rounded, size: 58, color: colors.blueIcon),
                    const SizedBox(height: 20),
                    Text(
                      'SW Air Link',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 36,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'App simples para conectar o telefone ao navegador. A tela principal ficará no site.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted, fontSize: 18, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    ThemeSwitch(
                      amoled: widget.amoled,
                      colors: colors,
                      onChanged: widget.onThemeChanged,
                    ),
                    const SizedBox(height: 18),
                    AirTextField(
                      controller: _serverController,
                      label: 'Servidor WebSocket',
                      hint: 'ws://192.168.0.10:8080',
                      icon: Icons.dns_rounded,
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    AirTextField(
                      controller: _codeController,
                      label: 'Código do navegador',
                      hint: '123456',
                      icon: Icons.pin_rounded,
                      colors: colors,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: FilledButton.icon(
                        onPressed: _connecting || _connected ? null : _connect,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          disabledBackgroundColor: colors.disabled,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        icon: _connecting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.text),
                                ),
                              )
                            : const Icon(Icons.link_rounded),
                        label: Text(_connecting ? 'Conectando...' : 'Preparar conexão'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton.icon(
                        onPressed: _connected ? _disconnect : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.muted,
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Desconectar'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 16, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'v0.2-r4 • AMOLED opcional, pareamento real inicial',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
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

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({
    super.key,
    required this.amoled,
    required this.colors,
    required this.onChanged,
  });

  final bool amoled;
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ThemeButton(
              label: 'Claro',
              selected: !amoled,
              colors: colors,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ThemeButton(
              label: 'AMOLED',
              selected: amoled,
              colors: colors,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : colors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class AirTextField extends StatelessWidget {
  const AirTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.colors,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final AppColors colors;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.text, fontSize: 18),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colors.muted),
        filled: true,
        fillColor: colors.field,
        labelStyle: TextStyle(color: colors.muted),
        hintStyle: TextStyle(color: colors.muted),
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
