import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento_lote.dart';

class EventoLoteFormPage extends StatefulWidget {
  final int eventoId;
  final int organizacaoId;
  final int lojaId;
  final String? eventoInicio;
  final EventoLote? lote;

  const EventoLoteFormPage({
    super.key,
    required this.eventoId,
    required this.organizacaoId,
    required this.lojaId,
    this.eventoInicio,
    this.lote,
  });

  @override
  State<EventoLoteFormPage> createState() => _EventoLoteFormPageState();
}

class _EventoLoteFormPageState extends State<EventoLoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final EventoLoteRepository _repo = EventoLoteRepository();

  final _nomeController = TextEditingController();
  final _precoController = TextEditingController();
  final _qtTotalController = TextEditingController();
  final _qtVendidaController = TextEditingController();
  final _dtInicioController = TextEditingController();
  final _dtFimController = TextEditingController();
  final _numeroLoteController = TextEditingController(text: '1');

  bool _salvando = false;
  String _status = 'ATIVO';
  DateTime? _dataInicioSelecionada;
  DateTime? _dataFimSelecionada;
  bool _modoSimples = false;
  List<EventoSetor> _setores = [];
  int? _setorId;
  String _tipoIngresso = 'INTEIRA';
  bool _usarCapacidadeRestante = false;

  bool get editando => widget.lote != null;
  int get _quantidadeTotal => int.tryParse(_qtTotalController.text.trim()) ?? 0;
  int get _quantidadeVendida =>
      int.tryParse(_qtVendidaController.text.trim()) ?? 0;
  int get _quantidadeDisponivel =>
      (_quantidadeTotal - _quantidadeVendida).clamp(0, _quantidadeTotal);
  double get _preco =>
      double.tryParse(
        _precoController.text
            .replaceAll('R\$', '')
            .replaceAll(' ', '')
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .trim(),
      ) ??
      0;

  @override
  void initState() {
    super.initState();
    _precoController.addListener(_atualizarResumo);
    _qtTotalController.addListener(_atualizarResumo);

    final lote = widget.lote;
    if (lote != null) {
      _nomeController.text = lote.nmlote;
      _precoController.text = lote.vrprecolote.toString();
      _qtTotalController.text = lote.qttotallote.toString();
      _qtVendidaController.text = lote.qtvendidalote.toString();
      _status = lote.statuslote ?? 'ATIVO';
      _modoSimples = lote.eventoSetorId == null && lote.tipoIngresso == 'UNICO';
      _setorId = lote.eventoSetorId;
      _numeroLoteController.text = lote.numeroLote.toString();
      _tipoIngresso = lote.tipoIngresso == 'UNICO'
          ? 'INTEIRA'
          : lote.tipoIngresso;
      _usarCapacidadeRestante = lote.usarCapacidadeRestante;
      _preencherData(lote.dtiniciovenda, _dtInicioController, inicio: true);
      _preencherData(lote.dtfimvenda, _dtFimController, inicio: false);
    } else {
      _qtVendidaController.text = '0';
    }
    _carregarSetores();
  }

  @override
  void dispose() {
    _precoController.removeListener(_atualizarResumo);
    _qtTotalController.removeListener(_atualizarResumo);
    _nomeController.dispose();
    _precoController.dispose();
    _qtTotalController.dispose();
    _qtVendidaController.dispose();
    _dtInicioController.dispose();
    _dtFimController.dispose();
    _numeroLoteController.dispose();
    super.dispose();
  }

  Future<void> _carregarSetores() async {
    try {
      final setores = await _repo.listarSetores(widget.eventoId);
      if (mounted) {
        setState(
          () => _setores = setores.where((e) => e.situacao == 'ATIVO').toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _novoSetor() async {
    final nome = TextEditingController();
    final capacidade = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Novo setor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome do setor'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacidade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacidade'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nome.dispose();
      capacidade.dispose();
      return;
    }
    try {
      final setor = await _repo.criarSetor(
        eventoId: widget.eventoId,
        nome: nome.text.trim(),
        capacidade: int.tryParse(capacidade.text) ?? 0,
      );
      if (mounted) {
        setState(() {
          _setores.add(setor);
          _setorId = setor.id;
        });
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, _mensagemErro(e));
    }
    nome.dispose();
    capacidade.dispose();
  }

  void _atualizarResumo() {
    if (mounted) setState(() {});
  }

  void _preencherData(
    String? valor,
    TextEditingController controller, {
    required bool inicio,
  }) {
    if (valor == null || valor.trim().isEmpty) return;
    final data = DateTime.tryParse(valor);
    if (data == null) {
      controller.text = valor;
      return;
    }
    controller.text = DateFormat('dd/MM/yyyy HH:mm').format(data);
    if (inicio) {
      _dataInicioSelecionada = data;
    } else {
      _dataFimSelecionada = data;
    }
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  String? _dataParaApi(DateTime? data) {
    if (data == null) return null;
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(data);
  }

  Future<DateTime?> _selecionarDataHora(DateTime? atual) async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? agora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return null;

    final hora = await showTimePicker(
      context: context,
      initialTime: atual != null
          ? TimeOfDay.fromDateTime(atual)
          : TimeOfDay.now(),
    );
    if (hora == null) return null;

    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  Future<void> _selecionarInicio() async {
    final data = await _selecionarDataHora(_dataInicioSelecionada);
    if (data == null || !mounted) return;
    setState(() {
      _dataInicioSelecionada = data;
      _dtInicioController.text = DateFormat('dd/MM/yyyy HH:mm').format(data);
    });
  }

  Future<void> _selecionarFim() async {
    final data = await _selecionarDataHora(
      _dataFimSelecionada ?? _dataInicioSelecionada,
    );
    if (data == null || !mounted) return;
    setState(() {
      _dataFimSelecionada = data;
      _dtFimController.text = DateFormat('dd/MM/yyyy HH:mm').format(data);
    });
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone, color: ClubbarColors.textoSecundario),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ClubbarColors.branco,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
      ),
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_modoSimples && _setorId == null) {
      AppSnackBar.aviso(context, 'Selecione o setor do ingresso.');
      return;
    }

    if (!_usarCapacidadeRestante && _quantidadeVendida > _quantidadeTotal) {
      AppSnackBar.aviso(
        context,
        'A quantidade vendida não pode ser maior que a quantidade total.',
      );
      return;
    }

    if (_dataInicioSelecionada != null &&
        _dataFimSelecionada != null &&
        !_dataFimSelecionada!.isAfter(_dataInicioSelecionada!)) {
      AppSnackBar.aviso(
        context,
        'A data final de venda deve ser posterior à data inicial.',
      );
      return;
    }

    final inicioEvento = DateTime.tryParse(widget.eventoInicio ?? '');
    if (inicioEvento != null) {
      if (_dataInicioSelecionada != null &&
          !_dataInicioSelecionada!.isBefore(inicioEvento)) {
        AppSnackBar.aviso(
          context,
          'O início das vendas deve acontecer antes do início do evento.',
        );
        return;
      }
      if (_dataFimSelecionada == null) {
        AppSnackBar.aviso(context, 'Informe o fim das vendas.');
        return;
      }
    }
    setState(() => _salvando = true);

    try {
      final numeroLote = _modoSimples
          ? 1
          : int.parse(_numeroLoteController.text);
      final tipoIngresso = _modoSimples ? 'UNICO' : _tipoIngresso;
      final setor = _setores.where((e) => e.id == _setorId).firstOrNull;
      final nomeTipo = _nomeTipo(tipoIngresso) == 'Meia'
          ? 'Meia Entrada'
          : _nomeTipo(tipoIngresso);
      final nomeLote = _modoSimples
          ? 'Ingresso único'
          : 'Lote $numeroLote - ${setor!.nome} $nomeTipo';
      if (editando) {
        await _repo.atualizar(
          loteId: widget.lote!.loteId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          eventoId: widget.eventoId,
          nome: nomeLote,
          eventoSetorId: _modoSimples ? null : _setorId,
          numeroLote: numeroLote,
          tipoIngresso: tipoIngresso,
          preco: _preco,
          quantidadeTotal: _quantidadeTotal,
          quantidadeVendida: _quantidadeVendida,
          usarCapacidadeRestante: _usarCapacidadeRestante,
          dtInicioVenda: _dataParaApi(_dataInicioSelecionada),
          dtFimVenda: _dataParaApi(_dataFimSelecionada),
          status: _status,
        );
      } else {
        await _repo.criar(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          nome: nomeLote,
          eventoSetorId: _modoSimples ? null : _setorId,
          numeroLote: numeroLote,
          tipoIngresso: tipoIngresso,
          preco: _preco,
          quantidadeTotal: _quantidadeTotal,
          quantidadeVendida: 0,
          usarCapacidadeRestante: _usarCapacidadeRestante,
          dtInicioVenda: _dataParaApi(_dataInicioSelecionada),
          dtFimVenda: _dataParaApi(_dataFimSelecionada),
          status: _status,
        );
      }

      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        editando ? 'Lote atualizado com sucesso.' : 'Lote criado com sucesso.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _nomeTipo(String tipo) =>
      {
        'INTEIRA': 'Inteira',
        'MEIA': 'Meia',
        'SOCIAL': 'Social',
        'CORTESIA': 'Cortesia',
        'OUTRO': 'Outro',
      }[tipo] ??
      tipo;

  Widget _cardCabecalho() {
    return ClubbarCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: ClubbarColors.ambarClaro,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.confirmation_number_rounded, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editando ? 'Dados do lote' : 'Novo lote',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  editando
                      ? 'Atualize preço, quantidade e período de vendas.'
                      : 'Defina o preço e a quantidade de ingressos.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFormulario() {
    return ClubbarCard(
      child: Column(
        children: [
          if (editando && _modoSimples) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClubbarColors.ambarClaro,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'Este ingresso foi criado no formato antigo. Converta-o '
                    'para informar setor e tipo de ingresso.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _quantidadeVendida > 0
                        ? null
                        : () => setState(() => _modoSimples = false),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Converter ingresso'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (!_modoSimples) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _setorId,
                    decoration: _decoracaoCampo(
                      label: 'Setor',
                      icone: Icons.chair_alt_outlined,
                    ),
                    items: _setores
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.nome} (${s.capacidade})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _setorId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _novoSetor,
                  tooltip: 'Novo setor',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _numeroLoteController,
                    keyboardType: TextInputType.number,
                    decoration: _decoracaoCampo(
                      label: 'Número do lote',
                      icone: Icons.numbers,
                    ),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                        ? 'Informe o lote'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tipoIngresso,
                    decoration: _decoracaoCampo(
                      label: 'Tipo',
                      icone: Icons.badge_outlined,
                    ),
                    items: ['INTEIRA', 'MEIA', 'SOCIAL', 'CORTESIA', 'OUTRO']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(_nomeTipo(v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _tipoIngresso = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _precoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoracaoCampo(
              label: 'Preço',
              icone: Icons.attach_money_rounded,
              hint: '0,00',
            ),
            validator: (value) => _preco < 0 ? 'Informe um preço válido' : null,
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar a capacidade restante'),
            subtitle: const Text(
              'Recomendado para o último lote. O sistema calcula automaticamente os lugares restantes.',
            ),
            value: _usarCapacidadeRestante,
            onChanged: (valor) =>
                setState(() => _usarCapacidadeRestante = valor),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _qtTotalController,
            enabled: !_usarCapacidadeRestante,
            keyboardType: TextInputType.number,
            decoration: _decoracaoCampo(
              label: 'Quantidade total',
              icone: Icons.groups_outlined,
              hint: 'Ex.: 500',
            ),
            validator: (value) {
              if (_usarCapacidadeRestante) return null;
              final quantidade = int.tryParse(value?.trim() ?? '');
              if (quantidade == null || quantidade <= 0) {
                return 'Informe uma quantidade maior que zero';
              }
              if (editando && quantidade < _quantidadeVendida) {
                return 'Não pode ser menor que a quantidade vendida';
              }
              return null;
            },
          ),
          if (editando) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _qtVendidaController,
              readOnly: true,
              decoration: _decoracaoCampo(
                label: 'Quantidade vendida',
                icone: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _dtInicioController,
            readOnly: true,
            onTap: _selecionarInicio,
            decoration: _decoracaoCampo(
              label: 'Início das vendas',
              icone: Icons.calendar_month_outlined,
              hint: 'dd/mm/aaaa hh:mm',
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dtFimController,
            readOnly: true,
            onTap: _selecionarFim,
            decoration: _decoracaoCampo(
              label: 'Fim das vendas',
              icone: Icons.event_available_outlined,
              hint: 'dd/mm/aaaa hh:mm',
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: _decoracaoCampo(
              label: 'Status',
              icone: Icons.toggle_on_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'ATIVO', child: Text('Ativo')),
              DropdownMenuItem(value: 'INATIVO', child: Text('Inativo')),
            ],
            onChanged: _salvando
                ? null
                : (value) => setState(() => _status = value ?? 'ATIVO'),
          ),
        ],
      ),
    );
  }

  Widget _linhaResumo(String titulo, String valor, {bool destaque = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontWeight: destaque ? FontWeight.w900 : FontWeight.w600,
              color: ClubbarColors.textoSecundario,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: destaque ? 21 : 15,
            fontWeight: FontWeight.w900,
            color: destaque
                ? ClubbarColors.sucesso
                : ClubbarColors.textoPrincipal,
          ),
        ),
      ],
    );
  }

  Widget _cardResumo() {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return ClubbarCard(
      backgroundColor: ClubbarColors.avisoClaro,
      borderColor: ClubbarColors.ambar,
      child: Column(
        children: [
          _linhaResumo('Preço', moeda.format(_preco)),
          const SizedBox(height: 10),
          _linhaResumo('Quantidade total', '$_quantidadeTotal'),
          const SizedBox(height: 10),
          _linhaResumo('Vendidos', '$_quantidadeVendida'),
          const Divider(height: 26),
          _linhaResumo('Disponíveis', '$_quantidadeDisponivel', destaque: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: editando ? 'Editar Lote' : 'Novo Lote',
              subtitulo: editando
                  ? 'Atualize as condições de venda'
                  : 'Defina preço, quantidade e período',
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    _cardCabecalho(),
                    const SizedBox(height: 16),
                    _cardFormulario(),
                    const SizedBox(height: 16),
                    _cardResumo(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _salvando
                              ? 'Salvando...'
                              : editando
                              ? 'Salvar alterações'
                              : 'Cadastrar lote',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClubbarColors.ambar,
                          foregroundColor: ClubbarColors.preto,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
