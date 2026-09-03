import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/financeiro_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class FinanceiroParceiroPage extends StatefulWidget {
  final int? lojaId;
  final String? nomeLoja;

  const FinanceiroParceiroPage({super.key, this.lojaId, this.nomeLoja});

  @override
  State<FinanceiroParceiroPage> createState() => _FinanceiroParceiroPageState();
}

class _FinanceiroParceiroPageState extends State<FinanceiroParceiroPage> {
  final _repo = FinanceiroRepository();
  final _lojaRepo = LojaRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  Map<String, dynamic> _dados = {};
  Map<String, dynamic>? _conta;
  int? _lojaId;
  List<Loja> _lojas = [];
  String _nomeOrganizacao = 'Empresa';
  bool _carregando = true;
  String? _filtroStatus;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() => _carregando = true);
    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      final nomeOrganizacao = (await StorageService.getNomeOrganizacao() ?? '')
          .trim();
      final lojas = organizacaoId == null || organizacaoId <= 0
          ? <Loja>[]
          : await _lojaRepo.listar(organizacaoId);
      final lojaSalva = await StorageService.getLojaId();
      final lojaId =
          widget.lojaId ??
          lojaSalva ??
          (lojas.isNotEmpty ? lojas.first.lojaId : null);
      if (!mounted) return;
      setState(() {
        _nomeOrganizacao = nomeOrganizacao.isEmpty
            ? 'Empresa'
            : nomeOrganizacao;
        _lojas = lojas;
        _lojaId = lojaId;
      });
      if (lojaId == null || lojaId <= 0) {
        throw Exception(
          'Selecione um estabelecimento para consultar o financeiro.',
        );
      }
      await _carregarFinanceiro(lojaId);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregar() async {
    final lojaId = _lojaId;
    if (lojaId == null || lojaId <= 0) return;
    setState(() => _carregando = true);
    try {
      await _carregarFinanceiro(lojaId);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarFinanceiro(int lojaId) async {
    final resultados = await Future.wait([
      _repo.resumo(lojaId),
      _repo.conta(lojaId),
    ]);
    if (mounted) {
      setState(() {
        _lojaId = lojaId;
        _dados = resultados[0]!;
        _conta = resultados[1];
      });
    }
  }

  Future<void> _selecionarLoja(int? lojaId) async {
    if (lojaId == null || lojaId == _lojaId) return;
    setState(() {
      _lojaId = lojaId;
      _dados = {};
      _conta = null;
      _filtroStatus = null;
    });
    await _carregar();
  }

  double _numero(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _formatarData(Object? valor) {
    final data = DateTime.tryParse(valor?.toString() ?? '');
    return data == null ? '--/--/----' : DateFormat('dd/MM/yyyy').format(data);
  }

  bool _recebido(Map repasse) =>
      repasse['status']?.toString().toUpperCase() == 'PAGO';

  void _alternarFiltro(String filtro) {
    setState(() => _filtroStatus = _filtroStatus == filtro ? null : filtro);
  }

  Future<void> _editarConta() async {
    if (_lojaId == null) return;
    final campos = <String, TextEditingController>{
      'codigobanco': TextEditingController(
        text: _conta?['codigobanco']?.toString(),
      ),
      'nmbanco': TextEditingController(text: _conta?['nmbanco']?.toString()),
      'agencia': TextEditingController(text: _conta?['agencia']?.toString()),
      'nrconta': TextEditingController(text: _conta?['nrconta']?.toString()),
      'digitoconta': TextEditingController(
        text: _conta?['digitoconta']?.toString(),
      ),
      'nmtitular': TextEditingController(
        text: _conta?['nmtitular']?.toString(),
      ),
      'cpfcnpjtitular': TextEditingController(
        text: _conta?['cpfcnpjtitular']?.toString(),
      ),
      'chavepix': TextEditingController(text: _conta?['chavepix']?.toString()),
    };
    String tipoConta = _conta?['tipoconta']?.toString() ?? 'CORRENTE';
    final formKey = GlobalKey<FormState>();
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Conta para receber repasses'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _campo(
                      campos['codigobanco']!,
                      'Código do banco',
                      obrigatorio: true,
                    ),
                    _campo(campos['nmbanco']!, 'Nome do banco'),
                    Row(
                      children: [
                        Expanded(
                          child: _campo(
                            campos['agencia']!,
                            'Agência',
                            obrigatorio: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _campo(
                            campos['nrconta']!,
                            'Conta',
                            obrigatorio: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: _campo(campos['digitoconta']!, 'Dígito'),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: tipoConta,
                      decoration: const InputDecoration(
                        labelText: 'Tipo da conta',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CORRENTE',
                          child: Text('Conta corrente'),
                        ),
                        DropdownMenuItem(
                          value: 'POUPANCA',
                          child: Text('Poupança'),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => tipoConta = v!),
                    ),
                    _campo(
                      campos['nmtitular']!,
                      'Nome do titular',
                      obrigatorio: true,
                    ),
                    _campo(
                      campos['cpfcnpjtitular']!,
                      'CPF/CNPJ do titular',
                      obrigatorio: true,
                    ),
                    _campo(campos['chavepix']!, 'Chave PIX (opcional)'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;
    await _repo.salvarConta(_lojaId!, {
      for (final e in campos.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      'tipoconta': tipoConta,
      'tipochavepix': null,
      'status': 'ATIVA',
    });
    await _carregar();
  }

  Widget _campo(
    TextEditingController c,
    String label, {
    bool obrigatorio = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: obrigatorio
          ? (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null
          : null,
    ),
  );

  Widget _card(
    String titulo,
    Object? valor,
    IconData icone,
    Color cor,
    String filtro,
  ) => Expanded(
    child: Semantics(
      button: true,
      selected: _filtroStatus == filtro,
      child: Card(
        color: _filtroStatus == filtro ? cor.withValues(alpha: 0.12) : null,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: _filtroStatus == filtro ? cor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _alternarFiltro(filtro),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icone, color: cor),
                const SizedBox(height: 8),
                Text(
                  _moeda.format(_numero(valor)),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(titulo, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _repasseCard(Map r) {
    final recebido = _recebido(r);
    final cor = recebido ? Colors.green : Colors.red;
    final status = recebido ? 'Recebido' : 'Aguardando repasse';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.12),
          child: Icon(
            recebido ? Icons.check_circle : Icons.schedule,
            color: cor,
          ),
        ),
        title: Text(
          _moeda.format(_numero(r['vrrepasse'])),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Venda #${r['venda_id']} • $status\n'
          'Venda em ${_formatarData(r['dtvenda'])}'
          '${recebido && r['dtpagamento'] != null ? '\nRecebido em ${_formatarData(r['dtpagamento'])}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repasses = (_dados['repasses'] as List? ?? const []).cast<Map>();
    final repassesFiltrados = repasses.where((r) {
      if (_filtroStatus == null) return true;
      return _filtroStatus == 'recebido' ? _recebido(r) : !_recebido(r);
    }).toList();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        actions: [
          IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _nomeOrganizacao,
            subtitulo: '',
            tituloStyle: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: ClubbarColors.info,
            ),
            subtituloWidget: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DropdownButtonFormField<int>(
                initialValue: _lojas.any((loja) => loja.lojaId == _lojaId)
                    ? _lojaId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Estabelecimento',
                  filled: true,
                  fillColor: ClubbarColors.branco,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: ClubbarColors.info),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: ClubbarColors.info),
                  ),
                ),
                items: _lojas
                    .map(
                      (loja) => DropdownMenuItem<int>(
                        value: loja.lojaId,
                        child: Text(
                          loja.nmloja,
                          style: const TextStyle(
                            color: ClubbarColors.info,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _carregando ? null : _selecionarLoja,
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            _card(
                              'A receber',
                              _dados['total_a_receber'],
                              Icons.schedule,
                              Colors.red,
                              'a_receber',
                            ),
                            _card(
                              'Recebido',
                              _dados['total_recebido'],
                              Icons.check_circle,
                              Colors.green,
                              'recebido',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: Icon(
                              _conta == null
                                  ? Icons.warning_amber
                                  : Icons.account_balance,
                              color: _conta == null
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            title: Text(
                              _conta == null
                                  ? 'Cadastre sua conta bancária'
                                  : '${_conta!['nmbanco'] ?? 'Banco'} • Ag. ${_conta!['agencia']} • Conta ${_conta!['nrconta']}',
                            ),
                            subtitle: Text(
                              _conta == null
                                  ? 'Repasses ficam bloqueados até o cadastro.'
                                  : 'Conta ativa para recebimento',
                            ),
                            trailing: const Icon(Icons.edit),
                            onTap: _editarConta,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
                          child: Text(
                            'Histórico de repasses',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (repassesFiltrados.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Center(
                                child: Text(
                                  repasses.isEmpty
                                      ? 'Ainda não há repasses.'
                                      : 'Nenhum lançamento neste filtro.',
                                ),
                              ),
                            ),
                          ),
                        ...repassesFiltrados.map(_repasseCard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
