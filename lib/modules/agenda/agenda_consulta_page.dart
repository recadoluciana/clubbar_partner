import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import '../../models/loja.dart';

class AgendaConsultaPage extends StatefulWidget {
  final int organizacaoId;
  const AgendaConsultaPage({super.key, required this.organizacaoId});
  @override
  State<AgendaConsultaPage> createState() => _AgendaConsultaPageState();
}

class _AgendaConsultaPageState extends State<AgendaConsultaPage> {
  static const _clubbarAppUrl = 'https://app.clubbar.com.br';
  static const _tamanhoImagem = 128.0;
  final _repo = AtracaoRepository(), _lojaRepo = LojaRepository();
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<Loja> _lojas = [];
  List<AgendaEvento> _eventos = [];
  int? _lojaId;
  bool _loading = true;
  String? _erro;
  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  @override
  void initState() {
    super.initState();
    _init();
  }

  Loja? get _loja {
    for (final l in _lojas) {
      if (l.lojaId == _lojaId) return l;
    }
    return null;
  }

  Future<void> _init() async {
    try {
      final ls = await _lojaRepo.listar(widget.organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = ls;
        _lojaId = ls.isEmpty ? null : ls.first.lojaId;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    if (_lojaId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final x = await _repo.agenda(_lojaId!, _mes);
      if (mounted) {
        setState(() {
          _eventos = x.where((e) => e.status.toUpperCase() == 'ATIVO').toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _month(int d) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + d));
    _load();
  }

  List<_Ocorrencia> get _ocorrencias {
    final out = <_Ocorrencia>[];
    for (final e in _eventos) {
      final porDia = <DateTime, List<EventoAtracao>>{};
      for (final a in e.atracoes) {
        if (a.inicio.year != _mes.year || a.inicio.month != _mes.month) {
          continue;
        }
        final d = DateTime(a.inicio.year, a.inicio.month, a.inicio.day);
        porDia.putIfAbsent(d, () => []).add(a);
      }
      if (porDia.isEmpty &&
          e.inicio.year == _mes.year &&
          e.inicio.month == _mes.month) {
        out.add(_Ocorrencia(e, e.inicio, const []));
      } else {
        for (final item in porDia.entries) {
          item.value.sort((a, b) => a.inicio.compareTo(b.inicio));
          out.add(_Ocorrencia(e, item.value.first.inicio, item.value));
        }
      }
    }
    out.sort((a, b) => a.inicio.compareTo(b.inicio));
    return out;
  }

  String? _imagem(_Ocorrencia o) {
    final ev = o.evento.bannerEvento?.trim() ?? '';
    if (ev.isNotEmpty) return _url(ev);
    for (final a in o.atracoes) {
      final x = a.atracao.banner?.trim() ?? '';
      if (x.isNotEmpty) return _url(x);
    }
    return null;
  }

  String _url(String x) => x.startsWith('http')
      ? x
      : '${ApiConfig.baseUrl}${x.startsWith('/') ? '' : '/'}$x';
  String _texto() {
    final l = _loja;
    final cidade = l?.nmcidade?.trim();
    final b = StringBuffer(
      'Veja a agenda do ${l?.nmloja ?? 'estabelecimento'}${cidade?.isNotEmpty == true ? ' em $cidade' : ''} para o mês de ${_meses[_mes.month - 1]}:\n\n',
    );
    for (final o in _ocorrencias) {
      b.writeln(
        '${DateFormat('dd/MM').format(o.inicio)} - ${_semana(o.inicio)} às ${DateFormat('HH:mm').format(o.inicio)}',
      );
      if (o.atracoes.isEmpty) {
        b.writeln(o.evento.titulo);
      } else {
        for (final a in o.atracoes) {
          final estilo = a.atracao.estiloMusical?.trim();
          b.writeln(
            '• ${a.atracao.nome}${estilo?.isNotEmpty == true ? ', $estilo' : ''} (${DateFormat('HH:mm').format(a.inicio)}–${DateFormat('HH:mm').format(a.fim)})',
          );
        }
      }
      b.writeln();
    }
    b
      ..writeln('Compre seu ingresso digital pelo Clubbar App:')
      ..writeln(_clubbarAppUrl)
      ..writeln()
      ..writeln(
        'Cadastre-se para comprar. Seu ingresso ficará na carteira digital do aplicativo e deverá ser apresentado pelo QR Code na portaria do local.',
      );
    return b.toString().trim();
  }

  String _semana(DateTime d) =>
      const ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'][d.weekday - 1];
  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _texto()));
    if (mounted) {
      AppSnackBar.sucesso(
        context,
        'Agenda copiada. Cole no WhatsApp, Instagram ou onde desejar.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _ocorrencias.isEmpty ? null : _share,
      icon: const Icon(Icons.share),
      label: const Text('Compartilhar'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Agenda para Compartilhar',
            subtitulo: _loja?.nmloja ?? 'Agenda mensal',
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _lojaId,
                    decoration: const InputDecoration(
                      labelText: 'Estabelecimento',
                      border: OutlineInputBorder(),
                    ),
                    items: _lojas
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.lojaId,
                            child: Text(l.nmloja),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _lojaId = v);
                      _load();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => _month(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_meses[_mes.month - 1]} ${_mes.year}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => _month(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(child: Text(_erro!))
                : _ocorrencias.isEmpty
                ? const Center(child: Text('Nenhum evento ativo neste mês.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                    itemCount: _ocorrencias.length,
                    itemBuilder: (c, i) => _card(_ocorrencias[i]),
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _card(_Ocorrencia o) {
    final img = _imagem(o);
    final detalhes = o.atracoes.map((a) {
      final estilo = a.atracao.estiloMusical?.trim() ?? '';
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${a.atracao.nome}${estilo.isNotEmpty ? ' • $estilo' : ''}\n${DateFormat('HH:mm').format(a.inicio)}–${DateFormat('HH:mm').format(a.fim)}',
          style: const TextStyle(height: 1.25),
        ),
      );
    }).toList();
    final placeholder = ColoredBox(
      color: ClubbarColors.ambarClaro,
      child: const Center(child: Icon(Icons.event, size: 42)),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _tamanhoImagem,
            height: _tamanhoImagem,
            child: img == null
                ? placeholder
                : ClipRect(
                    child: Image.network(
                      img,
                      width: _tamanhoImagem,
                      height: _tamanhoImagem,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('dd/MM').format(o.inicio)} - ${_semana(o.inicio)} às ${DateFormat('HH:mm').format(o.inicio)}',
                    style: const TextStyle(
                      color: ClubbarColors.ambarEscuro,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    o.evento.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  ...detalhes,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ocorrencia {
  final AgendaEvento evento;
  final DateTime inicio;
  final List<EventoAtracao> atracoes;
  const _Ocorrencia(this.evento, this.inicio, this.atracoes);
}
