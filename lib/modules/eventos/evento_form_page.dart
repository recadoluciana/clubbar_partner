import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento.dart';

class EventoFormPage extends StatefulWidget {
  final int organizacaoId;
  final int lojaId;
  final Evento? evento;

  const EventoFormPage({
    super.key,
    required this.organizacaoId,
    required this.lojaId,
    this.evento,
  });

  @override
  State<EventoFormPage> createState() => _EventoFormPageState();
}

class _EventoFormPageState extends State<EventoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = EventoRepository();
  final _picker = ImagePicker();

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _dataInicioController = TextEditingController();
  final _dataFimController = TextEditingController();
  final _localController = TextEditingController();
  final _enderecoController = TextEditingController();

  DateTime? _dataInicioSelecionada;
  DateTime? _dataFimSelecionada;
  XFile? _imagemSelecionada;
  Uint8List? _imagemBytes;

  bool _salvando = false;
  String _statusSelecionado = 'ATIVO';

  bool get editando => widget.evento != null;

  @override
  void initState() {
    super.initState();

    final evento = widget.evento;
    if (evento != null) {
      _tituloController.text = evento.nmtituloevento;
      _descricaoController.text = evento.dsdescevento ?? '';
      _localController.text = evento.nmlocalevento ?? '';
      _enderecoController.text = evento.dsendlocevento ?? '';
      _statusSelecionado = evento.statusevento ?? 'ATIVO';

      final inicio = DateTime.tryParse(evento.dtinicioevento ?? '');
      if (inicio != null) {
        _dataInicioSelecionada = inicio;
        _dataInicioController.text = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(inicio);
      }

      final fim = DateTime.tryParse(evento.dtfimevento ?? '');
      if (fim != null) {
        _dataFimSelecionada = fim;
        _dataFimController.text = DateFormat('dd/MM/yyyy HH:mm').format(fim);
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _dataInicioController.dispose();
    _dataFimController.dispose();
    _localController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  String _dataParaApi(DateTime? data) {
    if (data == null) return '';
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(data);
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
      _dataInicioController.text = DateFormat('dd/MM/yyyy HH:mm').format(data);

      if (_dataFimSelecionada == null || _dataFimSelecionada!.isBefore(data)) {
        _dataFimSelecionada = data;
        _dataFimController.text = DateFormat('dd/MM/yyyy HH:mm').format(data);
      }
    });
  }

  Future<void> _selecionarFim() async {
    final data = await _selecionarDataHora(
      _dataFimSelecionada ?? _dataInicioSelecionada,
    );
    if (data == null || !mounted) return;

    setState(() {
      _dataFimSelecionada = data;
      _dataFimController.text = DateFormat('dd/MM/yyyy HH:mm').format(data);
    });
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

    if (_dataInicioSelecionada == null) {
      AppSnackBar.aviso(context, 'Informe a data e hora de início.');
      return;
    }

    if (_dataFimSelecionada == null) {
      AppSnackBar.aviso(context, 'Informe a data e hora de término.');
      return;
    }

    if (_dataFimSelecionada!.isBefore(_dataInicioSelecionada!)) {
      AppSnackBar.aviso(
        context,
        'A data final não pode ser anterior à data inicial.',
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final inicio = _dataParaApi(_dataInicioSelecionada);
      final fim = _dataParaApi(_dataFimSelecionada);

      if (editando) {
        await _repo.atualizar(
          eventoId: widget.evento!.eventoId,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataInicio: inicio,
          dataFim: fim,
          local: _localController.text.trim(),
          endereco: _enderecoController.text.trim(),
          status: _statusSelecionado,
          imagem: _imagemSelecionada,
        );
      } else {
        await _repo.criar(
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          produtoIdIngresso: 1,
          titulo: _tituloController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataInicio: inicio,
          dataFim: fim,
          local: _localController.text.trim(),
          endereco: _enderecoController.text.trim(),
          status: _statusSelecionado,
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
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }

      return Image.file(
        File(_imagemSelecionada!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    if (editando && bannerAtual.isNotEmpty) {
      return Image.network(
        bannerAtual,
        fit: BoxFit.cover,
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
            'Banner do evento',
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
            controller: _dataInicioController,
            readOnly: true,
            onTap: _selecionarInicio,
            decoration: _decoracaoCampo(
              label: 'Início do evento',
              icone: Icons.calendar_month_outlined,
              hint: 'dd/mm/aaaa hh:mm',
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Informe o início do evento';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dataFimController,
            readOnly: true,
            onTap: _selecionarFim,
            decoration: _decoracaoCampo(
              label: 'Término do evento',
              icone: Icons.event_available_outlined,
              hint: 'dd/mm/aaaa hh:mm',
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Informe o término do evento';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _localController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Local',
              icone: Icons.location_on_outlined,
              hint: 'Ex.: Motor Rock',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _enderecoController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Endereço',
              icone: Icons.map_outlined,
              hint: 'Rua, número e bairro',
            ),
          ),
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
              'Os preços, quantidades e períodos de venda são '
              'configurados nos lotes do evento após o cadastro.',
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
              : 'Cadastrar evento',
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
              titulo: editando ? 'Editar Evento' : 'Novo Evento',
              subtitulo: editando
                  ? 'Atualize os dados do evento'
                  : 'Cadastre o evento e depois configure os lotes',
              icone: Icons.event_rounded,
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
