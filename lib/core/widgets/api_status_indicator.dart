import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiStatusIndicator extends StatefulWidget {
  final String versao;

  const ApiStatusIndicator({super.key, required this.versao});

  @override
  State<ApiStatusIndicator> createState() => _ApiStatusIndicatorState();
}

class _ApiStatusIndicatorState extends State<ApiStatusIndicator> {
  Timer? _timer;
  bool _online = false;
  bool _bancoOnline = false;
  String _ambiente = '?';

  bool get _exibirDev =>
      ApiConfig.isDev ||
      ApiConfig.baseUrl.contains('desenvolvimento') ||
      ApiConfig.baseUrl.contains('localhost');

  @override
  void initState() {
    super.initState();
    if (_exibirDev) {
      _consultar();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _consultar());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      final dados = response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _online =
            response.statusCode == 200 &&
            (dados['api'] == null || dados['api'] == 'online');
        _bancoOnline = dados['database'] == 'online';
        _ambiente = (dados['environment'] ?? '?').toString().toUpperCase();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _bancoOnline = false;
        _ambiente = '?';
      });
    }
  }

  Future<void> _mostrarDetalhes() async {
    await _consultar();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.developer_mode_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Ambiente DEV'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API: ${_online ? 'online' : 'offline'}'),
            const SizedBox(height: 8),
            Text('Banco: ${_bancoOnline ? 'online' : 'offline'}'),
            const SizedBox(height: 8),
            Text('Ambiente: $_ambiente'),
            const SizedBox(height: 8),
            Text('Versão: ${widget.versao}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_exibirDev) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Ver informações do ambiente',
        child: InkWell(
          onTap: _mostrarDetalhes,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 7),
                SizedBox(width: 5),
                Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
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
