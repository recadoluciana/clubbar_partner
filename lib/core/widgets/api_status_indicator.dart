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
  bool _consultando = true;
  String _ambiente = '?';

  @override
  void initState() {
    super.initState();
    _consultar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _consultar());
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
        _consultando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _bancoOnline = false;
        _ambiente = '?';
        _consultando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _consultando || (_online && !_bancoOnline)
        ? Colors.amber
        : _online
        ? Colors.greenAccent.shade400
        : Colors.redAccent;
    final api = _consultando ? '...' : (_online ? 'ON' : 'OFF');

    final iconeApi = _consultando
        ? Icons.sync_rounded
        : _online
        ? Icons.cloud_done_rounded
        : Icons.cloud_off_rounded;

    return Tooltip(
      message:
          'API: ${_online ? 'online' : 'offline'} | Banco: ${_bancoOnline ? 'online' : 'offline'} | Ambiente: $_ambiente',
      child: InkWell(
        onTap: _consultar,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconeApi, color: cor, size: 15),
              const SizedBox(width: 3),
              Text(
                'API $api',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.storage_rounded,
                color: _bancoOnline ? Colors.greenAccent.shade400 : cor,
                size: 14,
              ),
              const SizedBox(width: 2),
              Text(
                'DB $_ambiente · v${widget.versao}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
