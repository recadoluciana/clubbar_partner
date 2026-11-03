import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';

class TitularMercadoPagoPage extends StatefulWidget {
  const TitularMercadoPagoPage({
    super.key,
    required this.organizacaoId,
    required this.titularId,
    required this.nome,
  });

  final int organizacaoId;
  final int titularId;
  final String nome;

  @override
  State<TitularMercadoPagoPage> createState() => _TitularMercadoPagoPageState();
}

class _TitularMercadoPagoPageState extends State<TitularMercadoPagoPage> {
  Timer? _timer;
  Map<String, dynamic>? _dados;
  Map<String, dynamic>? _perfil;
  bool _ocupado = false;
  String get _base =>
      '/organizacoes/${widget.organizacaoId}/titulares/${widget.titularId}/mercado-pago';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final resposta = await ApiService.get(_base);
      if (resposta.statusCode != 200) {
        throw Exception('Não foi possível consultar a conta Mercado Pago.');
      }
      final dados = Map<String, dynamic>.from(jsonDecode(resposta.body));
      if (!mounted) return;
      setState(() => _dados = dados);
      if (dados['conta_pendente'] != null) _timer?.cancel();
      if (dados['conectada'] == true && _perfil == null) {
        try {
          final perfil = await ApiService.get('$_base/perfil');
          if (perfil.statusCode == 200 && mounted) {
            setState(
              () =>
                  _perfil = Map<String, dynamic>.from(jsonDecode(perfil.body)),
            );
          }
        } catch (_) {
          // A conexão continua válida mesmo se o perfil estiver indisponível.
        }
      }
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _conectar() async {
    setState(() => _ocupado = true);
    try {
      final resposta = await ApiService.post('$_base/autorizacao', {});
      if (resposta.statusCode != 200) {
        throw Exception('Não foi possível iniciar a autorização.');
      }
      final url = Uri.parse(jsonDecode(resposta.body)['authorization_url']);
      if (!await launchUrl(
        url,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      )) {
        throw Exception('Não foi possível abrir o Mercado Pago.');
      }
      _timer?.cancel();
      final prazo = DateTime.now().add(const Duration(minutes: 10));
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (DateTime.now().isAfter(prazo)) {
          timer.cancel();
          return;
        }
        _carregar();
      });
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmar(bool confirmar) async {
    final pendente = _dados?['conta_pendente'];
    if (pendente == null) return;
    setState(() => _ocupado = true);
    try {
      final resposta = await ApiService.post('$_base/confirmacao', {
        'confirmacao_id': pendente['confirmacao_id'],
        'confirmar': confirmar,
      });
      if (resposta.statusCode != 200) {
        throw Exception('Não foi possível confirmar a conta.');
      }
      _perfil = null;
      await _carregar();
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _desconectar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar conta Mercado Pago?'),
        content: const Text(
          'As lojas vinculadas devem deixar de usar este provedor antes da desconexão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final resposta = await ApiService.post('$_base/desconectar', {});
      if (resposta.statusCode != 200) {
        final detalhe = jsonDecode(resposta.body)['detail'];
        throw Exception(detalhe ?? 'Não foi possível desconectar a conta.');
      }
      await _carregar();
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendente = _dados?['conta_pendente'];
    return Scaffold(
      appBar: AppBar(title: const Text('Mercado Pago')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Titular financeiro: ${widget.nome}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_dados == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                _dados!['conectada'] == true
                    ? 'Conta conectada: ${_dados!['nome'] ?? 'Nome indisponível'}'
                    : 'Nenhuma conta Mercado Pago conectada.',
              ),
              if (_dados!['conectada'] == true) ...[
                Text('Titular: ${_perfil?['nome'] ?? 'Não disponível'}'),
                Text('E-mail: ${_perfil?['email'] ?? 'Não disponível'}'),
              ],
              if (pendente != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Confirme se a conta ${pendente['nome']} (ID ${pendente['user_id']}) pertence a ${widget.nome}.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _ocupado ? null : () => _confirmar(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: _ocupado ? null : () => _confirmar(true),
                      child: const Text('Confirmar conta'),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _ocupado ? null : _conectar,
                  child: Text(
                    _dados!['conectada'] == true
                        ? 'Trocar conta Mercado Pago'
                        : 'Conectar Mercado Pago',
                  ),
                ),
                if (_dados!['conectada'] == true)
                  TextButton(
                    onPressed: _ocupado ? null : _desconectar,
                    child: const Text('Desconectar conta'),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
