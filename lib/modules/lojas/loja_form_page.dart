import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
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
  final _picker = ImagePicker();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _estiloLojaController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _diasValidadeController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();

  bool _salvando = false;
  bool _carregandoNomeOrganizacao = true;
  String _nomeOrganizacao = 'Organização não identificada';
  int? _estadoId;
  int? _cidadeId;

  XFile? _imagemSelecionada;
  Uint8List? _imagemBytes;
  XFile? _imagemFachadaSelecionada;
  Uint8List? _imagemFachadaBytes;

  bool get editando => widget.loja != null;

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatarTelefone(String? valor) {
    final numeros = _somenteNumeros(valor ?? '');

    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    }

    return valor ?? '';
  }

  String _formatarPercentual(num? valor) {
    final taxa = valor ?? 5;
    return '${taxa.toStringAsFixed(2).replaceAll('.', ',')}%';
  }

  bool _instagramValido(String valor) {
    final texto = valor.trim();
    if (texto.isEmpty) return true;

    final usuario = texto
        .replaceFirst(RegExp(r'^https?://(www\.)?instagram\.com/'), '')
        .replaceFirst('@', '')
        .split('/')
        .first
        .trim();

    return RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(usuario);
  }

  String? _validarCamposLoja() {
    final nome = _nomeController.text.trim();
    final estiloLoja = _estiloLojaController.text.trim();
    final bairro = _bairroController.text.trim();
    final endereco = _enderecoController.text.trim();
    final instagram = _instagramController.text.trim();
    final telefone = _somenteNumeros(_telefoneController.text);
    final diasValidade = int.tryParse(_diasValidadeController.text.trim());

    if (nome.isEmpty) return 'Informe o nome da loja.';
    if (nome.length < 3) {
      return 'O nome da loja deve ter pelo menos 3 caracteres.';
    }
    if (nome.length > 120) {
      return 'O nome da loja pode ter no máximo 120 caracteres.';
    }
    if (estiloLoja.length > 255) {
      return 'O estilo musical pode ter no máximo 255 caracteres.';
    }
    if (_estadoId == null || _estadoId == 0) {
      return 'Selecione o estado da loja.';
    }
    if (_cidadeId == null || _cidadeId == 0) {
      return 'Selecione a cidade da loja.';
    }
    if (bairro.length > 120) {
      return 'O bairro pode ter no máximo 120 caracteres.';
    }
    if (endereco.length > 255) {
      return 'O endereço pode ter no máximo 255 caracteres.';
    }
    if (instagram.length > 255) {
      return 'O Instagram pode ter no máximo 255 caracteres.';
    }
    if (!_instagramValido(instagram)) {
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

    if (diasValidade == null) {
      return 'Informe a quantidade de dias de validade.';
    }
    if (diasValidade <= 0) {
      return 'Os dias de validade devem ser maiores que zero.';
    }

    return null;
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (erro) {
      AppSnackBar.erro(context, mensagem);
    } else {
      AppSnackBar.sucesso(context, mensagem);
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.loja != null) {
      _nomeController.text = widget.loja!.nmloja;
      _estiloLojaController.text = widget.loja!.dsestiloloja ?? '';
      _bairroController.text = widget.loja!.dsbairroloja ?? '';
      _telefoneController.text = _formatarTelefone(widget.loja!.nrtelloja);
      _diasValidadeController.text =
          widget.loja!.nrdiavalidade?.toString() ?? '90';
      _estadoId = widget.loja!.estadoId;
      _cidadeId = widget.loja!.cidadeId;
      _enderecoController.text = widget.loja!.endloja ?? '';
      _instagramController.text = widget.loja!.dsinstaloja ?? '';
    } else {
      _diasValidadeController.text = '90';
    }

    _carregarNomeOrganizacao();
  }

  Future<void> _carregarNomeOrganizacao() async {
    try {
      final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = nome.isEmpty ? 'Organização não identificada' : nome;
        _carregandoNomeOrganizacao = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = 'Organização não identificada';
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
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (arquivo == null) return;

      Uint8List? bytes;
      if (kIsWeb) bytes = await arquivo.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imagemSelecionada = arquivo;
        _imagemBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem('Erro ao selecionar imagem: $e', erro: true);
    }
  }

  Future<void> _selecionarImagemFachada() async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (arquivo == null) return;

      Uint8List? bytes;
      if (kIsWeb) bytes = await arquivo.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imagemFachadaSelecionada = arquivo;
        _imagemFachadaBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem('Erro ao selecionar a foto da fachada: $e', erro: true);
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;

    final formularioValido = _formKey.currentState?.validate() ?? false;
    if (!formularioValido) return;

    final erro = _validarCamposLoja();
    if (erro != null) {
      _mostrarMensagem(erro, erro: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      if (organizacaoId == null) {
        throw Exception('Organização não encontrada no login');
      }

      final telefoneSemMascara = _somenteNumeros(_telefoneController.text);
      final diasValidade = int.parse(_diasValidadeController.text.trim());

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
          instagram: _instagramController.text.trim(),
          aberto24x7: widget.loja!.aberto24x7,
          imagem: _imagemSelecionada,
          imagemFachada: _imagemFachadaSelecionada,
        );

        if (!mounted) return;
        _mostrarMensagem('Loja atualizada com sucesso.');
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
          instagram: _instagramController.text.trim(),
          imagem: _imagemSelecionada,
          imagemFachada: _imagemFachadaSelecionada,
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
          endloja: _enderecoController.text.trim(),
          dsinstaloja: _instagramController.text.trim(),
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
            'A loja foi cadastrada. O horário de funcionamento poderá ser '
            'configurado depois.',
          );
        }

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem('Erro ao salvar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirHorarios() async {
    final loja = widget.loja;
    if (loja == null) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HorarioFuncionamentoScreen(
          lojaId: loja.lojaId,
          nomeLoja: loja.nmloja,
          aberto24x7Inicial: loja.aberto24x7,
          onSalvarAberto24x7: (valor) =>
              _repository.atualizarAberto24x7(loja, valor),
        ),
      ),
    );
  }

  String _montarUrlImagemAtual(String? caminhoImagem) {
    final imagemAtual = (caminhoImagem ?? '').trim();
    if (imagemAtual.isEmpty) return '';
    if (imagemAtual.startsWith('http')) return imagemAtual;

    final path = imagemAtual.startsWith('/') ? imagemAtual : '/$imagemAtual';
    return '${ApiConfig.baseUrl}$path';
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
    final imagemAtualUrl = _montarUrlImagemAtual(widget.loja?.urllogoloja);
    final fachadaAtualUrl = _montarUrlImagemAtual(widget.loja?.urlfachadaloja);
    final taxaProduto = _formatarPercentual(widget.loja?.vrtaxaprod);
    final taxaIngresso = _formatarPercentual(widget.loja?.vrtaxaing);

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: editando ? 'Editar Loja' : 'Nova Loja',
              subtitulo: _carregandoNomeOrganizacao
                  ? 'Carregando organização...'
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
                                GestureDetector(
                                  onTap: _salvando ? null : _selecionarImagem,
                                  child: Container(
                                    height: 150,
                                    margin: const EdgeInsets.only(bottom: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: _imagemSelecionada != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: kIsWeb
                                                ? Image.memory(
                                                    _imagemBytes!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  )
                                                : Image.network(
                                                    _imagemSelecionada!.path,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (_, _, _) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons.store,
                                                            size: 44,
                                                          ),
                                                        ),
                                                  ),
                                          )
                                        : editando && imagemAtualUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Image.network(
                                              imagemAtualUrl,
                                              key: ValueKey(imagemAtualUrl),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons.store,
                                                      size: 44,
                                                    ),
                                                  ),
                                            ),
                                          )
                                        : const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_outlined,
                                                  size: 42,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Toque para selecionar a logo',
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _salvando
                                      ? null
                                      : _selecionarImagemFachada,
                                  child: Container(
                                    height: 180,
                                    margin: const EdgeInsets.only(bottom: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: _imagemFachadaSelecionada != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: kIsWeb
                                                ? Image.memory(
                                                    _imagemFachadaBytes!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  )
                                                : Image.network(
                                                    _imagemFachadaSelecionada!
                                                        .path,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (_, _, _) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons
                                                                .storefront_outlined,
                                                            size: 44,
                                                          ),
                                                        ),
                                                  ),
                                          )
                                        : editando && fachadaAtualUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Image.network(
                                              fachadaAtualUrl,
                                              key: ValueKey(fachadaAtualUrl),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons.storefront_outlined,
                                                      size: 44,
                                                    ),
                                                  ),
                                            ),
                                          )
                                        : const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                  size: 42,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Toque para selecionar a foto da fachada',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _nomeController,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 120,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(120),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Nome da loja',
                                    icone: Icons.store_outlined,
                                    hint: 'Digite o nome da loja',
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    final texto = value?.trim() ?? '';
                                    if (texto.isEmpty) {
                                      return 'Informe o nome da loja.';
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
                                    label: 'Estilo musical da loja',
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
                        if (editando) ...[
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              enabled: !_salvando,
                              onTap: _salvando ? null : _abrirHorarios,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                foregroundColor: Colors.amber.shade900,
                                child: const Icon(Icons.schedule_rounded),
                              ),
                              title: const Text(
                                'Horário de funcionamento',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Defina os dias e horários de atendimento',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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
                                  controller: _enderecoController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLength: 255,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(255),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Endereço da loja',
                                    icone: Icons.home_work_outlined,
                                  ).copyWith(counterText: ''),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _bairroController,
                                  textCapitalization: TextCapitalization.words,
                                  maxLength: 120,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(120),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Bairro',
                                    icone: Icons.map_outlined,
                                  ).copyWith(counterText: ''),
                                ),
                                const SizedBox(height: 14),
                                ClubbarLocalidadeField(
                                  estadoInicialId: _estadoId,
                                  cidadeInicialId: _cidadeId,
                                  obrigatorio: true,
                                  habilitado: !_salvando,
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
                                  controller: _instagramController,
                                  maxLength: 255,
                                  keyboardType: TextInputType.url,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(255),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Instagram da loja',
                                    icone: Icons.alternate_email,
                                    hint: '@nomedaloja',
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    final texto = value?.trim() ?? '';
                                    if (!_instagramValido(texto)) {
                                      return 'Informe um Instagram válido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
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
                                    final numeros = _somenteNumeros(
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
                                  controller: _diasValidadeController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: _decoracaoCampo(
                                    label: 'Dias de validade',
                                    icone: Icons.event_available_outlined,
                                    hint: '90',
                                    helperText:
                                        'Prazo padrão de validade dos itens.',
                                  ),
                                  validator: (value) {
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
                                  'Taxas do Clubbar',
                                  Icons.percent_outlined,
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final taxaProdutosField = TextFormField(
                                      initialValue: taxaProduto,
                                      readOnly: true,
                                      canRequestFocus: false,
                                      decoration: _decoracaoCampo(
                                        label: 'Taxa sobre produtos',
                                        icone: Icons.shopping_bag_outlined,
                                        helperText:
                                            'Somente o superadministrador pode alterar.',
                                        suffixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                      ).copyWith(fillColor: Colors.grey.shade100),
                                    );

                                    final taxaIngressosField = TextFormField(
                                      initialValue: taxaIngresso,
                                      readOnly: true,
                                      canRequestFocus: false,
                                      decoration: _decoracaoCampo(
                                        label: 'Taxa sobre ingressos',
                                        icone:
                                            Icons.confirmation_number_outlined,
                                        helperText:
                                            'Somente o superadministrador pode alterar.',
                                        suffixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                      ).copyWith(fillColor: Colors.grey.shade100),
                                    );

                                    if (constraints.maxWidth < 560) {
                                      return Column(
                                        children: [
                                          taxaProdutosField,
                                          const SizedBox(height: 12),
                                          taxaIngressosField,
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: taxaProdutosField),
                                        const SizedBox(width: 12),
                                        Expanded(child: taxaIngressosField),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'As duas taxas possuem valor padrão de 5,00%.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
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
                              _salvando ? 'Salvando...' : 'Salvar loja',
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

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 11) {
      numeros = numeros.substring(0, 11);
    }

    String texto;

    if (numeros.isEmpty) {
      texto = '';
    } else if (numeros.length <= 2) {
      texto = '($numeros';
    } else if (numeros.length <= 6) {
      texto = '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    } else if (numeros.length <= 10) {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    } else {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
