import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/repositories/localidade_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/masks.dart'
    show CepInputFormatter, TelefoneInputFormatter;
import '../../core/utils/validators.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_localidade_field.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'horario_funcionamento_screen.dart';

class LojaFormPage extends StatefulWidget {
  final Loja? loja;

  const LojaFormPage({super.key, this.loja});

  @override
  State<LojaFormPage> createState() => _LojaFormPageState();
}

class _LojaFormPageState extends State<LojaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = LojaRepository();
  final _localidadeRepository = LocalidadeRepository();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _estiloLojaController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _diasValidadeController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _numeroEnderecoController =
      TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _capacidadeController = TextEditingController();
  final TextEditingController _percentualCashbackController =
      TextEditingController();

  bool _salvando = false;
  bool _carregandoNomeOrganizacao = true;
  bool _consultandoCep = false;
  String? _ultimoCepConsultado;
  String _nomeOrganizacao = 'Empresa não identificada';
  int? _estadoId;
  int? _cidadeId;
  String _idValidadeProd = 'S';
  bool _usaCashback = false;

  bool get editando => widget.loja != null;
  bool get _controlaValidadeProduto => _idValidadeProd == 'S';

  String? _validarCamposLoja() {
    final nome = _nomeController.text.trim();
    final estiloLoja = _estiloLojaController.text.trim();
    final bairro = _bairroController.text.trim();
    final endereco = _enderecoController.text.trim();
    final cep = Validators.somenteNumeros(_cepController.text);
    final numeroEndereco = _numeroEnderecoController.text.trim();
    final instagram = _instagramController.text.trim();
    final telefone = Validators.somenteNumeros(_telefoneController.text);
    final diasValidade = int.tryParse(_diasValidadeController.text.trim());
    final capacidade = int.tryParse(_capacidadeController.text.trim());
    final percentualCashback = double.tryParse(
      _percentualCashbackController.text.replaceAll(',', '.'),
    );

    if (nome.isEmpty) return 'Informe o nome do estabelecimento.';
    if (nome.length < 3) {
      return 'O nome do estabelecimento deve ter pelo menos 3 caracteres.';
    }
    if (nome.length > 120) {
      return 'O nome do estabelecimento pode ter no máximo 120 caracteres.';
    }
    if (estiloLoja.length > 255) {
      return 'O estilo musical pode ter no máximo 255 caracteres.';
    }
    if (_estadoId == null || _estadoId == 0) {
      return 'Selecione o estado do estabelecimento.';
    }
    if (_cidadeId == null || _cidadeId == 0) {
      return 'Selecione a cidade do estabelecimento.';
    }
    if (bairro.length > 120) {
      return 'O bairro pode ter no máximo 120 caracteres.';
    }
    if (endereco.length > 255) {
      return 'O endereço pode ter no máximo 255 caracteres.';
    }
    if (cep.isEmpty) {
      return 'Informe o CEP do estabelecimento.';
    }
    if (cep.length != 8) {
      return 'Informe um CEP válido com 8 dígitos.';
    }
    if (_ultimoCepConsultado != cep) {
      return 'Consulte o CEP antes de salvar o estabelecimento.';
    }
    if (numeroEndereco.isEmpty) {
      return 'Informe o número do endereço ou S/N.';
    }
    if (instagram.length > 255) {
      return 'O Instagram pode ter no máximo 255 caracteres.';
    }
    if (!Validators.instagramValido(instagram)) {
      return 'Informe um usuário ou endereço válido do Instagram.';
    }

    if (telefone.isNotEmpty) {
      if (telefone.length != 10 && telefone.length != 11) {
        return 'Informe um telefone válido com DDD.';
      }

      final ddd = int.tryParse(telefone.substring(0, 2));
      if (ddd == null || ddd < 11 || ddd > 99) {
        return 'Informe um DDD válido.';
      }

      if (telefone.length == 11 && telefone[2] != '9') {
        return 'O celular deve começar com 9 após o DDD.';
      }
    }
    if (capacidade == null || capacidade <= 0) {
      return 'Informe a capacidade total de pessoas do estabelecimento.';
    }

    if (_controlaValidadeProduto) {
      if (diasValidade == null) {
        return 'Informe a quantidade de dias de validade.';
      }
      if (diasValidade <= 0) {
        return 'Os dias de validade devem ser maiores que zero.';
      }
    }
    if (_usaCashback &&
        (percentualCashback == null ||
            percentualCashback <= 0 ||
            percentualCashback > 100)) {
      return 'Informe um percentual de cashback entre 0,01% e 100%.';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    if (widget.loja != null) {
      _nomeController.text = widget.loja!.nmloja;
      _estiloLojaController.text = widget.loja!.dsestiloloja ?? '';
      _bairroController.text = widget.loja!.dsbairroloja ?? '';
      _telefoneController.text = Formatters.telefone(
        widget.loja!.nrtelloja ?? '',
      );
      _diasValidadeController.text =
          widget.loja!.nrdiavalidade?.toString() ?? '90';
      _estadoId = widget.loja!.estadoId;
      _cidadeId = widget.loja!.cidadeId;
      _enderecoController.text = widget.loja!.endloja ?? '';
      _cepController.text = widget.loja!.nrceploja;
      _numeroEnderecoController.text = widget.loja!.nrendeloja;
      _ultimoCepConsultado = Validators.somenteNumeros(widget.loja!.nrceploja);
      _instagramController.text = widget.loja!.dsinstaloja ?? '';
      _idValidadeProd = widget.loja!.idvalidadeprod;
      _capacidadeController.text =
          widget.loja!.capacidadeTotal?.toString() ?? '';
      _usaCashback = widget.loja!.usacashback == 'S';
      _percentualCashbackController.text = widget.loja!.pccashback
          .toStringAsFixed(2)
          .replaceAll('.', ',');
    } else {
      _diasValidadeController.text = '90';
      _percentualCashbackController.text = '5,00';
    }

    _carregarNomeOrganizacao();
  }

  Future<void> _carregarNomeOrganizacao() async {
    try {
      final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = nome.isEmpty ? 'Empresa não identificada' : nome;
        _carregandoNomeOrganizacao = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = 'Empresa não identificada';
        _carregandoNomeOrganizacao = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _estiloLojaController.dispose();
    _bairroController.dispose();
    _telefoneController.dispose();
    _diasValidadeController.dispose();
    _enderecoController.dispose();
    _cepController.dispose();
    _numeroEnderecoController.dispose();
    _instagramController.dispose();
    _capacidadeController.dispose();
    _percentualCashbackController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final cep = Validators.somenteNumeros(_cepController.text);
    if (_consultandoCep) {
      return;
    }
    if (cep.length != 8) {
      AppSnackBar.aviso(context, 'Informe um CEP válido com 8 dígitos.');
      return;
    }

    setState(() => _consultandoCep = true);

    try {
      final endereco = await _localidadeRepository.buscarEnderecoPorCep(cep);
      final estados = await _localidadeRepository.listarEstados();
      final estado = estados
          .where(
            (item) =>
                item.sgestado.trim().toUpperCase() == endereco.uf.toUpperCase(),
          )
          .firstOrNull;
      if (estado == null) {
        throw Exception('O Estado retornado pelo CEP não foi encontrado.');
      }

      final cidades = await _localidadeRepository.listarCidadesPorEstado(
        estado.estadoId,
      );
      final cidade = cidades
          .where(
            (item) =>
                (endereco.codigoIbgeCidade != null &&
                    item.cdibgecid == endereco.codigoIbgeCidade) ||
                item.nmcidade.trim().toLowerCase() ==
                    endereco.cidade.trim().toLowerCase(),
          )
          .firstOrNull;
      if (cidade == null) {
        throw Exception('A cidade retornada pelo CEP não foi encontrada.');
      }

      if (!mounted) return;
      setState(() {
        _ultimoCepConsultado = cep;
        _cepController.text = endereco.cep;
        if (endereco.logradouro.isNotEmpty) {
          _enderecoController.text = endereco.logradouro;
        }
        if (endereco.bairro.isNotEmpty) {
          _bairroController.text = endereco.bairro;
        }
        _estadoId = estado.estadoId;
        _cidadeId = cidade.cidadeId;
      });
      AppSnackBar.sucesso(context, 'Endereço carregado pelo CEP.');
    } catch (e) {
      if (!mounted) return;
      _ultimoCepConsultado = null;
      AppSnackBar.erro(
        context,
        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
    }
  }

  void _limparEnderecoCarregado() {
    setState(() {
      _ultimoCepConsultado = null;
      _enderecoController.clear();
      _numeroEnderecoController.clear();
      _bairroController.clear();
      _estadoId = null;
      _cidadeId = null;
    });
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    FocusScope.of(context).unfocus();

    final erro = _validarCamposLoja();
    if (erro != null) {
      AppSnackBar.erro(context, erro);
      return;
    }

    setState(() => _salvando = true);

    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      if (organizacaoId == null) {
        throw Exception('Empresa não encontrada no login');
      }

      final telefoneSemMascara = Validators.somenteNumeros(
        _telefoneController.text,
      );
      final diasValidade = _controlaValidadeProduto
          ? int.parse(_diasValidadeController.text.trim())
          : widget.loja?.nrdiavalidade ?? 90;

      if (editando) {
        await _repository.atualizar(
          lojaId: widget.loja!.lojaId,
          organizacaoId: organizacaoId,
          estadoId: _estadoId!,
          cidadeId: _cidadeId!,
          nome: _nomeController.text.trim(),
          estiloLoja: _estiloLojaController.text.trim(),
          bairro: _bairroController.text.trim(),
          telefone: telefoneSemMascara,
          diasValidade: diasValidade,
          endereco: _enderecoController.text.trim(),
          cep: Validators.somenteNumeros(_cepController.text),
          numeroEndereco: _numeroEnderecoController.text.trim(),
          instagram: _instagramController.text.trim(),
          aberto24x7: widget.loja!.aberto24x7,
          idvalidadeprod: _idValidadeProd,
          capacidadeTotal: int.parse(_capacidadeController.text.trim()),
          usacashback: _usaCashback ? 'S' : 'N',
          pccashback: double.parse(
            _percentualCashbackController.text.replaceAll(',', '.'),
          ),
        );

        if (!mounted) return;
        AppSnackBar.sucesso(context, 'Estabelecimento atualizado com sucesso.');
        Navigator.of(context).pop(true);
      } else {
        final nomeLoja = _nomeController.text.trim();
        final lojaId = await _repository.criar(
          organizacaoId: organizacaoId,
          estadoId: _estadoId!,
          cidadeId: _cidadeId!,
          nome: nomeLoja,
          estiloLoja: _estiloLojaController.text.trim(),
          bairro: _bairroController.text.trim(),
          telefone: telefoneSemMascara,
          diasValidade: diasValidade,
          endereco: _enderecoController.text.trim(),
          cep: Validators.somenteNumeros(_cepController.text),
          numeroEndereco: _numeroEnderecoController.text.trim(),
          instagram: _instagramController.text.trim(),
          idvalidadeprod: _idValidadeProd,
          capacidadeTotal: int.parse(_capacidadeController.text.trim()),
          usacashback: _usaCashback ? 'S' : 'N',
          pccashback: double.parse(
            _percentualCashbackController.text.replaceAll(',', '.'),
          ),
        );

        if (!mounted) return;

        setState(() => _salvando = false);

        final lojaCriada = Loja(
          lojaId: lojaId,
          organizacaoId: organizacaoId,
          estadoId: _estadoId,
          cidadeId: _cidadeId,
          nmloja: nomeLoja,
          dsestiloloja: _estiloLojaController.text.trim(),
          dsbairroloja: _bairroController.text.trim(),
          nrtelloja: telefoneSemMascara,
          nrdiavalidade: diasValidade,
          nrceploja: Validators.somenteNumeros(_cepController.text),
          nrendeloja: _numeroEnderecoController.text.trim(),
          idvalidadeprod: _idValidadeProd,
          endloja: _enderecoController.text.trim(),
          dsinstaloja: _instagramController.text.trim(),
          capacidadeTotal: int.parse(_capacidadeController.text.trim()),
          usacashback: _usaCashback ? 'S' : 'N',
          pccashback: double.parse(
            _percentualCashbackController.text.replaceAll(',', '.'),
          ),
        );

        final horariosSalvos = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => HorarioFuncionamentoScreen(
              lojaId: lojaId,
              nomeLoja: nomeLoja,
              aberto24x7Inicial: lojaCriada.aberto24x7,
              onSalvarAberto24x7: (valor) =>
                  _repository.atualizarAberto24x7(lojaCriada, valor),
            ),
          ),
        );

        if (!mounted) return;

        if (horariosSalvos != true) {
          AppSnackBar.aviso(
            context,
            'O estabelecimento foi cadastrado. O horário de funcionamento poderá ser '
            'configurado depois.',
          );
        }

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icon(icone),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _tituloSecao(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icone, size: 21, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
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
              titulo: editando
                  ? 'Editar estabelecimento - ${widget.loja!.nmloja}'
                  : 'Novo estabelecimento',
              subtitulo: _carregandoNomeOrganizacao
                  ? 'Carregando empresa...'
                  : _nomeOrganizacao,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tituloSecao(
                                  'Identificação',
                                  Icons.storefront_outlined,
                                ),
                                TextFormField(
                                  controller: _nomeController,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 120,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(120),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Nome do estabelecimento',
                                    icone: Icons.store_outlined,
                                    hint: 'Digite o nome do estabelecimento',
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    final texto = value?.trim() ?? '';
                                    if (texto.isEmpty) {
                                      return 'Informe o nome do estabelecimento.';
                                    }
                                    if (texto.length < 3) {
                                      return 'Informe pelo menos 3 caracteres.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _estiloLojaController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLength: 255,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(255),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Estilo musical do estabelecimento',
                                    icone: Icons.music_note_outlined,
                                    hint:
                                        'Ex.: Sertanejo, rock, música ao vivo',
                                  ).copyWith(counterText: ''),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tituloSecao(
                                  'Localização',
                                  Icons.location_on_outlined,
                                ),
                                TextFormField(
                                  controller: _cepController,
                                  enabled: !_salvando && !_consultandoCep,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.search,
                                  inputFormatters: [CepInputFormatter()],
                                  onChanged: (value) {
                                    final cep = Validators.somenteNumeros(
                                      value,
                                    );
                                    if (_ultimoCepConsultado != cep) {
                                      _limparEnderecoCarregado();
                                    }
                                  },
                                  onFieldSubmitted: (_) => _buscarCep(),
                                  decoration: _decoracaoCampo(
                                    label: 'CEP',
                                    icone: Icons.location_searching_rounded,
                                    hint: '00000-000',
                                    helperText:
                                        'Preenche endereço, bairro, Estado e Cidade.',
                                  ),
                                  validator: (value) {
                                    final cep = Validators.somenteNumeros(
                                      value ?? '',
                                    );
                                    if (cep.isEmpty) {
                                      return 'Informe o CEP do estabelecimento.';
                                    }
                                    if (cep.length != 8) {
                                      return 'Informe um CEP válido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 46,
                                  child: FilledButton.icon(
                                    onPressed: _salvando || _consultandoCep
                                        ? null
                                        : _buscarCep,
                                    icon: _consultandoCep
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.download_rounded),
                                    label: Text(
                                      _consultandoCep
                                          ? 'Carregando endereço...'
                                          : 'Carregar endereço pelo CEP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: ClubbarColors.ambar,
                                      foregroundColor: ClubbarColors.preto,
                                      disabledBackgroundColor:
                                          ClubbarColors.ambarClaro,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _enderecoController,
                                  readOnly: true,
                                  canRequestFocus: false,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLength: 255,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(255),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Endereço do estabelecimento',
                                    icone: Icons.home_work_outlined,
                                    helperText:
                                        'Preenchido automaticamente pelo CEP.',
                                  ).copyWith(counterText: ''),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _numeroEnderecoController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 20,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(20),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Número',
                                    icone: Icons.pin_outlined,
                                    hint: 'Ex.: 120 ou S/N',
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Informe o número ou S/N.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _bairroController,
                                  readOnly: true,
                                  canRequestFocus: false,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 120,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(120),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Bairro',
                                    icone: Icons.map_outlined,
                                    helperText:
                                        'Preenchido automaticamente pelo CEP.',
                                  ).copyWith(counterText: ''),
                                ),
                                const SizedBox(height: 14),
                                ClubbarLocalidadeField(
                                  estadoInicialId: _estadoId,
                                  cidadeInicialId: _cidadeId,
                                  obrigatorio: true,
                                  habilitado: false,
                                  onChanged: (estado, cidade) {
                                    _estadoId = estado?.estadoId;
                                    _cidadeId = cidade?.cidadeId;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tituloSecao(
                                  'Contato e funcionamento',
                                  Icons.contact_phone_outlined,
                                ),
                                TextFormField(
                                  controller: _telefoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    TelefoneInputFormatter(),
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Telefone ou celular',
                                    icone: Icons.phone_outlined,
                                    hint: '(35) 99999-9999',
                                  ),
                                  validator: (value) {
                                    final numeros = Validators.somenteNumeros(
                                      value ?? '',
                                    );
                                    if (numeros.isEmpty) return null;
                                    if (numeros.length != 10 &&
                                        numeros.length != 11) {
                                      return 'Informe um telefone válido com DDD.';
                                    }
                                    if (numeros.length == 11 &&
                                        numeros[2] != '9') {
                                      return 'O celular deve começar com 9 após o DDD.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _instagramController,
                                  maxLength: 255,
                                  keyboardType: TextInputType.url,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(255),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Instagram do estabelecimento',
                                    icone: Icons.alternate_email,
                                    hint: '@nomedaloja',
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    final texto = value?.trim() ?? '';
                                    if (!Validators.instagramValido(texto)) {
                                      return 'Informe um Instagram válido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _capacidadeController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(7),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Capacidade total de pessoas',
                                    icone: Icons.groups_rounded,
                                    hint: 'Ex.: 500',
                                    helperText:
                                        'Limite máximo usado na venda de ingressos.',
                                  ),
                                  validator: (value) {
                                    final numero = int.tryParse(
                                      value?.trim() ?? '',
                                    );
                                    if (numero == null || numero <= 0) {
                                      return 'Informe uma capacidade maior que zero.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _controlaValidadeProduto,
                                  onChanged: _salvando
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _idValidadeProd = value ? 'S' : 'N';
                                            if (value &&
                                                _diasValidadeController.text
                                                    .trim()
                                                    .isEmpty) {
                                              _diasValidadeController.text =
                                                  '90';
                                            }
                                          });
                                        },
                                  activeTrackColor: ClubbarColors.ambar,
                                  title: const Text(
                                    'Controlar validade dos tickets de produtos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _controlaValidadeProduto
                                        ? 'Os produtos na carteira expiram após o prazo informado.'
                                        : 'Os tickets de produtos não terão data de expiração. Ingressos não são afetados.',
                                  ),
                                  secondary: Icon(
                                    _controlaValidadeProduto
                                        ? Icons.event_available_outlined
                                        : Icons.event_busy_outlined,
                                    color: _controlaValidadeProduto
                                        ? ClubbarColors.ambarEscuro
                                        : ClubbarColors.textoSecundario,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _diasValidadeController,
                                  enabled:
                                      _controlaValidadeProduto && !_salvando,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Dias de validade',
                                    icone: Icons.event_available_outlined,
                                    hint: '90',
                                    helperText: _controlaValidadeProduto
                                        ? 'Prazo de validade dos tickets de produtos.'
                                        : 'Sem controle de validade para produtos.',
                                  ),
                                  validator: (value) {
                                    if (!_controlaValidadeProduto) return null;
                                    final texto = value?.trim() ?? '';
                                    final numero = int.tryParse(texto);
                                    if (texto.isEmpty) {
                                      return 'Informe os dias de validade.';
                                    }
                                    if (numero == null || numero <= 0) {
                                      return 'Informe um número maior que zero.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
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
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _salvando ? 'Salvando...' : 'Salvar estabelecimento',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.amber.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
