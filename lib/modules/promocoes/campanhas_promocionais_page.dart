import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../models/loja.dart';

class CampanhasPromocionaisPage extends StatefulWidget {
  const CampanhasPromocionaisPage({super.key, required this.organizacaoId});
  final int organizacaoId;

  @override
  State<CampanhasPromocionaisPage> createState() =>
      _CampanhasPromocionaisPageState();
}

class _CampanhasPromocionaisPageState extends State<CampanhasPromocionaisPage> {
  final _titulo = TextEditingController();
  final _mensagem = TextEditingController();
  List<Loja> _lojas = [];
  List<dynamic> _campanhas = [];
  int? _loja;
  bool _carregando = true;
  bool _push = true;
  bool _whatsapp = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _mensagem.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final lojas = await LojaRepository().listar(widget.organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _loja = lojas.isEmpty ? null : lojas.first.lojaId;
        _carregando = false;
      });
      if (_loja != null) await _carregar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _erro('Não foi possível carregar os estabelecimentos.');
    }
  }

  void _erro(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _carregar() async {
    final loja = _loja;
    if (loja == null) return;
    try {
      final r = await ApiService.get('/campanhas-promocionais/lojas/$loja');
      if (r.statusCode != 200) throw Exception();
      final dados = jsonDecode(r.body) as List<dynamic>;
      if (!mounted || _loja != loja) return;
      setState(() => _campanhas = dados);
    } catch (_) {
      if (mounted) _erro('Não foi possível carregar as campanhas.');
    }
  }

  Future<void> _salvar() async {
    final loja = _loja;
    if (loja == null ||
        _titulo.text.trim().isEmpty ||
        _mensagem.text.trim().isEmpty) {
      _erro('Informe o estabelecimento, o título e a mensagem.');
      return;
    }
    setState(() => _carregando = true);
    try {
      final r = await ApiService.post('/campanhas-promocionais', {
        'loja_id': loja,
        'titulo': _titulo.text.trim(),
        'mensagem': _mensagem.text.trim(),
      });
      if (r.statusCode != 201) throw Exception();
      _titulo.clear();
      _mensagem.clear();
      await _carregar();
      if (mounted) _erro('Rascunho salvo. Nenhuma mensagem foi enviada.');
    } catch (_) {
      if (mounted) _erro('Não foi possível salvar a campanha.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviar(Map campanha) async {
    if (!_push && !_whatsapp) {
      _erro('Selecione pelo menos um canal de envio.');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar promoção?'),
        content: const Text(
          'A mensagem será enviada aos clientes desta loja que autorizaram os canais selecionados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _carregando = true);
    try {
      final r = await ApiService.post(
        '/campanhas-promocionais/${campanha['id']}/enviar',
        {'push': _push, 'whatsapp': _whatsapp},
      );
      final dados = jsonDecode(r.body);
      if (r.statusCode != 200) {
        throw Exception(
          dados is Map && dados['detail'] is String
              ? dados['detail']
              : 'Não foi possível iniciar o envio.',
        );
      }
      await _carregar();
      if (mounted) {
        _erro('Envio iniciado para ${dados['destinatarios']} destino(s).');
      }
    } catch (e) {
      if (mounted) _erro(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _resultado(Map campanha) async {
    try {
      final r = await ApiService.get(
        '/campanhas-promocionais/${campanha['id']}/resultado',
      );
      if (r.statusCode != 200) throw Exception();
      final dados = jsonDecode(r.body) as Map<String, dynamic>;
      final entregas = Map<String, dynamic>.from(dados['entregas'] as Map);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resultado da campanha'),
          content: Text(
            'Situação: ${dados['status']}\n\n${entregas.entries.map((e) => '${e.key}: ${e.value}').join('\n')}\n\nEnviado significa que o provedor aceitou a solicitação; não confirma a leitura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _erro('Não foi possível consultar o resultado.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Campanhas promocionais')),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Crie uma promoção para os clientes que autorizaram o recebimento.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _loja,
                decoration: const InputDecoration(
                  labelText: 'Estabelecimento',
                  border: OutlineInputBorder(),
                ),
                items: _lojas
                    .map(
                      (loja) => DropdownMenuItem(
                        value: loja.lojaId,
                        child: Text(loja.nmloja),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _loja = v;
                    _campanhas = [];
                  });
                  _carregar();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titulo,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Título da promoção',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mensagem,
                minLines: 3,
                maxLines: 6,
                maxLength: 1024,
                decoration: const InputDecoration(
                  labelText: 'Mensagem',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Notificação no aplicativo'),
                value: _push,
                onChanged: (v) => setState(() => _push = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('WhatsApp'),
                value: _whatsapp,
                onChanged: (v) => setState(() => _whatsapp = v ?? false),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _salvar,
                child: const Text('Salvar rascunho'),
              ),
              const SizedBox(height: 24),
              Text('Campanhas', style: Theme.of(context).textTheme.titleLarge),
              if (_campanhas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhuma campanha cadastrada.'),
                ),
              for (final c in _campanhas)
                Card(
                  child: ListTile(
                    title: Text('${c['titulo']}'),
                    subtitle: Text('${c['mensagem']}\n${c['status']}'),
                    trailing: c['status'] == 'RASCUNHO'
                        ? TextButton(
                            onPressed: () => _enviar(c as Map),
                            child: const Text('Enviar'),
                          )
                        : TextButton(
                            onPressed: () => _resultado(c as Map),
                            child: const Text('Resultado'),
                          ),
                  ),
                ),
            ],
          ),
  );
}
