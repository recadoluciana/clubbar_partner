import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/financeiro_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class FinanceiroParceiroPage extends StatefulWidget {
  const FinanceiroParceiroPage({super.key});

  @override
  State<FinanceiroParceiroPage> createState() => _FinanceiroParceiroPageState();
}

class _FinanceiroParceiroPageState extends State<FinanceiroParceiroPage> {
  final _repo = FinanceiroRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  Map<String, dynamic> _dados = {};
  Map<String, dynamic>? _conta;
  int? _lojaId;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lojaId = await StorageService.getLojaId();
      if (lojaId == null || lojaId <= 0) {
        throw Exception('Selecione uma loja para consultar o financeiro.');
      }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  double _numero(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

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

  Widget _card(String titulo, Object? valor, IconData icone, Color cor) =>
      Expanded(
        child: Card(
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
      );

  @override
  Widget build(BuildContext context) {
    final repasses = (_dados['repasses'] as List? ?? const []).cast<Map>();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: ClubbarAppBar(
        actions: [
          IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Meu financeiro',
            subtitulo: 'Acompanhe os repasses das suas vendas',
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
                              Colors.orange,
                            ),
                            _card(
                              'Recebido',
                              _dados['total_recebido'],
                              Icons.check_circle,
                              Colors.green,
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
                        if (repasses.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(
                                child: Text('Ainda não há repasses.'),
                              ),
                            ),
                          ),
                        ...repasses.map(
                          (r) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: ClubbarColors.ambarClaro,
                                child: Icon(
                                  Icons.payments,
                                  color: Colors.black,
                                ),
                              ),
                              title: Text(
                                _moeda.format(_numero(r['vrrepasse'])),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'Venda #${r['venda_id']} • ${r['status']}\n${r['dtpagamento'] != null ? 'Recebido em ${r['dtpagamento'].toString().substring(0, 10)}' : 'Aguardando repasse'}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
