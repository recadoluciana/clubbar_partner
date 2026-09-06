import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/auditoria_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/auditoria.dart';
import '../../models/loja.dart';

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});

  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  final _repo = AuditoriaRepository();
  final _lojaRepo = LojaRepository();
  final _busca = TextEditingController();
  List<AuditoriaItem> _itens = [];
  bool _carregando = true;
  String? _erro;
  String? _acao;
  String? _tabela;
  int? _lojaId;
  int _dias = 30;
  Map<int, String> _nomesLojas = {};

  List<String> get _tabelas {
    final valores = _itens.map((item) => item.tabela).toSet().toList()..sort();
    return valores;
  }

  List<int> get _lojas {
    final valores =
        _itens.map((item) => item.lojaId).whereType<int>().toSet().toList()
          ..sort();
    return valores;
  }

  List<AuditoriaItem> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    return _itens.where((item) {
      if (_acao != null && item.acao != _acao) return false;
      if (_tabela != null && item.tabela != _tabela) return false;
      if (_lojaId != null && item.lojaId != _lojaId) return false;
      if (termo.isEmpty) return true;
      return item.atorNome.toLowerCase().contains(termo) ||
          (item.atorEmail ?? '').toLowerCase().contains(termo) ||
          item.tabela.toLowerCase().contains(termo) ||
          item.registroId.toLowerCase().contains(termo) ||
          (item.rota ?? '').toLowerCase().contains(termo);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      final resultados = await Future.wait<dynamic>([
        _repo.listar(dias: _dias),
        if (organizacaoId != null && organizacaoId > 0)
          _lojaRepo.listar(organizacaoId)
        else
          Future.value(<Loja>[]),
      ]);
      final itens = resultados[0] as List<AuditoriaItem>;
      final lojas = resultados[1] as List<Loja>;
      if (mounted) {
        setState(() {
          _itens = itens;
          _nomesLojas = {for (final loja in lojas) loja.lojaId: loja.nmloja};
          if (_tabela != null && !_tabelas.contains(_tabela)) _tabela = null;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _carregando = false;
        });
      }
    }
  }

  String _nomeLoja(int id) => _nomesLojas[id] ?? 'Estabelecimento $id';

  Color _corAcao(String acao) => switch (acao) {
    'INCLUSAO' => Colors.green,
    'ALTERACAO' => Colors.blue,
    'EXCLUSAO' => ClubbarColors.erro,
    _ => ClubbarColors.textoSecundario,
  };

  String _nomeAcao(String acao) => switch (acao) {
    'INCLUSAO' => 'Inclusão',
    'ALTERACAO' => 'Alteração',
    'EXCLUSAO' => 'Exclusão',
    _ => acao,
  };

  String _json(Map<String, dynamic>? dados) => dados == null || dados.isEmpty
      ? 'Nenhuma informação.'
      : const JsonEncoder.withIndent('  ').convert(dados);

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por usuário, tabela, registro ou rota',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _acao,
                  decoration: const InputDecoration(labelText: 'Ação'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'INCLUSAO',
                      child: Text('Inclusão'),
                    ),
                    DropdownMenuItem(
                      value: 'ALTERACAO',
                      child: Text('Alteração'),
                    ),
                    DropdownMenuItem(
                      value: 'EXCLUSAO',
                      child: Text('Exclusão'),
                    ),
                  ],
                  onChanged: (valor) => setState(() => _acao = valor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _dias,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 dias')),
                    DropdownMenuItem(value: 30, child: Text('30 dias')),
                    DropdownMenuItem(value: 90, child: Text('90 dias')),
                    DropdownMenuItem(value: 365, child: Text('1 ano')),
                  ],
                  onChanged: (valor) {
                    if (valor == null || valor == _dias) return;
                    _dias = valor;
                    _carregar();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _tabela,
            decoration: const InputDecoration(labelText: 'Tabela'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas as tabelas'),
              ),
              ..._tabelas.map(
                (valor) => DropdownMenuItem(value: valor, child: Text(valor)),
              ),
            ],
            onChanged: (valor) => setState(() => _tabela = valor),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            initialValue: _lojaId,
            decoration: const InputDecoration(labelText: 'Estabelecimento'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todos os estabelecimentos'),
              ),
              ..._lojas.map(
                (id) => DropdownMenuItem(value: id, child: Text(_nomeLoja(id))),
              ),
            ],
            onChanged: (valor) => setState(() => _lojaId = valor),
          ),
        ],
      ),
    );
  }

  Widget _card(AuditoriaItem item) {
    final cor = _corAcao(item.acao);
    final data = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
      'pt_BR',
    ).format(item.dataCriacao);
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.12),
          child: Icon(Icons.history_rounded, color: cor),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.tabela,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _nomeAcao(item.acao),
                style: TextStyle(
                  color: cor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text('${item.atorNome} • $data\nRegistro ${item.registroId}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          if (item.atorEmail?.isNotEmpty == true)
            _linha('E-mail', item.atorEmail!),
          if (item.metodoHttp?.isNotEmpty == true)
            _linha('Método', item.metodoHttp!),
          if (item.lojaId != null)
            _linha('Estabelecimento', _nomeLoja(item.lojaId!)),
          if (item.rota?.isNotEmpty == true) _linha('Rota', item.rota!),
          if (item.dadosAnteriores != null)
            _dados('Dados anteriores', _json(item.dadosAnteriores)),
          if (item.dadosNovos != null)
            _dados('Dados novos', _json(item.dadosNovos)),
        ],
      ),
    );
  }

  Widget _linha(String titulo, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: SelectableText(valor)),
      ],
    ),
  );

  Widget _dados(String titulo, String valor) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ClubbarColors.fundo,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ClubbarColors.borda),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        SelectableText(
          valor,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Auditoria',
              subtitulo: _carregando
                  ? 'Carregando movimentações...'
                  : '${itens.length} registros encontrados',
              trailing: IconButton.filled(
                tooltip: 'Atualizar',
                onPressed: _carregando ? null : _carregar,
                style: IconButton.styleFrom(
                  backgroundColor: ClubbarColors.ambar,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            _filtros(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregar,
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _erro != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 70),
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 54,
                            color: ClubbarColors.erro,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_erro!, textAlign: TextAlign.center),
                          ),
                          TextButton(
                            onPressed: _carregar,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      )
                    : itens.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 70),
                          Icon(
                            Icons.manage_search_rounded,
                            size: 58,
                            color: ClubbarColors.textoSecundario,
                          ),
                          Center(child: Text('Nenhum registro encontrado.')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: itens.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, index) => _card(itens[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
