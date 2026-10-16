import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/repositories/localidade_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/masks.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento.dart';
import 'evento_modelo_atracoes_page.dart';

class EventoFormPage extends StatefulWidget {
  final int organizacaoId;
  final Evento? evento;

  const EventoFormPage({super.key, required this.organizacaoId, this.evento});

  @override
  State<EventoFormPage> createState() => _EventoFormPageState();
}

class _EventoFormPageState extends State<EventoFormPage> {
  static const int _limiteTitulo = 120;
  static const _nomesEtapas = [
    'Dados',
    'Banner',
    'Contato',
    'Preço',
    'Local',
    'Atrações',
  ];

  final _repo = EventoRepository();
  final _localidadeRepository = LocalidadeRepository();
  final _picker = ImagePicker();
  final _pageController = PageController();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _emailContatoController = TextEditingController();
  final _whatsappContatoController = TextEditingController();
  final _localController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _precoController = TextEditingController(text: '0,00');

  XFile? _imagemSelecionada;
  Uint8List? _imagemBytes;
  bool _salvando = false;
  bool _consultandoCep = false;
  String? _ultimoCepConsultado;
  String _tipoLocalSelecionado = 'ESTABELECIMENTO';
  String _nomeEmpresa = 'Empresa';
  int _etapa = 0;
  int? _modeloCriadoId;

  bool get _editando => widget.evento != null;
  bool get _ultimaEtapa => _etapa == _nomesEtapas.length - 1;
  int get _modeloId => widget.evento?.eventoId ?? _modeloCriadoId ?? 0;

  @override
  void initState() {
    super.initState();
    _carregarNomeEmpresa();
    final evento = widget.evento;
    if (evento == null) return;
    _tituloController.text = evento.nmtituloevento;
    _descricaoController.text = evento.dsdescevento ?? '';
    _emailContatoController.text = evento.emailContatoEvento ?? '';
    _whatsappContatoController.text = evento.whatsappEvento ?? '';
    _tipoLocalSelecionado = evento.tipoLocalEvento;
    _cepController.text = evento.nrCepLocalEvento ?? '';
    _localController.text = evento.nmlocalevento ?? '';
    _enderecoController.text = evento.dsendlocevento ?? '';
    _precoController.text = evento.vrPrecoPadrao
        .toStringAsFixed(2)
        .replaceAll('.', ',');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tituloController.dispose();
    _descricaoController.dispose();
    _emailContatoController.dispose();
    _whatsappContatoController.dispose();
    _localController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeEmpresa() async {
    final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
    if (mounted && nome.isNotEmpty) setState(() => _nomeEmpresa = nome);
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
    String? prefixText,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
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
  );

  double _valorPreco() =>
      double.tryParse(
        _precoController.text.replaceAll('.', '').replaceAll(',', '.'),
      ) ??
      0;

  void _formatarPreco() {
    final texto = _valorPreco().toStringAsFixed(2).replaceAll('.', ',');
    _precoController.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  bool _validarEtapa(int etapa) {
    final titulo = _tituloController.text.trim();
    final email = _emailContatoController.text.trim();
    final whatsapp = _whatsappContatoController.text.trim();
    String? mensagem;
    switch (etapa) {
      case 0:
        if (titulo.isEmpty) {
          mensagem = 'Informe o nome do evento para continuar.';
        } else if (titulo.length > _limiteTitulo) {
          mensagem =
              'O nome do evento deve ter no máximo $_limiteTitulo caracteres.';
        }
      case 2:
        if (email.isNotEmpty && !email.contains('@')) {
          mensagem = 'Informe um e-mail válido.';
        } else if (email.isEmpty && whatsapp.isEmpty) {
          mensagem = 'Informe um e-mail ou WhatsApp para contato.';
        }
      case 3:
        if (_valorPreco() < 0) mensagem = 'Informe um preço padrão válido.';
      case 4:
        if (_tipoLocalSelecionado == 'OUTRO') {
          final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
          if (_localController.text.trim().isEmpty) {
            mensagem = 'Informe o nome do local.';
          } else if (cep.length != 8) {
            mensagem = 'Informe um CEP válido.';
          } else if (_enderecoController.text.trim().isEmpty) {
            mensagem = 'Informe o endereço do local.';
          }
        }
    }
    if (mensagem == null) return true;
    AppSnackBar.aviso(context, mensagem);
    return false;
  }

  Future<void> _irParaEtapa(int etapa) async {
    FocusScope.of(context).unfocus();
    await _pageController.animateToPage(
      etapa,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _avancar({bool pularBanner = false}) async {
    if (!pularBanner && !_validarEtapa(_etapa)) return;
    if (_etapa == _nomesEtapas.length - 2) {
      if (await _salvarDados()) await _irParaEtapa(_etapa + 1);
      return;
    }
    await _irParaEtapa(_etapa + 1);
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
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, _mensagemErro(erro));
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
    }
  }

  Future<void> _selecionarImagem() async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (arquivo == null) return;
      final bytes = kIsWeb ? await arquivo.readAsBytes() : null;
      if (!mounted) return;
      setState(() {
        _imagemSelecionada = arquivo;
        _imagemBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Não foi possível selecionar o banner.');
      }
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

  Future<bool> _salvarDados() async {
    if (_salvando) return false;
    for (var etapa = 0; etapa < _nomesEtapas.length - 1; etapa++) {
      if (!_validarEtapa(etapa)) {
        await _irParaEtapa(etapa);
        return false;
      }
    }
    _formatarPreco();
    setState(() => _salvando = true);
    try {
      final outroLocal = _tipoLocalSelecionado == 'OUTRO';
      if (_editando || _modeloCriadoId != null) {
        await _repo.atualizar(
          eventoId: _modeloId,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          emailContatoEvento: _emailContatoController.text.trim(),
          whatsappEvento: _whatsappContatoController.text.trim(),
          tipoLocal: _tipoLocalSelecionado,
          cep: outroLocal ? _cepController.text.trim() : null,
          local: outroLocal ? _localController.text.trim() : '',
          endereco: outroLocal ? _enderecoController.text.trim() : '',
          precoPadrao: _valorPreco(),
          imagem: _imagemSelecionada,
        );
      } else {
        final modeloId = await _repo.criar(
          organizacaoId: widget.organizacaoId,
          produtoIdIngresso: 1,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          emailContatoEvento: _emailContatoController.text.trim(),
          whatsappEvento: _whatsappContatoController.text.trim(),
          tipoLocal: _tipoLocalSelecionado,
          cep: outroLocal ? _cepController.text.trim() : null,
          local: outroLocal ? _localController.text.trim() : null,
          endereco: outroLocal ? _enderecoController.text.trim() : null,
          precoPadrao: _valorPreco(),
          imagem: _imagemSelecionada,
        );
        _modeloCriadoId = modeloId;
      }
      if (!mounted) return false;
      return true;
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, _mensagemErro(erro));
      return false;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _concluir() async {
    if (_modeloId == 0) return;
    AppSnackBar.sucesso(
      context,
      _editando
          ? 'Evento atualizado com sucesso.'
          : 'Evento criado com sucesso.',
    );
    Navigator.pop(context, true);
  }

  Widget _cardEtapa({
    required String titulo,
    required String descricao,
    required Widget child,
  }) => ClubbarCard(
    elevation: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          descricao,
          style: const TextStyle(color: ClubbarColors.textoSecundario),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  Widget _passoDados() => _cardEtapa(
    titulo: 'Dados do evento',
    descricao: 'O nome é obrigatório para criar o evento padrão.',
    child: Column(
      children: [
        TextField(
          controller: _tituloController,
          textCapitalization: TextCapitalization.words,
          maxLength: _limiteTitulo,
          inputFormatters: [LengthLimitingTextInputFormatter(_limiteTitulo)],
          decoration: _decoracaoCampo(
            label: 'Nome do evento',
            icone: Icons.celebration_outlined,
            hint: 'Ex.: Motor Rock Festival',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _descricaoController,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoracaoCampo(
            label: 'Descrição do evento',
            icone: Icons.description_outlined,
            hint: 'Descreva o evento',
          ),
        ),
      ],
    ),
  );

  Widget _imagemBanner() {
    Widget placeholder() => Container(
      color: ClubbarColors.ambarClaro,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 56,
        color: ClubbarColors.preto,
      ),
    );
    if (_imagemSelecionada != null) {
      if (kIsWeb && _imagemBytes != null) {
        return Image.memory(
          _imagemBytes!,
          fit: BoxFit.contain,
          width: double.infinity,
        );
      }
      return Image.file(
        _imagemSelecionada!.path.isEmpty
            ? File('')
            : File(_imagemSelecionada!.path),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    final bannerAtual = _montarUrlBannerAtual();
    if (bannerAtual.isNotEmpty) {
      return Image.network(
        bannerAtual,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    return placeholder();
  }

  Widget _passoBanner() => _cardEtapa(
    titulo: 'Banner do evento',
    descricao: 'Opcional. Você pode adicionar ou trocar a imagem depois.',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _salvando ? null : _selecionarImagem,
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _imagemBanner(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Selecionar banner',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _passoContato() => _cardEtapa(
    titulo: 'Contato do evento',
    descricao:
        'Informe ao menos um canal para o cliente falar com o organizador.',
    child: Column(
      children: [
        TextField(
          controller: _emailContatoController,
          keyboardType: TextInputType.emailAddress,
          decoration: _decoracaoCampo(
            label: 'E-mail',
            icone: Icons.email_outlined,
            hint: 'contato@evento.com.br',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'ou',
            style: TextStyle(color: ClubbarColors.textoSecundario),
          ),
        ),
        TextField(
          controller: _whatsappContatoController,
          keyboardType: TextInputType.phone,
          decoration: _decoracaoCampo(
            label: 'WhatsApp',
            icone: Icons.chat_outlined,
            hint: '(00) 00000-0000',
          ),
        ),
      ],
    ),
  );

  Widget _passoPreco() => _cardEtapa(
    titulo: 'Preço padrão do ingresso',
    descricao:
        'Ele será sugerido ao agendar o evento e pode ser alterado por lote e setor.',
    child: TextField(
      controller: _precoController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [
        DecimalInputFormatter(casasDecimais: 2, usarSeparadorMilhar: true),
      ],
      onTap: () {
        if (_valorPreco() == 0) {
          _precoController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _precoController.text.length,
          );
        }
      },
      onEditingComplete: _formatarPreco,
      onTapOutside: (_) => _formatarPreco(),
      decoration: _decoracaoCampo(
        label: 'Preço padrão',
        icone: Icons.payments_outlined,
        prefixText: r'R$ ',
        hint: '0,00',
      ),
    ),
  );

  Widget _passoLocal() => _cardEtapa(
    titulo: 'Onde o evento será realizado?',
    descricao: 'Escolha o estabelecimento ou informe outro local.',
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _tipoLocalSelecionado,
          decoration: _decoracaoCampo(
            label: 'Local do evento',
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
              : (valor) => setState(() {
                  _tipoLocalSelecionado = valor ?? 'ESTABELECIMENTO';
                  if (_tipoLocalSelecionado == 'ESTABELECIMENTO') {
                    _cepController.clear();
                    _localController.clear();
                    _enderecoController.clear();
                  }
                }),
        ),
        if (_tipoLocalSelecionado == 'OUTRO') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _localController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Nome do local',
              icone: Icons.location_city_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cepController,
            keyboardType: TextInputType.number,
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
                  selection: TextSelection.collapsed(offset: formatado.length),
                );
              }
              if (limitado != _ultimoCepConsultado) {
                _ultimoCepConsultado = null;
              }
              if (limitado.length == 8) _buscarCep();
            },
            onSubmitted: (_) => _buscarCep(),
            decoration: _decoracaoCampo(
              label: 'CEP',
              icone: Icons.markunread_mailbox_outlined,
              hint: '00000-000',
              suffixIcon: _consultandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: _buscarCep,
                      icon: const Icon(Icons.search_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _enderecoController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Endereço',
              icone: Icons.map_outlined,
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _gerenciarAtracoes() async {
    if (_modeloId == 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventoModeloAtracoesPage(
          modeloId: _modeloId,
          titulo: _tituloController.text.trim(),
        ),
      ),
    );
  }

  Widget _passoAtracoes() => _cardEtapa(
    titulo: 'Atrações do evento',
    descricao:
        'Defina as atrações que serão copiadas quando este evento for agendado. Esta etapa é opcional.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ClubbarColors.sucessoClaro,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.music_note_rounded, color: ClubbarColors.sucesso),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Você pode adicionar, ordenar ou remover atrações antes de concluir.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _salvando ? null : _gerenciarAtracoes,
          icon: const Icon(Icons.queue_music_rounded),
          label: const Text('Gerenciar atrações'),
        ),
      ],
    ),
  );

  Widget _indicadorEtapas() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Column(
      children: [
        Row(
          children: List.generate(_nomesEtapas.length, (indice) {
            final preenchida = indice <= _etapa;
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(
                  right: indice == _nomesEtapas.length - 1 ? 0 : 5,
                ),
                decoration: BoxDecoration(
                  color: preenchida
                      ? ClubbarColors.primaria
                      : ClubbarColors.borda,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Passo ${_etapa + 1} de ${_nomesEtapas.length}: ${_nomesEtapas[_etapa]}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _acoesNavegacao() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          if (_etapa > 0)
            OutlinedButton(
              onPressed: _salvando ? null : () => _irParaEtapa(_etapa - 1),
              child: const Text('Voltar'),
            ),
          if (_etapa == 1) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _salvando ? null : () => _avancar(pularBanner: true),
              child: const Text('Pular'),
            ),
          ],
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _salvando ? null : (_ultimaEtapa ? _concluir : _avancar),
            icon: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ClubbarColors.preto,
                    ),
                  )
                : Icon(
                    _ultimaEtapa
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              _salvando
                  ? 'Salvando...'
                  : (_ultimaEtapa
                        ? 'Concluir'
                        : (_etapa == _nomesEtapas.length - 2
                              ? 'Salvar e avançar'
                              : 'Próximo')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClubbarColors.ambar,
              foregroundColor: ClubbarColors.branco,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: _nomeEmpresa,
            subtitulo: _editando
                ? 'Editar evento padrão'
                : 'Novo evento padrão',
            tituloStyle: const TextStyle(
              color: ClubbarColors.primariaEscuro,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          _indicadorEtapas(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (etapa) => setState(() => _etapa = etapa),
              children:
                  [
                        _passoDados(),
                        _passoBanner(),
                        _passoContato(),
                        _passoPreco(),
                        _passoLocal(),
                        _passoAtracoes(),
                      ]
                      .map(
                        (passo) => ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          children: [passo],
                        ),
                      )
                      .toList(),
            ),
          ),
          _acoesNavegacao(),
        ],
      ),
    ),
  );
}
