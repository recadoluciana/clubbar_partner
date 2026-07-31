import 'package:flutter/material.dart';

import '../../models/cidade.dart';
import '../../models/estado.dart';
import '../repositories/localidade_repository.dart';
import '../theme/clubbar_colors.dart';

typedef LocalidadeChanged = void Function(Estado? estado, Cidade? cidade);

class ClubbarLocalidadeField extends StatefulWidget {
  final int? estadoInicialId;
  final int? cidadeInicialId;

  final bool obrigatorio;
  final bool habilitado;

  final LocalidadeChanged onChanged;

  const ClubbarLocalidadeField({
    super.key,
    this.estadoInicialId,
    this.cidadeInicialId,
    this.obrigatorio = true,
    this.habilitado = true,
    required this.onChanged,
  });

  @override
  State<ClubbarLocalidadeField> createState() => _ClubbarLocalidadeFieldState();
}

class _ClubbarLocalidadeFieldState extends State<ClubbarLocalidadeField> {
  final LocalidadeRepository _repository = LocalidadeRepository();

  final TextEditingController _estadoController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();

  final FocusNode _estadoFocusNode = FocusNode();
  final FocusNode _cidadeFocusNode = FocusNode();

  List<Estado> _estados = [];
  List<Cidade> _cidades = [];

  Estado? _estadoSelecionado;
  Cidade? _cidadeSelecionada;

  bool _carregandoEstados = true;
  bool _carregandoCidades = false;

  String? _erroEstados;
  String? _erroCidades;

  @override
  void initState() {
    super.initState();
    _carregarEstados();
  }

  @override
  void didUpdateWidget(covariant ClubbarLocalidadeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final alterouEstado = oldWidget.estadoInicialId != widget.estadoInicialId;

    final alterouCidade = oldWidget.cidadeInicialId != widget.cidadeInicialId;

    if (alterouEstado || alterouCidade) {
      _carregarSelecaoInicial();
    }
  }

  @override
  void dispose() {
    _estadoController.dispose();
    _cidadeController.dispose();

    _estadoFocusNode.dispose();
    _cidadeFocusNode.dispose();

    super.dispose();
  }

  Future<void> _carregarEstados() async {
    setState(() {
      _carregandoEstados = true;
      _erroEstados = null;
    });

    try {
      final estados = await _repository.listarEstados();

      if (!mounted) return;

      setState(() {
        _estados = estados;
        _carregandoEstados = false;
      });

      await _carregarSelecaoInicial();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregandoEstados = false;
        _erroEstados = _limparMensagemErro(e);
      });
    }
  }

  Future<void> _carregarSelecaoInicial() async {
    if (_estados.isEmpty) {
      return;
    }

    final estadoInicialId = widget.estadoInicialId;

    if (estadoInicialId == null || estadoInicialId <= 0) {
      _limparSelecao();
      return;
    }

    Estado? estadoInicial;

    for (final estado in _estados) {
      if (estado.estadoId == estadoInicialId) {
        estadoInicial = estado;
        break;
      }
    }

    if (estadoInicial == null) {
      _limparSelecao();
      return;
    }

    setState(() {
      _estadoSelecionado = estadoInicial;
      _estadoController.text = estadoInicial!.descricao;
      _cidadeSelecionada = null;
      _cidadeController.clear();
    });

    await _carregarCidades(
      estadoInicial.estadoId,
      cidadeInicialId: widget.cidadeInicialId,
      notificarAlteracao: false,
    );

    if (!mounted) return;

    widget.onChanged(_estadoSelecionado, _cidadeSelecionada);
  }

  void _limparSelecao() {
    if (!mounted) return;

    setState(() {
      _estadoSelecionado = null;
      _cidadeSelecionada = null;

      _estadoController.clear();
      _cidadeController.clear();

      _cidades = [];
      _erroCidades = null;
    });

    widget.onChanged(null, null);
  }

  Future<void> _selecionarEstado(Estado estado) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _estadoSelecionado = estado;
      _estadoController.text = estado.descricao;

      _cidadeSelecionada = null;
      _cidadeController.clear();

      _cidades = [];
      _erroCidades = null;
    });

    widget.onChanged(estado, null);

    await _carregarCidades(estado.estadoId, notificarAlteracao: true);
  }

  Future<void> _carregarCidades(
    int estadoId, {
    int? cidadeInicialId,
    required bool notificarAlteracao,
  }) async {
    setState(() {
      _carregandoCidades = true;
      _erroCidades = null;
      _cidades = [];
    });

    try {
      final cidades = await _repository.listarCidadesPorEstado(estadoId);

      if (!mounted) return;

      Cidade? cidadeInicial;

      if (cidadeInicialId != null && cidadeInicialId > 0) {
        for (final cidade in cidades) {
          if (cidade.cidadeId == cidadeInicialId) {
            cidadeInicial = cidade;
            break;
          }
        }
      }

      setState(() {
        _cidades = cidades;
        _cidadeSelecionada = cidadeInicial;
        _cidadeController.text = cidadeInicial?.nmcidade ?? '';
        _carregandoCidades = false;
      });

      if (notificarAlteracao) {
        widget.onChanged(_estadoSelecionado, _cidadeSelecionada);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregandoCidades = false;
        _erroCidades = _limparMensagemErro(e);
      });
    }
  }

  void _selecionarCidade(Cidade cidade) {
    FocusScope.of(context).unfocus();

    setState(() {
      _cidadeSelecionada = cidade;
      _cidadeController.text = cidade.nmcidade;
    });

    widget.onChanged(_estadoSelecionado, cidade);
  }

  void _validarTextoEstado() {
    final texto = _estadoController.text.trim();

    if (_estadoSelecionado == null) {
      return;
    }

    if (texto != _estadoSelecionado!.descricao) {
      setState(() {
        _estadoSelecionado = null;
        _cidadeSelecionada = null;

        _cidadeController.clear();
        _cidades = [];
      });

      widget.onChanged(null, null);
    }
  }

  void _validarTextoCidade() {
    final texto = _cidadeController.text.trim();

    if (_cidadeSelecionada == null) {
      return;
    }

    if (texto != _cidadeSelecionada!.nmcidade) {
      setState(() {
        _cidadeSelecionada = null;
      });

      widget.onChanged(_estadoSelecionado, null);
    }
  }

  String _limparMensagemErro(Object erro) {
    return erro.toString().replaceFirst('Exception: ', '').trim();
  }

  InputDecoration _decoracao({
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
      fillColor: widget.habilitado ? ClubbarColors.branco : ClubbarColors.fundo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
    );
  }

  String _normalizar(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  Iterable<Estado> _filtrarEstados(TextEditingValue valor) {
    final pesquisa = _normalizar(valor.text);

    if (pesquisa.isEmpty) {
      return _estados;
    }

    return _estados.where((estado) {
      final nome = _normalizar(estado.nmestado);
      final sigla = _normalizar(estado.sgestado);
      final descricao = _normalizar(estado.descricao);

      return nome.contains(pesquisa) ||
          sigla.contains(pesquisa) ||
          descricao.contains(pesquisa);
    });
  }

  Iterable<Cidade> _filtrarCidades(TextEditingValue valor) {
    final pesquisa = _normalizar(valor.text);

    if (pesquisa.isEmpty) {
      return _cidades;
    }

    return _cidades.where((cidade) {
      return _normalizar(cidade.nmcidade).contains(pesquisa);
    });
  }

  Widget _mensagemErro({
    required String mensagem,
    required VoidCallback onTentarNovamente,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubbarColors.erro.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubbarColors.erro.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: ClubbarColors.erro,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagem,
                  style: const TextStyle(
                    color: ClubbarColors.erro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onTentarNovamente,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _campoEstado() {
    if (_carregandoEstados) {
      return TextFormField(
        enabled: false,
        decoration: _decoracao(
          label: 'Estado',
          hint: 'Carregando estados...',
          icone: Icons.map_outlined,
          suffixIcon: const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_erroEstados != null) {
      return _mensagemErro(
        mensagem: _erroEstados!,
        onTentarNovamente: _carregarEstados,
      );
    }

    return FormField<Estado>(
      initialValue: _estadoSelecionado,
      validator: (_) {
        if (!widget.obrigatorio) {
          return null;
        }

        if (_estadoSelecionado == null) {
          return 'Selecione o estado.';
        }

        return null;
      },
      builder: (formField) {
        return RawAutocomplete<Estado>(
          textEditingController: _estadoController,
          focusNode: _estadoFocusNode,
          displayStringForOption: (estado) => estado.descricao,
          optionsBuilder: _filtrarEstados,
          onSelected: (estado) {
            formField.didChange(estado);
            _selecionarEstado(estado);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.habilitado,
              textCapitalization: TextCapitalization.words,
              decoration: _decoracao(
                label: 'Estado',
                hint: 'Digite o nome ou a sigla',
                icone: Icons.map_outlined,
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ).copyWith(errorText: formField.errorText),
              onChanged: (_) {
                _validarTextoEstado();
                formField.didChange(_estadoSelecionado);
              },
              onTap: () {
                if (!focusNode.hasFocus) {
                  focusNode.requestFocus();
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final lista = options.toList();

            if (lista.isEmpty) {
              return const SizedBox.shrink();
            }

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 520,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final estado = lista[index];

                      return ListTile(
                        leading: const Icon(Icons.map_outlined),
                        title: Text(estado.nmestado),
                        subtitle: Text(estado.sgestado),
                        onTap: () => onSelected(estado),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _campoCidade() {
    if (_estadoSelecionado == null) {
      return TextFormField(
        enabled: false,
        decoration: _decoracao(
          label: 'Cidade',
          hint: 'Selecione primeiro o estado',
          icone: Icons.location_city_outlined,
        ),
      );
    }

    if (_carregandoCidades) {
      return TextFormField(
        enabled: false,
        decoration: _decoracao(
          label: 'Cidade',
          hint: 'Carregando cidades...',
          icone: Icons.location_city_outlined,
          suffixIcon: const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_erroCidades != null) {
      return _mensagemErro(
        mensagem: _erroCidades!,
        onTentarNovamente: () {
          final estadoId = _estadoSelecionado?.estadoId;

          if (estadoId == null) {
            return;
          }

          _carregarCidades(estadoId, notificarAlteracao: true);
        },
      );
    }

    return FormField<Cidade>(
      initialValue: _cidadeSelecionada,
      validator: (_) {
        if (!widget.obrigatorio) {
          return null;
        }

        if (_cidadeSelecionada == null) {
          return 'Selecione a cidade.';
        }

        return null;
      },
      builder: (formField) {
        return RawAutocomplete<Cidade>(
          textEditingController: _cidadeController,
          focusNode: _cidadeFocusNode,
          displayStringForOption: (cidade) => cidade.nmcidade,
          optionsBuilder: _filtrarCidades,
          onSelected: (cidade) {
            formField.didChange(cidade);
            _selecionarCidade(cidade);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.habilitado,
              textCapitalization: TextCapitalization.words,
              decoration: _decoracao(
                label: 'Cidade',
                hint: 'Digite para pesquisar',
                icone: Icons.location_city_outlined,
                suffixIcon: const Icon(Icons.search_rounded),
              ).copyWith(errorText: formField.errorText),
              onChanged: (_) {
                _validarTextoCidade();
                formField.didChange(_cidadeSelecionada);
              },
              onTap: () {
                if (!focusNode.hasFocus) {
                  focusNode.requestFocus();
                }
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final lista = options.toList();

            if (lista.isEmpty) {
              return const SizedBox.shrink();
            }

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                    maxWidth: 520,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cidade = lista[index];

                      return ListTile(
                        leading: const Icon(Icons.location_city_outlined),
                        title: Text(cidade.nmcidade),
                        onTap: () => onSelected(cidade),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_campoEstado(), const SizedBox(height: 14), _campoCidade()],
    );
  }
}
