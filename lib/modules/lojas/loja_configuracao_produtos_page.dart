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
  bool _ativo = false;
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
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    if (_ativo && (valor == null || valor <= 0 || (_cashback && valor > 100))) {
      AppSnackBar.aviso(
        context,
        _cashback
            ? 'Informe um percentual entre 0,01% e 100%.'
            : 'Informe uma quantidade válida de dias.',
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      if (_cashback) {
        await _repository.atualizarCashback(
          loja: widget.loja,
          ativo: _ativo,
          percentual: valor ?? 0,
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
          ClubbarPageHeader(titulo: titulo, subtitulo: widget.loja.nmloja),
          Expanded(
            child: ListView(
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _valorController,
                          enabled: _ativo && !_salvando,
                          keyboardType: const TextInputType.numberWithOptions(
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
}
