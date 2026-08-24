import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

enum LojaConfiguracaoTipo { politicaProdutos, cashback }

class LojaConfiguracaoProdutosPage extends StatefulWidget {
  final Loja loja;
  final LojaConfiguracaoTipo tipo;

  const LojaConfiguracaoProdutosPage({
    super.key,
    required this.loja,
    required this.tipo,
  });

  @override
  State<LojaConfiguracaoProdutosPage> createState() =>
      _LojaConfiguracaoProdutosPageState();
}

class _LojaConfiguracaoProdutosPageState
    extends State<LojaConfiguracaoProdutosPage> {
  final _repository = LojaRepository();
  final _valorController = TextEditingController();
  final _minimoCompraController = TextEditingController();
  final _maximoCashbackController = TextEditingController();
  final _diasLiberacaoController = TextEditingController();
  final _diasValidadeController = TextEditingController();
  final _maximoUsoController = TextEditingController();
  bool _ativo = false;
  bool _permiteUsoParcial = true;
  bool _carregando = false;
  bool _salvando = false;

  bool get _cashback => widget.tipo == LojaConfiguracaoTipo.cashback;

  @override
  void initState() {
    super.initState();
    _ativo = _cashback
        ? widget.loja.usacashback == 'S'
        : widget.loja.idvalidadeprod == 'S';
    _valorController.text = _cashback
        ? widget.loja.pccashback.toStringAsFixed(2).replaceAll('.', ',')
        : '${widget.loja.nrdiavalidade ?? 90}';
    if (_cashback) _carregarCashback();
  }

  Future<void> _carregarCashback() async {
    setState(() => _carregando = true);
    try {
      final config = await _repository.buscarConfigCashback(widget.loja.lojaId);
      if (!mounted) return;
      setState(() {
        _ativo = config['sitcashback'] == 'ATIVO';
        _valorController.text = _decimal(config['pccashback']);
        _minimoCompraController.text = _decimal(config['vrmincompra']);
        _maximoCashbackController.text = config['vrmaxcashback'] == null
            ? ''
            : _decimal(config['vrmaxcashback']);
        _diasLiberacaoController.text = '${config['nrdiapliberacao'] ?? 7}';
        _diasValidadeController.text = '${config['nrdiavalidade'] ?? 90}';
        _permiteUsoParcial = config['permiteusoparcial'] != 'N';
        _maximoUsoController.text = _decimal(config['pcmaxusocompra'] ?? 30);
      });
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _decimal(dynamic valor) =>
      (double.tryParse('$valor') ?? 0).toStringAsFixed(2).replaceAll('.', ',');

  double? _numero(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _valorController.dispose();
    _minimoCompraController.dispose();
    _maximoCashbackController.dispose();
    _diasLiberacaoController.dispose();
    _diasValidadeController.dispose();
    _maximoUsoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = _numero(_valorController);
    if (_ativo && (valor == null || valor <= 0 || (_cashback && valor > 100))) {
      AppSnackBar.aviso(
        context,
        _cashback
            ? 'Informe um percentual entre 0,01% e 100%.'
            : 'Informe uma quantidade válida de dias.',
      );
      return;
    }

    if (_cashback) {
      final minimo = _numero(_minimoCompraController);
      final maximo = _maximoCashbackController.text.trim().isEmpty
          ? null
          : _numero(_maximoCashbackController);
      final liberacao = int.tryParse(_diasLiberacaoController.text.trim());
      final validade = int.tryParse(_diasValidadeController.text.trim());
      final maximoUso = _numero(_maximoUsoController);
      if (minimo == null || minimo < 0 || (maximo != null && maximo < 0)) {
        AppSnackBar.aviso(context, 'Confira os valores mínimos e máximos.');
        return;
      }
      if (liberacao == null ||
          liberacao < 0 ||
          validade == null ||
          validade < 1) {
        AppSnackBar.aviso(
          context,
          'Confira os prazos de liberação e validade.',
        );
        return;
      }
      if (maximoUso == null || maximoUso <= 0 || maximoUso > 100) {
        AppSnackBar.aviso(
          context,
          'O limite de uso deve estar entre 0,01% e 100%.',
        );
        return;
      }
    }

    setState(() => _salvando = true);
    try {
      if (_cashback) {
        await _repository.salvarConfigCashback(
          lojaId: widget.loja.lojaId,
          configuracao: {
            'sitcashback': _ativo ? 'ATIVO' : 'INATIVO',
            'pccashback': valor ?? 0,
            'vrmincompra': _numero(_minimoCompraController) ?? 0,
            'vrmaxcashback': _maximoCashbackController.text.trim().isEmpty
                ? null
                : _numero(_maximoCashbackController),
            'nrdiapliberacao': int.parse(_diasLiberacaoController.text.trim()),
            'nrdiavalidade': int.parse(_diasValidadeController.text.trim()),
            'permiteusoparcial': _permiteUsoParcial ? 'S' : 'N',
            'pcmaxusocompra': _numero(_maximoUsoController) ?? 30,
          },
        );
      } else {
        await _repository.atualizarPoliticaProdutos(
          loja: widget.loja,
          controlaValidade: _ativo ? 'S' : 'N',
          diasValidade: _ativo ? valor!.round() : widget.loja.nrdiavalidade,
        );
      }
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Configuração salva com sucesso.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _cashback ? 'Gerenciar cashback' : 'Política de produtos';
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _cashback ? widget.loja.nmloja : titulo,
            subtitulo: _cashback ? titulo : widget.loja.nmloja,
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _ativo,
                                onChanged: _salvando
                                    ? null
                                    : (valor) => setState(() => _ativo = valor),
                                title: Text(
                                  _cashback
                                      ? 'Usar cashback nesta loja'
                                      : 'Controlar validade dos produtos',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _valorController,
                                enabled: _ativo && !_salvando,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: _cashback
                                      ? 'Percentual de cashback'
                                      : 'Prazo de validade em dias',
                                  suffixText: _cashback ? '%' : 'dias',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              if (_cashback) ...[
                                const Divider(height: 30),
                                _campoNumero(
                                  controller: _minimoCompraController,
                                  label: 'Valor mínimo da compra',
                                  prefixo: 'R\$',
                                  ajuda: 'Compra mínima para gerar cashback.',
                                ),
                                const SizedBox(height: 14),
                                _campoNumero(
                                  controller: _maximoCashbackController,
                                  label: 'Valor máximo de cashback',
                                  prefixo: 'R\$',
                                  ajuda:
                                      'Deixe vazio para não limitar o crédito.',
                                ),
                                const SizedBox(height: 14),
                                _campoNumero(
                                  controller: _diasLiberacaoController,
                                  label: 'Dias para liberação',
                                  sufixo: 'dias',
                                  decimal: false,
                                  ajuda:
                                      'Período em que o crédito ficará pendente.',
                                ),
                                const SizedBox(height: 14),
                                _campoNumero(
                                  controller: _diasValidadeController,
                                  label: 'Validade do cashback',
                                  sufixo: 'dias',
                                  decimal: false,
                                ),
                                const SizedBox(height: 10),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _permiteUsoParcial,
                                  onChanged: _salvando
                                      ? null
                                      : (valor) => setState(
                                          () => _permiteUsoParcial = valor,
                                        ),
                                  title: const Text(
                                    'Permitir uso parcial do saldo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'O cliente pode usar apenas parte do cashback disponível.',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _campoNumero(
                                  controller: _maximoUsoController,
                                  label: 'Limite de uso por compra',
                                  sufixo: '%',
                                  ajuda:
                                      'Percentual máximo da compra que pode ser pago com cashback.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_salvando ? 'Salvando...' : 'Salvar'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _campoNumero({
    required TextEditingController controller,
    required String label,
    String? prefixo,
    String? sufixo,
    String? ajuda,
    bool decimal = true,
  }) {
    return TextField(
      controller: controller,
      enabled: !_salvando,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixo,
        suffixText: sufixo,
        helperText: ajuda,
        helperMaxLines: 2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
