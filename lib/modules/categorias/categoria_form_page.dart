import 'package:flutter/material.dart';

import '../../core/repositories/categoria_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/categoria.dart';

class CategoriaFormPage extends StatefulWidget {
  final Categoria? categoria;
  final int lojaId;

  const CategoriaFormPage({
    super.key,
    this.categoria,
    required this.lojaId,
  });

  @override
  State<CategoriaFormPage> createState() => _CategoriaFormPageState();
}

class _CategoriaFormPageState extends State<CategoriaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _ordemController = TextEditingController();
  final _repository = CategoriaRepository();

  bool _salvando = false;
  String _sitcategoria = 'ATIVA';

  bool get editando => widget.categoria != null;

  @override
  void initState() {
    super.initState();

    final categoria = widget.categoria;

    if (categoria != null) {
      _nomeController.text = categoria.nmcategoria;
      _sitcategoria = categoria.sitcategoria ?? 'ATIVA';
      _ordemController.text = (categoria.idordcategoria ?? 1).toString();
    } else {
      _ordemController.text = '1';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();

    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icone,
        color: ClubbarColors.textoSecundario,
      ),
      filled: true,
      fillColor: ClubbarColors.branco,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: ClubbarColors.ambar,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: ClubbarColors.erro,
          width: 2,
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
    });

    try {
      final nome = _nomeController.text.trim();
      final ordem = int.parse(_ordemController.text.trim());

      if (editando) {
        await _repository.atualizar(
          widget.lojaId,
          widget.categoria!.categoriaId,
          nome,
          _sitcategoria,
          ordem,
        );
      } else {
        await _repository.criar(
          widget.lojaId,
          nome,
          _sitcategoria,
          ordem,
        );
      }

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        editando
            ? 'Categoria alterada com sucesso.'
            : 'Categoria criada com sucesso.',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        _mensagemErro(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Widget _cabecalhoFormulario() {
    return ClubbarCard(
      elevation: 1,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: ClubbarColors.ambarClaro,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_rounded,
              size: 30,
              color: ClubbarColors.preto,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editando
                      ? 'Dados da categoria'
                      : 'Nova categoria',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  editando
                      ? 'Atualize o nome, a ordem e a situação.'
                      : 'Cadastre uma categoria para organizar o cardápio.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
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

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Nome da categoria',
              icone: Icons.label_outline_rounded,
              hint: 'Ex.: Drinks',
            ),
            validator: (value) {
              final texto = value?.trim() ?? '';

              if (texto.isEmpty) {
                return 'Informe o nome da categoria';
              }

              if (texto.length < 2) {
                return 'Nome muito curto';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ordemController,
            keyboardType: TextInputType.number,
            decoration: _decoracaoCampo(
              label: 'Ordem no cardápio',
              icone: Icons.format_list_numbered_rounded,
              hint: 'Ex.: 1',
            ),
            validator: (value) {
              final texto = value?.trim() ?? '';

              if (texto.isEmpty) {
                return 'Informe a ordem no cardápio';
              }

              final numero = int.tryParse(texto);

              if (numero == null) {
                return 'Informe um número válido';
              }

              if (numero <= 0) {
                return 'A ordem deve ser maior que zero';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _sitcategoria,
            decoration: _decoracaoCampo(
              label: 'Status',
              icone: Icons.toggle_on_outlined,
            ),
            items: const [
              DropdownMenuItem(
                value: 'ATIVA',
                child: Text('Ativa'),
              ),
              DropdownMenuItem(
                value: 'INATIVA',
                child: Text('Inativa'),
              ),
            ],
            onChanged: _salvando
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _sitcategoria = value;
                    });
                  },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ClubbarColors.preto,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _salvando
                    ? 'Salvando...'
                    : editando
                        ? 'Salvar alterações'
                        : 'Cadastrar categoria',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
                disabledBackgroundColor: ClubbarColors.ambarClaro,
                disabledForegroundColor: ClubbarColors.textoSecundario,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(
        mostrarVoltar: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: editando
                  ? 'Editar Categoria'
                  : 'Nova Categoria',
              subtitulo: editando
                  ? 'Atualize os dados da categoria'
                  : 'Organize os produtos do cardápio',
              icone: Icons.category_rounded,
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  30,
                ),
                children: [
                  _cabecalhoFormulario(),
                  const SizedBox(height: 18),
                  ClubbarCard(
                    elevation: 1,
                    padding: const EdgeInsets.all(18),
                    child: _formulario(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
