import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/repositories/localidade_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento.dart';

class EventoFormPage extends StatefulWidget {
  final int organizacaoId;
  final Evento? evento;

  const EventoFormPage({super.key, required this.organizacaoId, this.evento});

  @override
  State<EventoFormPage> createState() => _EventoFormPageState();
}

class _EventoFormPageState extends State<EventoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EventoRepository();
  final _localidadeRepository = LocalidadeRepository();
  final _picker = ImagePicker();

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _localController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _precoController = TextEditingController(text: '0,00');

  XFile? _imagemSelecionada;
  Uint8List? _imagemBytes;

  bool _salvando = false;
  bool _consultandoCep = false;
  String? _ultimoCepConsultado;
  String _statusSelecionado = 'ATIVO';
  String _tipoLocalSelecionado = 'ESTABELECIMENTO';
  String _nomeEmpresa = 'Empresa';

  bool get editando => widget.evento != null;

  @override
  void initState() {
    super.initState();
    _carregarNomeEmpresa();

    final evento = widget.evento;
    if (evento != null) {
      _tituloController.text = evento.nmtituloevento;
      _descricaoController.text = evento.dsdescevento ?? '';
      _tipoLocalSelecionado = evento.tipoLocalEvento;
      _cepController.text = evento.nrCepLocalEvento ?? '';
      _localController.text = evento.nmlocalevento ?? '';
      _enderecoController.text = evento.dsendlocevento ?? '';
      _statusSelecionado = evento.statusevento ?? 'ATIVO';
      _precoController.text = evento.vrPrecoPadrao
          .toStringAsFixed(2)
          .replaceAll('.', ',');
    }
  }

  Future<void> _carregarNomeEmpresa() async {
    final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
    if (mounted && nome.isNotEmpty) setState(() => _nomeEmpresa = nome);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _localController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  Future<void> _buscarCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8 || _consultandoCep || cep == _ultimoCepConsultado) {
      return;
    }
    setState(() => _consultandoCep = true);
    try {
      final endereco = await _localidadeRepository.buscarEnderecoPorCep(cep);
      if (!mounted) return;
      final partes = <String>[
        if (endereco.logradouro.isNotEmpty) endereco.logradouro,
        if (endereco.bairro.isNotEmpty) endereco.bairro,
        if (endereco.cidade.isNotEmpty)
          endereco.uf.isEmpty
              ? endereco.cidade
              : '${endereco.cidade} - ${endereco.uf}',
      ];
      setState(() {
        _ultimoCepConsultado = cep;
        _cepController.text = endereco.cep;
        _enderecoController.text = partes.join(', ');
      });
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
    }
  }

  String _montarUrlBannerAtual() {
    final caminho = (widget.evento?.urlbannerevento ?? '').trim();
    if (caminho.isEmpty) return '';
    if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
      return caminho;
    }
    return caminho.startsWith('/')
        ? '${ApiConfig.baseUrl}$caminho'
        : '${ApiConfig.baseUrl}/$caminho';
  }

  Future<void> _selecionarImagem() async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
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
      AppSnackBar.erro(context, 'Não foi possível selecionar o banner.');
    }
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
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    final preco =
        double.tryParse(
          _precoController.text.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;

    try {
      if (editando) {
        await _repo.atualizar(
          eventoId: widget.evento!.eventoId,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          tipoLocal: _tipoLocalSelecionado,
          cep: _tipoLocalSelecionado == 'OUTRO'
              ? _cepController.text.trim()
              : null,
          local: _tipoLocalSelecionado == 'OUTRO'
              ? _localController.text.trim()
              : '',
          endereco: _tipoLocalSelecionado == 'OUTRO'
              ? _enderecoController.text.trim()
              : '',
          status: _statusSelecionado,
          precoPadrao: preco,
          imagem: _imagemSelecionada,
        );
      } else {
        await _repo.criar(
          organizacaoId: widget.organizacaoId,
          produtoIdIngresso: 1,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          tipoLocal: _tipoLocalSelecionado,
          cep: _tipoLocalSelecionado == 'OUTRO'
              ? _cepController.text.trim()
              : null,
          local: _tipoLocalSelecionado == 'OUTRO'
              ? _localController.text.trim()
              : null,
          endereco: _tipoLocalSelecionado == 'OUTRO'
              ? _enderecoController.text.trim()
              : null,
          status: _statusSelecionado,
          precoPadrao: preco,
          imagem: _imagemSelecionada,
        );
      }

      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        editando
            ? 'Evento atualizado com sucesso.'
            : 'Evento criado com sucesso.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _imagemBanner() {
    final bannerAtual = _montarUrlBannerAtual();

    Widget placeholder() {
      return Container(
        color: ClubbarColors.ambarClaro,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 56,
          color: ClubbarColors.preto,
        ),
      );
    }

    if (_imagemSelecionada != null) {
      if (kIsWeb && _imagemBytes != null) {
        return Image.memory(
          _imagemBytes!,
          fit: BoxFit.contain,
          width: double.infinity,
        );
      }

      return Image.file(
        File(_imagemSelecionada!.path),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    if (editando && bannerAtual.isNotEmpty) {
      return Image.network(
        bannerAtual,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    return placeholder();
  }

  Widget _cardBanner() {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        children: [
          const Text(
            'Cadastre um evento padrão reutilizável',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 210,
              child: _imagemBanner(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _salvando ? null : _selecionarImagem,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                _imagemSelecionada != null || editando
                    ? 'Alterar banner'
                    : 'Selecionar banner',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(color: ClubbarColors.borda),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDados() {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados do evento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tituloController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Título',
              icone: Icons.celebration_outlined,
              hint: 'Ex.: Motor Rock Festival',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Informe o título do evento';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descricaoController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracaoCampo(
              label: 'Descrição',
              icone: Icons.description_outlined,
              hint: 'Descreva o evento',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _precoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoracaoCampo(
              label: 'Preço padrão da inteira',
              icone: Icons.attach_money_rounded,
              hint: '0,00',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _tipoLocalSelecionado,
            decoration: _decoracaoCampo(
              label: 'Onde o evento será realizado?',
              icone: Icons.location_on_outlined,
            ),
            items: const [
              DropdownMenuItem(
                value: 'ESTABELECIMENTO',
                child: Text('No estabelecimento'),
              ),
              DropdownMenuItem(value: 'OUTRO', child: Text('Em outro local')),
            ],
            onChanged: _salvando
                ? null
                : (value) => setState(() {
                    _tipoLocalSelecionado = value ?? 'ESTABELECIMENTO';
                    if (_tipoLocalSelecionado == 'ESTABELECIMENTO') {
                      _cepController.clear();
                      _localController.clear();
                      _enderecoController.clear();
                    }
                  }),
          ),
          if (_tipoLocalSelecionado == 'OUTRO') ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _localController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoracaoCampo(
                label: 'Local',
                icone: Icons.location_on_outlined,
                hint: 'Ex.: Motor Rock',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Informe o nome do local'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cepController,
              keyboardType: TextInputType.number,
              decoration:
                  _decoracaoCampo(
                    label: 'CEP do evento',
                    icone: Icons.markunread_mailbox_outlined,
                    hint: '00000-000',
                  ).copyWith(
                    suffixIcon: _consultandoCep
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'Buscar CEP',
                            onPressed: _buscarCep,
                            icon: const Icon(Icons.search_rounded),
                          ),
                  ),
              onChanged: (valor) {
                final numeros = valor.replaceAll(RegExp(r'\D'), '');
                final limitado = numeros.length > 8
                    ? numeros.substring(0, 8)
                    : numeros;
                final formatado = limitado.length > 5
                    ? '${limitado.substring(0, 5)}-${limitado.substring(5)}'
                    : limitado;
                if (formatado != valor) {
                  _cepController.value = TextEditingValue(
                    text: formatado,
                    selection: TextSelection.collapsed(
                      offset: formatado.length,
                    ),
                  );
                }
                if (limitado != _ultimoCepConsultado) {
                  _ultimoCepConsultado = null;
                }
                if (limitado.length == 8) _buscarCep();
              },
              onFieldSubmitted: (_) => _buscarCep(),
              validator: (value) =>
                  (value ?? '').replaceAll(RegExp(r'\D'), '').length != 8
                  ? 'Informe um CEP válido'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _enderecoController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoracaoCampo(
                label: 'Endereço',
                icone: Icons.map_outlined,
                hint: 'Rua, número, bairro, cidade e UF',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Informe o endereço do local'
                  : null,
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _statusSelecionado,
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
                : (value) {
                    if (value == null) return;
                    setState(() => _statusSelecionado = value);
                  },
          ),
        ],
      ),
    );
  }

  Widget _cardAvisoLotes() {
    return ClubbarCard(
      elevation: 0,
      backgroundColor: ClubbarColors.infoClaro,
      borderColor: ClubbarColors.info,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.confirmation_number_rounded, color: ClubbarColors.info),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ao agendar uma data, o sistema criará o Lote 1 com Pista '
              'Inteira e Pista Meia Entrada. A meia entrada inicia com 50% '
              'do preço da inteira e poderá ser ajustada depois.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: ClubbarColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoSalvar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
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
              : 'Cadastrar evento padrão',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
              titulo: _nomeEmpresa,
              subtitulo: 'Evento padrão',
              tituloStyle: const TextStyle(
                color: Colors.blue,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    _cardBanner(),
                    const SizedBox(height: 16),
                    _cardDados(),
                    const SizedBox(height: 16),
                    _cardAvisoLotes(),
                    const SizedBox(height: 20),
                    _botaoSalvar(),
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
