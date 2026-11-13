import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../models/loja.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

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
  List<Map<String, dynamic>> _clientes = [];
  final Set<int> _clientesSelecionados = {};
  int? _loja;
  bool _carregando = true;
  bool _push = true;
  bool _email = true;

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
      try {
        await _carregarClientes();
      } catch (_) {
        if (mounted) _erro('Não foi possível carregar os clientes.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _erro('Não foi possível carregar os estabelecimentos.');
    }
  }

  Future<void> _carregarClientes() async {
    var r = await ApiService.get('/campanhas-promocionais/clientes');
    List<dynamic> dados;
    if (r.statusCode == 200 &&
        (jsonDecode(r.body) as List<dynamic>).isNotEmpty) {
      dados = jsonDecode(r.body) as List<dynamic>;
    } else {
      // Compatibilidade com a API anterior enquanto o endpoint específico
      // de campanhas ainda não estiver publicado em produção.
      r = await ApiService.get('/acompanhamento-vendas/clientes');
      if (r.statusCode != 200) {
        throw Exception('Não foi possível carregar os clientes.');
      }
      final resposta = jsonDecode(r.body) as Map<String, dynamic>;
      dados = ((resposta['clientes'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (cliente) => {
              'cliente_id': cliente['cliente_id'],
              'nome': cliente['nmcliente'],
              'email': cliente['emailcliente'],
            },
          )
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _clientes = dados
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _clientesSelecionados
        ..clear()
        ..addAll(_clientes.map((e) => (e['cliente_id'] as num).toInt()));
    });
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
    if (!_push && !_email) {
      _erro('Selecione pelo menos um canal de envio.');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar promoção?'),
        content: const Text(
          'A mensagem será enviada somente aos clientes selecionados que autorizaram os canais escolhidos.',
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
        {
          'push': _push,
          'email': _email,
          'cliente_ids': _clientesSelecionados.toList(),
        },
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

  Widget _preview() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pré-visualização do envio',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _titulo.text.trim().isEmpty
                ? 'Título da campanha'
                : _titulo.text.trim(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _mensagem.text.trim().isEmpty
                ? 'A mensagem aparecerá aqui.'
                : _mensagem.text.trim(),
          ),
          const SizedBox(height: 12),
          Text(
            '${_clientesSelecionados.length} cliente(s) selecionado(s) • ${_push ? 'Notificação' : ''}${_push && _email ? ' e ' : ''}${_email ? 'e-mail' : ''}',
          ),
        ],
      ),
    ),
  );

  Widget _selecaoClientes() => Card(
    margin: EdgeInsets.zero,
    child: ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        'Destinatários (${_clientesSelecionados.length}/${_clientes.length})',
      ),
      subtitle: const Text('Escolha um, alguns ou todos os clientes'),
      children: [
        CheckboxListTile(
          title: const Text('Selecionar todos'),
          value:
              _clientes.isNotEmpty &&
              _clientesSelecionados.length == _clientes.length,
          onChanged: (marcado) => setState(() {
            if (marcado == true) {
              _clientesSelecionados.addAll(
                _clientes.map((e) => (e['cliente_id'] as num).toInt()),
              );
            } else {
              _clientesSelecionados.clear();
            }
          }),
        ),
        for (final cliente in _clientes)
          CheckboxListTile(
            title: Text('${cliente['nome']}'),
            subtitle: Text('${cliente['email']}'),
            value: _clientesSelecionados.contains(
              (cliente['cliente_id'] as num).toInt(),
            ),
            onChanged: (marcado) => setState(() {
              final id = (cliente['cliente_id'] as num).toInt();
              marcado == true
                  ? _clientesSelecionados.add(id)
                  : _clientesSelecionados.remove(id);
            }),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarTopbar: true, mostrarVoltar: true),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ClubbarPageHeader(
                titulo: 'Campanhas de Marketing',
                subtitulo:
                    'Crie, revise e envie uma campanha para clientes selecionados.',
                mostrarVoltar: false,
                padding: EdgeInsets.fromLTRB(20, 14, 20, 16),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
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
                        labelText: 'Título da campanha',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
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
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                'Enviar campanha por',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            CheckboxListTile(
                              title: const Text('Notificação no aplicativo'),
                              value: _push,
                              onChanged: (v) =>
                                  setState(() => _push = v ?? false),
                            ),
                            CheckboxListTile(
                              title: const Text('E-mail'),
                              value: _email,
                              onChanged: (v) =>
                                  setState(() => _email = v ?? false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _selecaoClientes(),
                    const SizedBox(height: 12),
                    _preview(),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _salvar,
                      child: const Text('Salvar rascunho'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Campanhas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
              ),
            ],
          ),
  );
}
