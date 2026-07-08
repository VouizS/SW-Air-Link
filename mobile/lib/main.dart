import 'package:flutter/material.dart';

void main() {
  runApp(const SWAirLinkApp());
}

class SWAirLinkApp extends StatelessWidget {
  const SWAirLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SW Air Link',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  String _status = 'Aguardando conexão...';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _connect() {
    final code = _codeController.text.trim();
    setState(() {
      _status = code.isEmpty
          ? 'Digite o código mostrado no navegador.'
          : 'Código $code preparado. Pareamento real entra na v0.2.';
    });
  }

  void _scanQr() {
    setState(() {
      _status = 'Leitor de QR Code será implementado na v0.2.';
    });
  }

  void _startMirror() {
    setState(() {
      _status = 'Espelhamento real será implementado com MediaProjection na v0.4.';
    });
  }

  void _stopMirror() {
    setState(() {
      _status = 'Nenhum espelhamento ativo nesta versão foundation.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cast_connected, color: Colors.white, size: 54),
                  const SizedBox(height: 18),
                  const Text(
                    'SW Air Link',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conecte este telefone ao navegador. O app é simples; o painel principal fica no computador, Chromebook ou outro celular.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB7C0CE), fontSize: 15, height: 1.35),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 9,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Código',
                      hintStyle: const TextStyle(color: Color(0xFF657086), letterSpacing: 1),
                      filled: true,
                      fillColor: const Color(0xFF151922),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF2A3040)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF2A3040)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _connect,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B0D10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Conectar ao navegador'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _scanQr,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2A3040)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ler QR Code'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _startMirror,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF2A3040)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Iniciar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _stopMirror,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF2A3040)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Parar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151922),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2A3040)),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB7C0CE), fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'v0.1-r2 Foundation — app simples, sem permissões invasivas e sem função falsa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6E7A8F), fontSize: 12),
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
