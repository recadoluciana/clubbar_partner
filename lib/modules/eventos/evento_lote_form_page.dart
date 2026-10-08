import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento_lote.dart';

class EventoLoteFormPage extends StatefulWidget {
  final int eventoId;
  final int organizacaoId;
  final int lojaId;
  final String eventoTitulo;
  final String? eventoInicio;
  final List<EventoSetor> setores;
  final int proximoNumeroLote;
  final EventoLoteGlobal? loteGlobal;

  const EventoLoteFormPage({
    super.key,
    required this.eventoId,
    required this.organizacaoId,
    required this.lojaId,
    required this.eventoTitulo,
    required this.setores,
    required this.proximoNumeroLote,
    this.eventoInicio,
    this.loteGlobal,
  });

  @override
  State<EventoLoteFormPage> createState() => _EventoLoteFormPageState();
}

class _EventoLoteFormPageState extends State<EventoLoteFormPage> {
  final _repo = EventoLoteRepository();
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _fim = TextEditingController();
  final Map<int, TextEditingController> _quantidades = {};
  final Map<int, TextEditingController> _inteiras = {};
  final Map<int, bool> _venderNesteLote = {};
  List<ModalidadeIngressoCatalogo> _modalidades = [];
  bool _carregandoModalidades = true;
  DateTime? _fimSelecionado;
  bool _salvando = false;

  bool get _editando => widget.loteGlobal != null;
  int get _numero => widget.loteGlobal?.numero ?? widget.proximoNumeroLote;

  @override
  void initState() {
    super.initState();
    _carregarModalidades();
    final lote = widget.loteGlobal;
    _nome.text = lote?.nome ?? 'Lote $_numero';
    _fimSelecionado = DateTime.tryParse(lote?.fimVendas ?? '');
    if (_fimSelecionado != null) _fim.text = _br(_fimSelecionado!);
    for (final setor in widget.setores) {
      final configuracao = lote?.setores
          .where((item) => item.eventoSetorId == setor.id)
          .firstOrNull;
      _venderNesteLote[setor.id] = _editando ? configuracao != null : true;
      _quantidades[setor.id] = TextEditingController(
        text:
            configuracao?.qttotallote?.toString() ??
            setor.capacidade.toString(),
      );
      final inteira = configuracao?.precos
          .where((preco) => preco.tipo == 'INTEIRA')
          .firstOrNull;
      _inteiras[setor.id] = TextEditingController(
        text: (inteira?.valor ?? 0).toStringAsFixed(2).replaceAll('.', ','),
      );
    }
  }

  Future<void> _carregarModalidades() async {
    try {
      final itens = await _repo.listarModalidadesDoEvento(widget.eventoId);
      if (mounted) setState(() => _modalidades = itens);
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoModalidades = false);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _fim.dispose();
    for (final controller in _quantidades.values) {
      controller.dispose();
    }
    for (final controller in _inteiras.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _br(DateTime data) => DateFormat("dd/MM/yyyy 'às' HH:mm").format(data);
  String _api(DateTime data) =>
      DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(data);

  Future<DateTime?> _selecionar(DateTime? atual) async {
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: atual == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(atual),
    );
    if (hora == null) return null;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  Future<void> _selecionarFim() async {
    final data = await _selecionar(_fimSelecionado);
    if (data == null || !mounted) return;
    final inicioEvento = DateTime.tryParse(widget.eventoInicio ?? '');
    if (inicioEvento != null && data.isAfter(inicioEvento)) {
      AppSnackBar.aviso(
        context,
        'A data limite deste preço não pode ser posterior ao início do evento.',
      );
      return;
    }
    if (mounted) {
      setState(() {
        _fimSelecionado = data;
        _fim.text = _br(data);
      });
    }
  }

  double _valor(TextEditingController controller) =>
      double.tryParse(
        controller.text.replaceAll('.', '').replaceAll(',', '.'),
      ) ??
      0;

  void _selecionarZero(TextEditingController controller) {
    if (_valor(controller) != 0) return;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  List<Map<String, dynamic>> _setoresPayload() => widget.setores
      .where((setor) => _venderNesteLote[setor.id] ?? false)
      .map((setor) {
        final inteira = _valor(_inteiras[setor.id]!);
        final modalidadesPadrao = _modalidades
            .where((item) => item.tipo == 'PADRAO' || item.tipo == 'LEGAL')
            .toList();
        return {
          'eventosetor_id': setor.id,
          'qtlimite': int.tryParse(_quantidades[setor.id]!.text.trim()),
          'precos': modalidadesPadrao
              .map(
                (item) => {
                  'modalidade_id': item.id,
                  'nmpreco': item.nome,
                  'tipopreco': item.codigo,
                  'vrpreco': item.tipo == 'LEGAL' ? inteira / 2 : inteira,
                  'nrordem': item.ordem,
                },
              )
              .toList(),
        };
      })
      .toList();

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_carregandoModalidades || _modalidades.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Aguarde o carregamento do catálogo de modalidades.',
      );
      return;
    }
    final setoresSelecionados = _setoresPayload();
    if (!_editando && setoresSelecionados.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Selecione pelo menos um setor para vender neste lote.',
      );
      return;
    }
    if (!_editando &&
        setoresSelecionados.any(
          (setor) => ((setor['precos'] as List).first['vrpreco'] as double) < 0,
        )) {
      AppSnackBar.aviso(context, 'Informe um preço válido para cada setor.');
      return;
    }
    setState(() => _salvando = true);
    try {
      if (_editando) {
        await _repo.atualizarGlobal(
          loteGlobalId: widget.loteGlobal!.id,
          nome: _nome.text.trim(),
          inicioVendas: null,
          fimVendas: _fimSelecionado == null ? null : _api(_fimSelecionado!),
          gatilhoVirada: 'HIBRIDO',
        );
      } else {
        await _repo.criarGlobal(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          nome: _nome.text.trim(),
          inicioVendas: null,
          fimVendas: _fimSelecionado == null ? null : _api(_fimSelecionado!),
          gatilhoVirada: 'HIBRIDO',
          setores: setoresSelecionados,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: _editando ? 'Editar Lote $_numero' : 'Novo Lote $_numero',
          subtitulo: widget.eventoTitulo,
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClubbarCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etapa global de vendas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'O lote define o preço. Cada setor mantém sua própria capacidade e nunca compartilha ingressos com outro setor.',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nome,
                        decoration: const InputDecoration(
                          labelText: 'Nome do lote',
                        ),
                        validator: (valor) =>
                            valor == null || valor.trim().isEmpty
                            ? 'Informe o nome do lote'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.auto_mode_rounded),
                        title: Text('Início automático'),
                        subtitle: Text(
                          'O Lote 1 começa com a publicação. Os próximos começam quando a quantidade do anterior for atingida, na data limite ou por mudança manual.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fim,
                        readOnly: true,
                        onTap: _selecionarFim,
                        decoration: const InputDecoration(
                          labelText: 'Data limite deste preço (opcional)',
                          helperText:
                              'Sem data, a mudança pode ser feita pela quantidade ou manualmente. O último lote pode ficar sem os dois.',
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      if (_fimSelecionado != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _fimSelecionado = null;
                              _fim.clear();
                            }),
                            icon: const Icon(Icons.clear_rounded),
                            label: const Text('Remover data limite'),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_editando) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Configuração deste lote por setor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Informe a quantidade máxima de cada setor neste lote. A sobra só poderá seguir para o próximo lote do mesmo setor.',
                  ),
                  const SizedBox(height: 10),
                  ...widget.setores.map(
                    (setor) => ClubbarCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            setor.nome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Capacidade total do setor: ${setor.capacidade} pessoas',
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _venderNesteLote[setor.id] ?? false,
                            onChanged: (valor) => setState(
                              () => _venderNesteLote[setor.id] = valor ?? false,
                            ),
                            title: const Text('Vender neste lote'),
                          ),
                          if (_venderNesteLote[setor.id] ?? false) ...[
                            TextFormField(
                              controller: _quantidades[setor.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Quantidade máxima neste lote',
                                helperText:
                                    'Capacidade do setor: ${setor.capacidade} pessoas.',
                              ),
                              validator: (valor) {
                                final texto = valor?.trim() ?? '';
                                if (texto.isEmpty) {
                                  return 'Informe a quantidade deste lote';
                                }
                                final quantidade = int.tryParse(texto) ?? 0;
                                if (quantidade <= 0) {
                                  return 'Informe uma quantidade válida';
                                }
                                if (quantidade > setor.capacidade) {
                                  return 'A quantidade não pode superar a capacidade do setor';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _inteiras[setor.id],
                              onTap: () =>
                                  _selecionarZero(_inteiras[setor.id]!),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Preço da inteira',
                              ),
                              validator: (valor) =>
                                  _valor(_inteiras[setor.id]!) < 0
                                  ? 'Preço inválido'
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'A inteira cria automaticamente Meia-entrada e Pessoa idosa a 50%.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Este setor ficará indisponível para venda neste lote.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: ClubbarActionBar(
      actions: [
        FilledButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Salvar faixa de preço'),
        ),
      ],
    ),
  );
}
