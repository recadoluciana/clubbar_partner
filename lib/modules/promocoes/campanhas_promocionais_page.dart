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
  final _busca = TextEditingController();
  List<Loja> _lojas = [];
  List<dynamic> _campanhas = [];
  List<Map<String, dynamic>> _clientes = [];
  final Set<int> _clientesSelecionados = {};
  int? _loja;
  bool _carregando = true;
  bool _push = true;
  bool _email = true;
  bool _criando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _mensagem.dispose();
    _busca.dispose();
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
      if (mounted) {
        setState(() => _criando = false);
        _erro('Rascunho salvo. Nenhuma mensagem foi enviada.');
      }
    } catch (_) {
      if (mounted) _erro('Não foi possível salvar a campanha.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviar(Map campanha) async {
    var pushSelecionado = _push;
    var emailSelecionado = _email;
    final selecionados = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        final selecionadosLocal = Set<int>.from(_clientesSelecionados);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Escolha os destinatários'),
            content: SizedBox(
              width: 460,
              child: _clientes.isEmpty
                  ? const Text('Nenhum cliente disponível para envio.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Enviar campanha por'),
                          CheckboxListTile(
                            title: const Text('Notificação no aplicativo'),
                            value: pushSelecionado,
                            onChanged: (valor) => setDialogState(
                              () => pushSelecionado = valor ?? false,
                            ),
                          ),
                          CheckboxListTile(
                            title: const Text('E-mail'),
                            value: emailSelecionado,
                            onChanged: (valor) => setDialogState(
                              () => emailSelecionado = valor ?? false,
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Selecionar todos'),
                            value: selecionadosLocal.length == _clientes.length,
                            onChanged: (marcado) => setDialogState(() {
                              if (marcado == true) {
                                selecionadosLocal
                                  ..clear()
                                  ..addAll(
                                    _clientes.map(
                                      (e) => (e['cliente_id'] as num).toInt(),
                                    ),
                                  );
                              } else {
                                selecionadosLocal.clear();
                              }
                            }),
                          ),
                          for (final cliente in _clientes)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${cliente['nome']}'),
                              subtitle: Text('${cliente['email']}'),
                              value: selecionadosLocal.contains(
                                (cliente['cliente_id'] as num).toInt(),
                              ),
                              onChanged: (marcado) => setDialogState(() {
                                final id = (cliente['cliente_id'] as num)
                                    .toInt();
                                marcado == true
                                    ? selecionadosLocal.add(id)
                                    : selecionadosLocal.remove(id);
                              }),
                            ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed:
                    selecionadosLocal.isEmpty ||
                        (!pushSelecionado && !emailSelecionado)
                    ? null
                    : () => Navigator.pop(context, selecionadosLocal),
                child: Text('Enviar (${selecionadosLocal.length})'),
              ),
            ],
          ),
        );
      },
    );
    if (selecionados == null || !mounted) return;
    setState(
      () => _clientesSelecionados
        ..clear()
        ..addAll(selecionados),
    );
    _push = pushSelecionado;
    _email = emailSelecionado;
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
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Situação: ${dados['status']}'),
                  const SizedBox(height: 12),
                  ...entregas.entries.map((e) => Text('${e.key}: ${e.value}')),
                  const SizedBox(height: 16),
                  const Text(
                    'Destinatários',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (dados['destinatarios'] is! List)
                    const Text(
                      'Atualize a API para consultar os destinatários.',
                    )
                  else if ((dados['destinatarios'] as List).isEmpty)
                    const Text(
                      'Não há destinatários registrados para esta campanha.',
                    )
                  else
                    for (final destinatario in dados['destinatarios'] as List)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${destinatario['nome']}'),
                        subtitle: Text(
                          [
                            if (destinatario['email'] != null)
                              '${destinatario['email']}',
                            for (final envio in destinatario['envios'] as List)
                              '${envio['canal'] == 'push' ? 'Notificação' : 'E-mail'}: ${envio['status']}',
                          ].join('\n'),
                        ),
                      ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enviado significa que o provedor aceitou a solicitação; não confirma a entrega ou a leitura.',
                  ),
                ],
              ),
            ),
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
          Text('Os canais e destinatários serão escolhidos ao enviar.'),
        ],
      ),
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
              ClubbarPageHeader(
                titulo: _criando ? 'Nova campanha' : 'Campanhas de Marketing',
                subtitulo: _criando
                    ? 'Crie e revise sua campanha.'
                    : 'Consulte e envie suas campanhas.',
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
                    if (_criando) ...[
                      TextButton.icon(
                        onPressed: () => setState(() => _criando = false),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar para campanhas'),
                      ),
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
                      const SizedBox(height: 12),
                      _preview(),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _salvar,
                        child: const Text('Salvar rascunho'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _busca,
                        decoration: const InputDecoration(
                          labelText: 'Buscar campanha',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => setState(() => _criando = true),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova campanha'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Campanhas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_campanhas
                          .where(
                            (c) => '${c['titulo']} ${c['mensagem']}'
                                .toLowerCase()
                                .contains(_busca.text.trim().toLowerCase()),
                          )
                          .isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Nenhuma campanha encontrada.'),
                        ),
                      for (final c in _campanhas.where(
                        (c) => '${c['titulo']} ${c['mensagem']}'
                            .toLowerCase()
                            .contains(_busca.text.trim().toLowerCase()),
                      ))
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
                  ],
                ),
              ),
            ],
          ),
  );
}
