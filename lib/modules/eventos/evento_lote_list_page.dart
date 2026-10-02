import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/repositories/evento_lote_repository.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/asaas_pendente_dialog.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento.dart';
import '../../models/evento_lote.dart';
import '../../models/atracao.dart';
import 'evento_lote_form_page.dart';

class EventoLoteListPage extends StatefulWidget {
  final int eventoId;
  final String eventoTitulo;
  final String? eventoBanner;
  final int organizacaoId;
  final int lojaId;
  final String? eventoInicio;
  final EventoSetor? setorParaGerenciar;
  final int abaInicial;
  final bool somenteConsulta;

  const EventoLoteListPage({
    super.key,
    required this.eventoId,
    required this.eventoTitulo,
    this.eventoBanner,
    required this.organizacaoId,
    required this.lojaId,
    this.eventoInicio,
    this.setorParaGerenciar,
    this.abaInicial = 0,
    this.somenteConsulta = false,
  });

  @override
  State<EventoLoteListPage> createState() => _EventoLoteListPageState();
}

class _EventoLoteListPageState extends State<EventoLoteListPage> {
  final _repo = EventoLoteRepository();
  final _eventoRepo = EventoRepository();
  final _atracaoRepo = AtracaoRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _carregando = true;
  String? _erro;
  int _aba = 0;
  List<EventoSetor> _setores = [];
  List<EventoLoteGlobal> _globais = [];
  List<EventoAtracao> _atracoes = [];
  CapacidadeEvento? _capacidade;
  Evento? _evento;
  late String? _eventoInicio;
  late String _eventoTitulo;
  late String? _eventoBanner;
  Uint8List? _bannerPreview;
  bool _alterandoPublicacao = false;

  @override
  void initState() {
    super.initState();
    _aba = widget.abaInicial.clamp(0, 3);
    _eventoInicio = widget.eventoInicio;
    _eventoTitulo = widget.eventoTitulo;
    _eventoBanner = widget.eventoBanner;
    _carregar();
  }

  String get _dataEvento {
    final data = DateTime.tryParse(_eventoInicio ?? '');
    return data == null
        ? 'Data e hora do evento não informadas'
        : DateFormat("dd/MM/yyyy 'às' HH:mm 'horas'").format(data);
  }

  String _data(String? valor) {
    final data = DateTime.tryParse(valor ?? '');
    return data == null
        ? 'Não informada'
        : DateFormat("dd/MM/yyyy 'às' HH:mm").format(data);
  }

  Future<DateTime?> _selecionarDataHora(DateTime? atual) async {
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: atual == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(atual),
    );
    if (hora == null) return null;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  Future<void> _editarDataGlobal(
    EventoLoteGlobal lote, {
    required bool inicio,
  }) async {
    final atual = DateTime.tryParse(
      inicio ? lote.inicioVendas ?? '' : lote.fimVendas ?? '',
    );
    final escolhida = await _selecionarDataHora(atual);
    if (escolhida == null) return;
    final inicioAtual = inicio
        ? escolhida
        : DateTime.tryParse(lote.inicioVendas ?? '');
    final fimAtual = inicio
        ? DateTime.tryParse(lote.fimVendas ?? '')
        : escolhida;
    if (inicioAtual != null &&
        fimAtual != null &&
        !fimAtual.isAfter(inicioAtual)) {
      if (mounted)
        AppSnackBar.aviso(
          context,
          'O fim das vendas deve ser posterior ao início.',
        );
      return;
    }
    try {
      final valor = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(escolhida);
      await _repo.atualizarGlobal(
        loteGlobalId: lote.id,
        inicioVendas: inicio ? valor : null,
        fimVendas: inicio ? null : valor,
      );
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          '${inicio ? 'Início' : 'Fim'} das vendas atualizado.',
        );
        _carregar();
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final respostas = await Future.wait([
        _repo.listarSetores(widget.eventoId),
        _repo.listarGlobais(widget.eventoId),
        _repo.obterCapacidadeEvento(widget.eventoId),
        _atracaoRepo.agenda(
          widget.lojaId,
          DateTime.tryParse(_eventoInicio ?? '') ?? DateTime.now(),
        ),
        _eventoRepo.obterEventoAgendado(widget.eventoId),
      ]);
      if (!mounted) return;
      final eventos = respostas[3] as List<AgendaEvento>;
      final evento = eventos.where((item) => item.eventoId == widget.eventoId);
      setState(() {
        _setores = respostas[0] as List<EventoSetor>;
        _globais = respostas[1] as List<EventoLoteGlobal>;
        _capacidade = respostas[2] as CapacidadeEvento;
        _atracoes = evento.expand((item) => item.atracoes).toList()
          ..sort((a, b) => a.inicio.compareTo(b.inicio));
        _evento = respostas[4] as Evento;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  int get _capacidadeEvento => _capacidade?.capacidadeTotal ?? 0;
  bool get _eventoPublicado =>
      (_evento?.statusevento ?? '').trim().toUpperCase() == 'ATIVO';

  bool get _eventoPassado {
    final data = DateTime.tryParse(
      _evento?.dtinicioevento ?? _eventoInicio ?? '',
    );
    if (data == null) return false;
    final hoje = DateTime.now();
    return DateTime(
      data.year,
      data.month,
      data.day,
    ).isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }

  bool get _somenteConsulta => widget.somenteConsulta || _eventoPassado;

  Future<void> _alternarPublicacao() async {
    if (_alterandoPublicacao) return;
    if (!_eventoPublicado && _globais.isEmpty) {
      setState(() => _aba = 3);
      AppSnackBar.erro(
        context,
        'Cadastre ao menos um lote global ativo e configurado para venda antes de publicar o evento.',
      );
      return;
    }
    setState(() => _alterandoPublicacao = true);
    try {
      final mensagem = _eventoPublicado
          ? await _eventoRepo.despublicarEvento(widget.eventoId)
          : await _eventoRepo.publicarEvento(widget.eventoId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, mensagem);
    } catch (erro) {
      if (!mounted) return;
      if (erroIndicaPendenteAsaas(erro)) {
        await mostrarDialogoAsaasPendente(context, recurso: 'este evento');
      } else {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
          duration: const Duration(seconds: 10),
          mostrarFechar: true,
        );
      }
    } finally {
      if (mounted) setState(() => _alterandoPublicacao = false);
    }
  }

  int get _capacidadeSetores => _setores
      .where((setor) => setor.situacao == 'ATIVO')
      .fold(0, (total, setor) => total + setor.capacidade);

  Future<void> _alterarCapacidade() async {
    final controller = TextEditingController(
      text: _capacidadeEvento.toString(),
    );
    final nova = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capacidade total do evento'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade máxima de pessoas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (nova == null || nova <= 0) return;
    try {
      await _repo.atualizarCapacidadeEvento(
        eventoId: widget.eventoId,
        capacidade: nova,
      );
      if (mounted) {
        AppSnackBar.sucesso(context, 'Capacidade total atualizada.');
        _carregar();
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _excluirData() async {
    final data = DateTime.tryParse(_eventoInicio ?? '');
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta data?'),
        content: Text(
          'O evento “$_eventoTitulo” será removido somente de ${data == null ? 'sua data agendada' : DateFormat('dd/MM/yyyy').format(data)}. O evento padrão e as demais datas não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir esta data'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _eventoRepo.excluirOcorrencia(widget.eventoId);
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _alterarHorarioEvento() async {
    final atual = DateTime.tryParse(_eventoInicio ?? '') ?? DateTime.now();
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(atual),
    );
    if (hora == null) return;
    final nova = DateTime(
      atual.year,
      atual.month,
      atual.day,
      hora.hour,
      hora.minute,
    );
    try {
      await _eventoRepo.atualizarHorarioEventoAgendado(
        eventoId: widget.eventoId,
        inicio: nova,
      );
      if (!mounted) return;
      setState(() => _eventoInicio = nova.toIso8601String());
      await _carregar();
      if (mounted)
        AppSnackBar.sucesso(context, 'Horário do evento atualizado.');
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _editarAtracao([EventoAtracao? atual]) async {
    final atracoes = await _atracaoRepo.listar();
    if (!mounted) return;
    if (atracoes.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Cadastre uma atração antes de incluí-la no evento.',
      );
      return;
    }

    var atracaoId = atual?.atracao.atracaoId ?? atracoes.first.atracaoId;
    var inicio =
        atual?.inicio ??
        (DateTime.tryParse(_eventoInicio ?? '') ?? DateTime.now());
    var fim = atual?.fim ?? inicio.add(const Duration(hours: 2));
    var salvando = false;
    final salvo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(atual == null ? 'Adicionar atração' : 'Editar atração'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: atracaoId,
                  decoration: const InputDecoration(
                    labelText: 'Atração',
                    border: OutlineInputBorder(),
                  ),
                  items: atracoes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.atracaoId,
                          child: Text(item.nome),
                        ),
                      )
                      .toList(),
                  onChanged: (valor) => atualizar(() => atracaoId = valor!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Início'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(inicio)),
                  onTap: () async {
                    final valor = await _selecionarDataHora(inicio);
                    if (valor != null) atualizar(() => inicio = valor);
                  },
                ),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.stop_rounded),
                  title: const Text('Fim'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(fim)),
                  onTap: () async {
                    final valor = await _selecionarDataHora(fim);
                    if (valor != null) atualizar(() => fim = valor);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (!fim.isAfter(inicio)) {
                        AppSnackBar.aviso(
                          context,
                          'O fim deve ser posterior ao início.',
                        );
                        return;
                      }
                      atualizar(() => salvando = true);
                      try {
                        if (atual == null) {
                          await _atracaoRepo.adicionar(
                            eventoId: widget.eventoId,
                            atracaoId: atracaoId,
                            inicio: inicio,
                            fim: fim,
                          );
                        } else {
                          await _atracaoRepo.atualizarProgramacao(
                            id: atual.programacaoId,
                            atracaoId: atracaoId,
                            inicio: inicio,
                            fim: fim,
                          );
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (erro) {
                        atualizar(() => salvando = false);
                        if (mounted)
                          AppSnackBar.erro(
                            this.context,
                            erro.toString().replaceFirst('Exception: ', ''),
                          );
                      }
                    },
              child: Text(salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvo == true && mounted) await _carregar();
  }

  Future<void> _removerAtracao(EventoAtracao atracao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover atração?'),
        content: Text(
          'Deseja remover a atração “${atracao.atracao.nome}” deste evento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _atracaoRepo.removerProgramacao(atracao.programacaoId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Atração removida do evento.');
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _editarNomeEvento() async {
    final nome = TextEditingController(text: _eventoTitulo);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome do evento'),
        content: TextField(
          controller: nome,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do evento'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nome.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    nome.dispose();
    if (novoNome == null || novoNome.isEmpty || novoNome == _eventoTitulo)
      return;
    try {
      await _eventoRepo.atualizarEventoAgendado(
        eventoId: widget.eventoId,
        titulo: novoNome,
      );
      if (mounted) {
        setState(() => _eventoTitulo = novoNome);
        AppSnackBar.sucesso(context, 'Nome do evento atualizado.');
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _editarFotoEvento() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (foto == null) return;
    try {
      final bytes = await foto.readAsBytes();
      await _eventoRepo.atualizarEventoAgendado(
        eventoId: widget.eventoId,
        titulo: _eventoTitulo,
        imagem: foto,
      );
      if (mounted) {
        setState(() => _bannerPreview = bytes);
        AppSnackBar.sucesso(context, 'Foto do evento atualizada.');
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _editarLocalEvento() async {
    final local = TextEditingController(text: _evento?.nmlocalevento ?? '');
    final endereco = TextEditingController(text: _evento?.dsendlocevento ?? '');
    final valores = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local do evento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: local,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome do local'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endereco,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Endereço do local',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              local.text.trim(),
              endereco.text.trim(),
            ]),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    local.dispose();
    endereco.dispose();
    if (valores == null) return;

    if (valores[0].isEmpty || valores[1].isEmpty) {
      if (mounted) {
        AppSnackBar.aviso(context, 'Informe o nome e o endereço do local.');
      }
      return;
    }

    try {
      await _eventoRepo.atualizarLocalEventoAgendado(
        eventoId: widget.eventoId,
        local: valores[0],
        endereco: valores[1],
      );
      if (mounted) {
        await _carregar();
        if (mounted) {
          AppSnackBar.sucesso(context, 'Local do evento atualizado.');
        }
      }
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  String? get _urlBanner {
    final banner = _eventoBanner?.trim() ?? '';
    if (banner.isEmpty) return null;
    if (banner.startsWith('http://') || banner.startsWith('https://'))
      return banner;
    return '${ApiConfig.baseUrl}${banner.startsWith('/') ? '' : '/'}$banner';
  }

  Future<void> _editarSetor(EventoSetor? existente) async {
    final nome = TextEditingController(text: existente?.nome ?? '');
    final descricao = TextEditingController(text: existente?.descricao ?? '');
    final capacidade = TextEditingController(
      text: existente?.capacidade.toString() ?? '',
    );
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existente == null ? 'Adicionar setor' : 'Editar setor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome do setor'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descricao,
              maxLength: 255,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição do setor',
                hintText: 'Ex.: área próxima ao palco, sem assentos marcados',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacidade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacidade máxima de pessoas',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final quantidade = int.tryParse(capacidade.text.trim());
              if (nome.text.trim().isEmpty ||
                  quantidade == null ||
                  quantidade <= 0)
                return;
              try {
                if (existente == null) {
                  await _repo.criarSetor(
                    eventoId: widget.eventoId,
                    nome: nome.text.trim(),
                    capacidade: quantidade,
                    descricao: descricao.text.trim(),
                  );
                } else {
                  await _repo.atualizarSetor(
                    setor: existente,
                    nome: nome.text.trim(),
                    capacidade: quantidade,
                    descricao: descricao.text.trim(),
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (erro) {
                if (context.mounted)
                  AppSnackBar.erro(
                    context,
                    erro.toString().replaceFirst('Exception: ', ''),
                  );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (resultado == true && mounted) _carregar();
  }

  Future<void> _excluirSetor(EventoSetor setor) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${setor.nome}?'),
        content: const Text(
          'O setor será removido do evento. A exclusão só é permitida quando ele não possui ingressos cadastrados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir setor'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirSetor(setor.id);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Setor excluído do evento.');
        _carregar();
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _novoLote() async {
    if (_setores.where((setor) => setor.situacao == 'ATIVO').isEmpty) {
      AppSnackBar.aviso(
        context,
        'Cadastre pelo menos um setor antes de criar o lote global.',
      );
      return;
    }
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          eventoTitulo: _eventoTitulo,
          eventoInicio: _eventoInicio,
          setores: _setores
              .where((setor) => setor.situacao == 'ATIVO')
              .toList(),
          proximoNumeroLote: _globais.length + 1,
        ),
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _editarLoteGlobal(EventoLoteGlobal lote) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          eventoTitulo: _eventoTitulo,
          eventoInicio: _eventoInicio,
          setores: _setores
              .where((setor) => setor.situacao == 'ATIVO')
              .toList(),
          proximoNumeroLote: lote.numero,
          loteGlobal: lote,
        ),
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _editarConfiguracao(EventoLote configuracao) async {
    final limite = TextEditingController(
      text: configuracao.qttotallote.toString(),
    );
    final precoInteira = configuracao.precos
        .where((preco) => preco.tipo == 'INTEIRA')
        .firstOrNull;
    final preco = TextEditingController(
      text: (precoInteira?.valor ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Lote ${configuracao.numeroLote} · ${configuracao.nomeSetor ?? 'Setor'}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: limite,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade vendida por este preço',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: preco,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Preço da inteira'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ao alterar a inteira, as modalidades existentes são mantidas. Edite cada modalidade no painel abaixo para alterar suas regras.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final quantidade = int.tryParse(limite.text.trim());
              if (quantidade == null || quantidade <= 0) return;
              try {
                final valor = double.tryParse(
                  preco.text.replaceAll('.', '').replaceAll(',', '.'),
                );
                final modalidades = configuracao.precos.map((item) {
                  if (item.tipo != 'INTEIRA' || valor == null) return item;
                  return EventoLotePreco(
                    id: item.id,
                    nome: item.nome,
                    tipo: item.tipo,
                    valor: valor,
                    aplicaCotaLegal: item.aplicaCotaLegal,
                    exigeComprovante: item.exigeComprovante,
                    situacao: item.situacao,
                    ordem: item.ordem,
                  );
                }).toList();
                await _repo.atualizarConfiguracaoSetor(
                  loteId: configuracao.loteId,
                  limite: quantidade,
                  precos: modalidades,
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (erro) {
                if (context.mounted)
                  AppSnackBar.erro(
                    context,
                    erro.toString().replaceFirst('Exception: ', ''),
                  );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _adicionarSetorAoLoteGlobal(EventoLoteGlobal lote) async {
    final setoresDisponiveis = _setores
        .where(
          (setor) =>
              setor.situacao == 'ATIVO' &&
              !lote.setores.any(
                (configuracao) => configuracao.eventoSetorId == setor.id,
              ),
        )
        .toList();
    if (setoresDisponiveis.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Todos os setores ativos já participam deste lote.',
      );
      return;
    }

    var setorId = setoresDisponiveis.first.id;
    final quantidade = TextEditingController(
      text: setoresDisponiveis.first.capacidade.toString(),
    );
    final preco = TextEditingController(text: '0,00');
    var salvando = false;
    final salvo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) {
          final setor = setoresDisponiveis.firstWhere(
            (item) => item.id == setorId,
          );
          return AlertDialog(
            title: Text('Adicionar setor ao ${lote.nome}'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey(setorId),
                      initialValue: setorId,
                      decoration: const InputDecoration(labelText: 'Setor'),
                      items: setoresDisponiveis
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) {
                        if (valor == null) return;
                        final selecionado = setoresDisponiveis.firstWhere(
                          (item) => item.id == valor,
                        );
                        atualizar(() {
                          setorId = valor;
                          quantidade.text = selecionado.capacidade.toString();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Capacidade do setor: ${setor.capacidade} pessoas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantidade,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade vendida por este preço',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: preco,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Preço da inteira',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Meia-entrada e Pessoa idosa serão criadas automaticamente a 50% do valor da inteira.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: salvando
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: salvando
                    ? null
                    : () async {
                        final limite = int.tryParse(quantidade.text.trim());
                        final inteira = double.tryParse(
                          preco.text.replaceAll('.', '').replaceAll(',', '.'),
                        );
                        if (limite == null ||
                            limite <= 0 ||
                            inteira == null ||
                            inteira < 0) {
                          AppSnackBar.aviso(
                            context,
                            'Informe a quantidade e o preço da inteira.',
                          );
                          return;
                        }
                        if (limite > setor.capacidade) {
                          AppSnackBar.aviso(
                            context,
                            'A quantidade não pode superar a capacidade do setor.',
                          );
                          return;
                        }
                        atualizar(() => salvando = true);
                        try {
                          await _repo.adicionarSetorAoGlobal(
                            loteGlobalId: lote.id,
                            setorId: setorId,
                            limite: limite,
                            precoInteira: inteira,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (erro) {
                          if (context.mounted) {
                            AppSnackBar.erro(
                              context,
                              erro.toString().replaceFirst('Exception: ', ''),
                            );
                          }
                          atualizar(() => salvando = false);
                        }
                      },
                icon: salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Adicionar setor'),
              ),
            ],
          );
        },
      ),
    );
    if (salvo == true && mounted) {
      AppSnackBar.sucesso(context, 'Setor adicionado ao lote global.');
      _carregar();
    }
  }

  Future<void> _excluirSetorDoLote(EventoLote configuracao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${configuracao.nomeSetor} deste lote?'),
        content: const Text(
          'Este setor deixará de vender ingressos somente neste lote global. Ele continuará cadastrado no evento e poderá participar dos próximos lotes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir setor do lote'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirSetorDoLote(configuracao.loteId);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Setor removido deste lote global.');
        _carregar();
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _editarModalidade(
    EventoLote configuracao,
    EventoLotePreco atual,
  ) async {
    final ingressoInteira = atual.tipo.trim().toUpperCase() == 'INTEIRA';
    final nome = TextEditingController(text: atual.nome);
    final valor = TextEditingController(
      text: atual.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    var usaCota = ingressoInteira ? false : atual.aplicaCotaLegal;
    var exigeComprovante = ingressoInteira ? false : atual.exigeComprovante;
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text('Editar ${atual.nome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(labelText: 'Modalidade'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Preço'),
                ),
                if (!ingressoInteira) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: usaCota,
                    onChanged: (novo) =>
                        atualizar(() => usaCota = novo ?? false),
                    title: const Text('Usa a cota legal de meia-entrada'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: exigeComprovante,
                    onChanged: (novo) =>
                        atualizar(() => exigeComprovante = novo ?? false),
                    title: const Text('Exige comprovante'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final preco = double.tryParse(
                  valor.text.replaceAll('.', '').replaceAll(',', '.'),
                );
                if (nome.text.trim().isEmpty || preco == null || preco < 0)
                  return;
                try {
                  final modalidades = configuracao.precos
                      .map(
                        (item) => item.id == atual.id
                            ? EventoLotePreco(
                                id: item.id,
                                nome: nome.text.trim(),
                                tipo: item.tipo,
                                valor: preco,
                                aplicaCotaLegal: ingressoInteira
                                    ? false
                                    : usaCota,
                                exigeComprovante: ingressoInteira
                                    ? false
                                    : exigeComprovante,
                                situacao: item.situacao,
                                ordem: item.ordem,
                              )
                            : item,
                      )
                      .toList();
                  await _repo.atualizarConfiguracaoSetor(
                    loteId: configuracao.loteId,
                    precos: modalidades,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (erro) {
                  if (context.mounted)
                    AppSnackBar.erro(
                      context,
                      erro.toString().replaceFirst('Exception: ', ''),
                    );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _excluirGlobal(EventoLoteGlobal lote) async {
    if (_eventoPublicado && _globais.length <= 1) {
      AppSnackBar.erro(
        context,
        'Não é possível excluir o último lote global de um evento publicado. Retire a publicação do evento antes de excluir este lote.',
        duration: const Duration(seconds: 8),
        mostrarFechar: true,
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${lote.nome}?'),
        content: const Text(
          'Todas as configurações de setor deste lote serão excluídas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirGlobal(lote.id);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Lote global excluído.');
        _carregar();
      }
    } catch (erro) {
      if (mounted)
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Widget _resumo() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _numero(
            'Setores',
            _setores
                .where((setor) => setor.situacao == 'ATIVO')
                .length
                .toString(),
            Icons.stadium_outlined,
          ),
          _numero(
            'Capacidade evento',
            '$_capacidadeEvento',
            Icons.groups_outlined,
            onEditar: _somenteConsulta ? null : _alterarCapacidade,
          ),
          _numero(
            'Capacidade dos setores',
            '$_capacidadeSetores',
            Icons.pie_chart_outline,
          ),
          _numero(
            'Faixas de preço',
            _globais.length.toString(),
            Icons.confirmation_number_outlined,
          ),
        ],
      ),
      const SizedBox(height: 18),
      ClubbarCard(
        child: Row(
          children: [
            const Icon(
              Icons.title_rounded,
              color: ClubbarColors.primariaEscuro,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nome do evento', style: TextStyle(fontSize: 12)),
                  Text(
                    _eventoTitulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (!_somenteConsulta)
              IconButton(
                onPressed: _editarNomeEvento,
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Editar nome do evento',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ClubbarCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.place_outlined,
              color: ClubbarColors.primariaEscuro,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local do evento', style: TextStyle(fontSize: 12)),
                  Text(
                    (_evento?.nmlocalevento ?? '').trim().isEmpty
                        ? 'Local não informado'
                        : _evento!.nmlocalevento!.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (_evento?.dsendlocevento ?? '').trim().isEmpty
                        ? 'Endereço não informado'
                        : _evento!.dsendlocevento!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (!_somenteConsulta)
              IconButton(
                onPressed: _editarLocalEvento,
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Editar local do evento',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ClubbarCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 74,
                height: 54,
                child: _bannerPreview != null
                    ? Image.memory(_bannerPreview!, fit: BoxFit.cover)
                    : _urlBanner != null
                    ? Image.network(
                        _urlBanner!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: ClubbarColors.primariaClaro,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                      )
                    : const ColoredBox(
                        color: ClubbarColors.primariaClaro,
                        child: Icon(Icons.image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Foto do evento', style: TextStyle(fontSize: 12)),
                  Text(
                    'Imagem exibida para o público',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (!_somenteConsulta)
              IconButton(
                onPressed: _editarFotoEvento,
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Editar foto do evento',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ClubbarCard(
        child: Row(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: ClubbarColors.primariaEscuro,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agendado para', style: TextStyle(fontSize: 12)),
                  Text(
                    _dataEvento,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (!_somenteConsulta)
              IconButton(
                onPressed: _alterarHorarioEvento,
                icon: const Icon(Icons.access_time_rounded, color: Colors.blue),
                tooltip: 'Alterar horário do evento',
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _matrizCapacidade(),
      const SizedBox(height: 14),
      _matrizPrecos(),
    ],
  );

  List<EventoSetor> get _setoresAtivos =>
      _setores.where((setor) => setor.situacao == 'ATIVO').toList()
        ..sort((a, b) => a.ordem.compareTo(b.ordem));

  EventoLote? _configuracaoDoSetor(EventoSetor setor, EventoLoteGlobal lote) {
    for (final configuracao in lote.setores) {
      if (configuracao.eventoSetorId == setor.id) return configuracao;
    }
    return null;
  }

  Widget _matrizCapacidade() => _cardMatriz(
    titulo: 'Quantidade por preço e setor',
    subtitulo:
        'Cada coluna mostra quantos ingressos do setor serão vendidos pelo preço daquele lote. A capacidade física permanece definida no setor.',
    child: _setoresAtivos.isEmpty || _globais.isEmpty
        ? const Text(
            'Cadastre setores e lotes globais para visualizar a matriz.',
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                ClubbarColors.primariaClaro,
              ),
              dataRowMinHeight: 54,
              columns: [
                const DataColumn(label: Text('Setor')),
                const DataColumn(label: Text('Capacidade')),
                ..._globais.map((lote) => DataColumn(label: Text(lote.nome))),
              ],
              rows: _setoresAtivos.map((setor) {
                final configuracoes = _globais
                    .map((lote) => _configuracaoDoSetor(setor, lote))
                    .toList();
                return DataRow(
                  cells: [
                    DataCell(Text(setor.nome)),
                    DataCell(Text('${setor.capacidade}')),
                    ...configuracoes.map(
                      (configuracao) => DataCell(
                        Text(
                          configuracao == null
                              ? '—'
                              : configuracao.usarCapacidadeRestante
                              ? 'Saldo'
                              : '${configuracao.qttotallote}',
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
  );

  Widget _matrizPrecos() => _cardMatriz(
    titulo: 'Matriz de preços',
    subtitulo: 'Preços de cada modalidade em cada faixa de preço e setor.',
    child: _setoresAtivos.isEmpty || _globais.isEmpty
        ? const Text(
            'Cadastre setores e lotes globais para visualizar a matriz.',
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                ClubbarColors.primariaClaro,
              ),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 128,
              columns: [
                const DataColumn(label: Text('Setor')),
                ..._globais.map((lote) => DataColumn(label: Text(lote.nome))),
              ],
              rows: _setoresAtivos.map((setor) {
                return DataRow(
                  cells: [
                    DataCell(Text(setor.nome)),
                    ..._globais.map(
                      (lote) => DataCell(
                        _precosDaConfiguracao(
                          _configuracaoDoSetor(setor, lote),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
  );

  Widget _precosDaConfiguracao(EventoLote? configuracao) {
    if (configuracao == null) return const Text('—');
    final precos =
        configuracao.precos.where((preco) => preco.situacao == 'ATIVO').toList()
          ..sort((a, b) => a.ordem.compareTo(b.ordem));
    if (precos.isEmpty) return const Text('Sem preço');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: precos
          .map(
            (preco) => Text(
              '${preco.nome}: ${_moeda.format(preco.valor)}',
              style: const TextStyle(fontSize: 12),
            ),
          )
          .toList(),
    );
  }

  Widget _cardMatriz({
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) => ClubbarCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitulo, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _abaSetores() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Setores do evento',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'A capacidade de cada setor é o limite real de ingressos. Os lotes apenas dividem essa venda em preços diferentes.',
      ),
      const SizedBox(height: 12),
      ..._setores.map(
        (setor) => ClubbarCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.stadium_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setor.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text('Capacidade máxima: ${setor.capacidade} pessoas'),
                    if (setor.descricao.trim().isNotEmpty)
                      Text(
                        setor.descricao.trim(),
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
              if (!_somenteConsulta) ...[
                IconButton(
                  onPressed: () => _editarSetor(setor),
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  tooltip: 'Editar setor',
                ),
                IconButton(
                  onPressed: () => _excluirSetor(setor),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: ClubbarColors.erro,
                  ),
                  tooltip: 'Excluir setor',
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  Widget _numero(
    String titulo,
    String valor,
    IconData icone, {
    VoidCallback? onEditar,
  }) => SizedBox(
    width: 205,
    child: ClubbarCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icone, color: ClubbarColors.primariaEscuro),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 11)),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onEditar != null)
            IconButton(
              onPressed: onEditar,
              icon: const Icon(
                Icons.edit_rounded,
                size: 19,
                color: Colors.blue,
              ),
              tooltip: 'Editar capacidade autorizada',
            ),
        ],
      ),
    ),
  );

  Widget _lotes() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Faixas de preço do evento',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'O primeiro lote começa quando o evento é publicado. O próximo preço entra automaticamente quando as quantidades do lote atual terminarem ou na data limite, o que ocorrer primeiro.',
      ),
      const SizedBox(height: 14),
      if (_globais.isEmpty)
        const ClubbarCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nenhuma faixa de preço cadastrada.'),
            ),
          ),
        ),
      ..._globais.map(_cardLoteGlobal),
    ],
  );

  Widget _abaAtracoes() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Atrações do evento',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Programe as atrações e informe o horário de início e fim de cada apresentação.',
      ),
      const SizedBox(height: 14),
      if (_atracoes.isEmpty)
        const ClubbarCard(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: Text('Nenhuma atração programada.')),
          ),
        ),
      ..._atracoes.asMap().entries.map(
        (entrada) => _cardAtracao(entrada.value, entrada.key),
      ),
    ],
  );

  Widget _cardAtracao(EventoAtracao atracao, int indice) => ClubbarCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: ClubbarColors.primariaClaro,
          child: Text(
            '${indice + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: _urlImagemAtracao(atracao) == null
                ? const ColoredBox(
                    color: ClubbarColors.primariaClaro,
                    child: Icon(Icons.music_note_rounded),
                  )
                : Image.network(
                    _urlImagemAtracao(atracao)!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: ClubbarColors.primariaClaro,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                atracao.atracao.nome,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Início: ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(atracao.inicio)}',
              ),
              Text(
                'Fim: ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(atracao.fim)}',
              ),
            ],
          ),
        ),
        if (!_somenteConsulta)
          Column(
            children: [
              IconButton(
                onPressed: () => _editarAtracao(atracao),
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Editar atração',
              ),
              IconButton(
                onPressed: () => _removerAtracao(atracao),
                icon: const Icon(
                  Icons.delete_outline,
                  color: ClubbarColors.erro,
                ),
                tooltip: 'Remover atração',
              ),
            ],
          ),
      ],
    ),
  );

  String? _urlImagemAtracao(EventoAtracao atracao) {
    final banner = atracao.atracao.banner?.trim() ?? '';
    if (banner.isEmpty) return null;
    if (banner.startsWith('http://') || banner.startsWith('https://'))
      return banner;
    return '${ApiConfig.baseUrl}${banner.startsWith('/') ? '' : '/'}$banner';
  }

  Widget _cardLoteGlobal(EventoLoteGlobal lote) => ClubbarCard(
    margin: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: ClubbarColors.primariaClaro,
              child: Text(
                '${lote.numero}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lote.nome,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!_somenteConsulta) ...[
              OutlinedButton.icon(
                onPressed: () => _excluirGlobal(lote),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir lote'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClubbarColors.erro,
                  side: const BorderSide(color: ClubbarColors.erro),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _editarLoteGlobal(lote),
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Editar lote global',
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _dataCard(
          Icons.schedule_rounded,
          'Data limite deste preço',
          lote.fimVendas == null || lote.fimVendas!.isEmpty
              ? 'Sem data: muda quando a quantidade terminar'
              : _data(lote.fimVendas),
          onEditar: _somenteConsulta
              ? null
              : () => _editarDataGlobal(lote, inicio: false),
        ),
        const SizedBox(height: 10),
        Text(
          'Mudança de preço: quando a quantidade desta etapa terminar ou na data limite, o que ocorrer primeiro.',
        ),
        const SizedBox(height: 10),
        const Text(
          'Setores do lote',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        ...lote.setores.map((configuracao) => _setorNoLote(configuracao)),
        if (!_somenteConsulta &&
            _setores.any(
              (setor) =>
                  setor.situacao == 'ATIVO' &&
                  !lote.setores.any(
                    (configuracao) => configuracao.eventoSetorId == setor.id,
                  ),
            ))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _adicionarSetorAoLoteGlobal(lote),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar setor a este lote'),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dataCard(
    IconData icone,
    String titulo,
    String valor, {
    VoidCallback? onEditar,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ClubbarColors.fundo,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ClubbarColors.borda),
    ),
    child: Row(
      children: [
        Icon(icone, color: ClubbarColors.primariaEscuro),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 11)),
              Text(valor, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.blue),
            tooltip: 'Alterar data e hora',
          ),
      ],
    ),
  );

  Widget _setorNoLote(EventoLote configuracao) => Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      border: Border.all(color: ClubbarColors.borda),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ExpansionTile(
      title: Text(
        configuracao.nomeSetor ?? 'Setor',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${configuracao.qttotallote} ingressos neste lote · ${configuracao.qtvendidalote} vendidos · ${configuracao.qtReservadaLote} reservados',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Tooltip(
            message: 'Toque no card para ver modalidades e preços',
            child: Icon(
              Icons.expand_more_rounded,
              color: ClubbarColors.primariaEscuro,
            ),
          ),
          const SizedBox(width: 4),
          if (!_somenteConsulta)
            IconButton(
              onPressed: () => _editarConfiguracao(configuracao),
              icon: const Icon(Icons.edit_rounded, color: Colors.blue),
              tooltip: 'Editar setor neste lote',
            ),
          if (!_somenteConsulta)
            IconButton(
              onPressed: () => _excluirSetorDoLote(configuracao),
              icon: const Icon(Icons.delete_outline, color: ClubbarColors.erro),
              tooltip: 'Excluir setor deste lote',
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            children: configuracao.precos
                .map(
                  (preco) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ClubbarColors.fundo,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preco.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!_somenteConsulta)
                              IconButton(
                                onPressed: () =>
                                    _editarModalidade(configuracao, preco),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Editar modalidade',
                              ),
                          ],
                        ),
                        Text('Preço: ${_moeda.format(preco.valor)}'),
                        Text(
                          preco.aplicaCotaLegal
                              ? 'Regra: usa a cota legal de meia-entrada'
                              : preco.exigeComprovante
                              ? 'Regra: comprovante obrigatório'
                              : 'Regra: sem exigência',
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: _aba,
    child: Scaffold(
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Nome Evento: $_eventoTitulo',
            subtitulo: _somenteConsulta
                ? 'Evento realizado — disponível somente para consulta'
                : '${_eventoPublicado ? 'Publicado' : 'Rascunho'} — gerencie evento, setores, lotes e preços',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          TabBar(
            onTap: (indice) => setState(() => _aba = indice),
            tabs: const [
              Tab(text: 'Resumo'),
              Tab(text: 'Atrações'),
              Tab(text: 'Setores'),
              Tab(text: 'Lotes globais'),
            ],
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(child: Text(_erro!))
                : _aba == 0
                ? _resumo()
                : _aba == 1
                ? _abaAtracoes()
                : _aba == 2
                ? _abaSetores()
                : _lotes(),
          ),
        ],
      ),
      bottomNavigationBar: ClubbarActionBar(
        actions: [
          if (!_somenteConsulta && _aba == 0)
            FilledButton.icon(
              onPressed: _carregando || _alterandoPublicacao
                  ? null
                  : _alternarPublicacao,
              icon: Icon(
                _eventoPublicado
                    ? Icons.visibility_off_outlined
                    : Icons.publish_outlined,
              ),
              label: Text(
                _alterandoPublicacao
                    ? 'Salvando...'
                    : _eventoPublicado
                    ? 'Retirar publicação'
                    : 'Publicar evento',
              ),
            ),
          if (!_somenteConsulta && _aba == 0)
            OutlinedButton.icon(
              onPressed: _excluirData,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir esta data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.erro,
              ),
            ),
          if (!_somenteConsulta && _aba == 3)
            ClubbarAddButton(
              label: 'Adicionar lote global',
              onPressed: _novoLote,
            ),
          if (!_somenteConsulta && _aba == 1)
            ClubbarAddButton(
              label: 'Adicionar atração',
              onPressed: () => _editarAtracao(),
            ),
          if (!_somenteConsulta && _aba == 2)
            ClubbarAddButton(
              label: 'Adicionar setor',
              onPressed: () => _editarSetor(null),
            ),
        ],
      ),
    ),
  );
}
