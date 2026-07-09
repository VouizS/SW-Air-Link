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
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9FB7FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
  String _status = 'Aguardando código do navegador';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _connect() {
    final code = _codeController.text.trim();
    setState(() {
      if (code.isEmpty) {
        _status = 'Digite o código exibido no navegador.';
      } else {
        _status = 'Código $code recebido. Pareamento real entra na próxima versão.';
      }
    });
  }

  void _startMirrorNotice() {
    setState(() {
      _status = 'Espelhamento real ainda não está ativo nesta base. Próxima etapa: MediaProjection.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B10),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cast_connected_rounded, size: 58),
                  const SizedBox(height: 18),
                  Text(
                    'SW Air Link',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'App simples para conectar o telefone ao navegador.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB8C2D2),
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Código do navegador',
                      hintText: 'Ex: 482913',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _connect,
                    child: const Text('Conectar ao navegador'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _startMirrorNotice,
                    child: const Text('Iniciar espelhamento'),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF141923),
                      border: Border.all(color: const Color(0xFF252B38)),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFD6DEEB)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'v0.1-r4 • base inicial sem função falsa',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7F8CA3), fontSize: 12),
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
