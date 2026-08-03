import 'package:flutter/material.dart';

import '../../core/repositories/loja_horario_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja_horario.dart';

class HorarioFuncionamentoScreen extends StatefulWidget {
  final int lojaId;
  final String nomeLoja;
  final String aberto24x7Inicial;
  final Future<void> Function(String aberto24x7) onSalvarAberto24x7;

  const HorarioFuncionamentoScreen({
    super.key,
    required this.lojaId,
    required this.nomeLoja,
    required this.aberto24x7Inicial,
    required this.onSalvarAberto24x7,
  });

  @override
  State<HorarioFuncionamentoScreen> createState() =>
      _HorarioFuncionamentoScreenState();
}

class _HorarioFuncionamentoScreenState
    extends State<HorarioFuncionamentoScreen> {
  final LojaHorarioRepository _repository = LojaHorarioRepository();

  List<LojaHorario> _horarios = const [];
  bool _carregando = true;
  bool _salvando = false;
  late String _aberto24x7;
  String? _erro;

  bool get _funciona24x7 => _aberto24x7 == 'S';

  @override
  void initState() {
    super.initState();
    _aberto24x7 = widget.aberto24x7Inicial == 'S' ? 'S' : 'N';
    _carregar();
  }

  Future<void> _carregar() async {
    if (_carregando && _horarios.isNotEmpty) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (_funciona24x7) {
        setState(() {
          _horarios = _completarSemana(const []);
          _carregando = false;
        });
        return;
      }

      final recebidos = await _repository.buscarPorLoja(widget.lojaId);
      if (!mounted) return;

      setState(() {
        _horarios = _completarSemana(recebidos);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
        _erro = _limparErro(e);
      });
    }
  }

  List<LojaHorario> _completarSemana(List<LojaHorario> recebidos) {
    return List.generate(7, (index) {
      final diaSemana = index + 1;

      for (final horario in recebidos) {
        if (horario.diaSemana == diaSemana) {
          return horario.copyWith(lojaId: widget.lojaId);
        }
      }

      return LojaHorario(
        lojaId: widget.lojaId,
        diaSemana: diaSemana,
        fechado: true,
      );
    });
  }

  void _atualizarDia(int index, LojaHorario horario) {
    setState(() {
      final atualizados = List<LojaHorario>.from(_horarios);
      atualizados[index] = horario;
      _horarios = atualizados;
    });
  }

  LojaHorario _ajustarFechaDiaSeguinte(LojaHorario horario) {
    final abertura = horario.horaAbertura;
    final fechamento = horario.horaFechamento;
    if (horario.fechado || abertura == null || fechamento == null) {
      return horario;
    }

    final fechaDiaSeguinte =
        !horario.fechamentoMeiaNoite &&
        _minutos(fechamento) < _minutos(abertura);
    return horario.copyWith(fechaDiaSeguinte: fechaDiaSeguinte);
  }

  void _alterarAberto(int index, bool aberto) {
    final atual = _horarios[index];

    _atualizarDia(
      index,
      atual.copyWith(fechado: !aberto, limparHorarios: !aberto),
    );
  }

  Future<void> _selecionarHora(int index, {required bool abertura}) async {
    final atual = _horarios[index];
    if (atual.fechado || _salvando) return;

    final horaAtual = abertura ? atual.horaAbertura : atual.horaFechamento;
    final selecionada = await showTimePicker(
      context: context,
      initialTime:
          horaAtual ??
          (abertura
              ? const TimeOfDay(hour: 18, minute: 0)
              : const TimeOfDay(hour: 2, minute: 0)),
      helpText: abertura ? 'HORÁRIO DE ABERTURA' : 'HORÁRIO DE FECHAMENTO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ClubbarColors.ambar,
              brightness: Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selecionada == null || !mounted) return;

    final atualizado = abertura
        ? atual.copyWith(horaAbertura: selecionada)
        : atual.copyWith(
            horaFechamento: selecionada,
            fechamentoMeiaNoite: false,
          );
    _atualizarDia(index, _ajustarFechaDiaSeguinte(atualizado));
  }

  void _definirFechamento24Horas(int index) {
    final atual = _horarios[index];
    if (atual.fechado || _salvando) return;

    _atualizarDia(
      index,
      atual.copyWith(
        horaFechamento: const TimeOfDay(hour: 0, minute: 0),
        fechamentoMeiaNoite: true,
        fechaDiaSeguinte: false,
      ),
    );
  }

  String? _validar() {
    if (_funciona24x7) return null;

    if (_horarios.length != 7) {
      return 'Não foi possível montar os sete dias da semana.';
    }

    for (final horario in _horarios.where((item) => !item.fechado)) {
      if (horario.horaAbertura == null) {
        return 'Informe a abertura de ${horario.nomeDiaSemana}.';
      }

      if (horario.horaFechamento == null) {
        return 'Informe o fechamento de ${horario.nomeDiaSemana}.';
      }

      final minutosFechamento = horario.fechamentoMeiaNoite
          ? 24 * 60
          : _minutos(horario.horaFechamento!);
      if (_minutos(horario.horaAbertura!) == minutosFechamento) {
        return 'Em ${horario.nomeDiaSemana}, abertura e fechamento '
            'não podem ser iguais.';
      }
    }

    return null;
  }

  Future<void> _salvar() async {
    if (_salvando) return;

    final horariosNormalizados = _horarios
        .map(_ajustarFechaDiaSeguinte)
        .toList();
    if (!_funciona24x7) {
      setState(() => _horarios = horariosNormalizados);
    }

    final erro = _validar();
    if (erro != null) {
      AppSnackBar.aviso(context, erro);
      return;
    }

    setState(() => _salvando = true);

    try {
      await widget.onSalvarAberto24x7(_aberto24x7);
      if (!_funciona24x7) {
        await _repository.salvarTodos(widget.lojaId, horariosNormalizados);
      }
      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        _funciona24x7
            ? 'Loja configurada como aberta 24 horas.'
            : 'Horários salvos com sucesso.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _limparErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  int _minutos(TimeOfDay horario) => horario.hour * 60 + horario.minute;

  String _formatarHora(TimeOfDay? horario, {bool fechamentoMeiaNoite = false}) {
    if (horario == null) return '--:--';
    if (fechamentoMeiaNoite) return '24:00';
    return '${horario.hour.toString().padLeft(2, '0')}:'
        '${horario.minute.toString().padLeft(2, '0')}';
  }

  String _limparErro(Object erro) {
    return erro.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Widget _estadoCarregando() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: ClubbarColors.ambar),
      ),
    );
  }

  Widget _estadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClubbarCard(
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 46,
                  color: ClubbarColors.erro,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível carregar os horários',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _erro ?? 'Tente novamente.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ClubbarColors.textoSecundario),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ClubbarColors.ambar,
                    foregroundColor: ClubbarColors.preto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoHora(int index, {required bool abertura}) {
    final horario = _horarios[index];
    final valor = abertura ? horario.horaAbertura : horario.horaFechamento;

    return InkWell(
      onTap: horario.fechado || _salvando
          ? null
          : () => _selecionarHora(index, abertura: abertura),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: abertura ? 'Abertura' : 'Fechamento',
          prefixIcon: const Icon(Icons.schedule_rounded),
          enabled: !horario.fechado && !_salvando,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          _formatarHora(
            valor,
            fechamentoMeiaNoite: !abertura && horario.fechamentoMeiaNoite,
          ),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: horario.fechado
                ? ClubbarColors.textoDesabilitado
                : ClubbarColors.textoPrincipal,
          ),
        ),
      ),
    );
  }

  Widget _cardDia(int index) {
    final horario = _horarios[index];
    final fechamentoAposMeiaNoite =
        !horario.fechamentoMeiaNoite &&
        horario.horaAbertura != null &&
        horario.horaFechamento != null &&
        _minutos(horario.horaFechamento!) < _minutos(horario.horaAbertura!);

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  horario.nomeDiaSemana,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),
              ),
              Text(
                horario.fechado ? 'Fechado' : 'Aberto',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: horario.fechado
                      ? ClubbarColors.textoSecundario
                      : ClubbarColors.sucesso,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: !horario.fechado,
                onChanged: _salvando
                    ? null
                    : (aberto) => _alterarAberto(index, aberto),
                activeTrackColor: ClubbarColors.sucesso,
              ),
            ],
          ),
          if (!horario.fechado) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final abertura = _campoHora(index, abertura: true);
                final fechamento = _campoHora(index, abertura: false);

                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      abertura,
                      const SizedBox(height: 12),
                      fechamento,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: abertura),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'até',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ClubbarColors.textoSecundario,
                        ),
                      ),
                    ),
                    Expanded(child: fechamento),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _salvando
                    ? null
                    : () => _definirFechamento24Horas(index),
                icon: const Icon(Icons.nights_stay_outlined, size: 18),
                label: const Text('Fechar às 24:00'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: horario.fechamentoMeiaNoite
                      ? ClubbarColors.ambarEscuro
                      : ClubbarColors.textoPrincipal,
                  side: BorderSide(
                    color: horario.fechamentoMeiaNoite
                        ? ClubbarColors.ambar
                        : ClubbarColors.borda,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              value: horario.fechaDiaSeguinte,
              onChanged: _salvando
                  ? null
                  : (value) => _atualizarDia(
                      index,
                      horario.copyWith(
                        fechaDiaSeguinte: value,
                        fechamentoMeiaNoite: value
                            ? false
                            : horario.fechamentoMeiaNoite,
                      ),
                    ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Fecha no dia seguinte',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: horario.fechaDiaSeguinte
                  ? Text(
                      '${fechamentoAposMeiaNoite ? 'Marcado automaticamente. ' : ''}'
                      'Exemplo: ${_formatarHora(horario.horaAbertura)} até '
                      '${_formatarHora(horario.horaFechamento)} do dia seguinte',
                    )
                  : null,
              activeTrackColor: ClubbarColors.ambar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _conteudo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const ClubbarCard(
          elevation: 0,
          backgroundColor: ClubbarColors.infoClaro,
          borderColor: ClubbarColors.infoClaro,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: ClubbarColors.info),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ative os dias de atendimento e informe abertura e '
                  'fechamento. Para horários como 18:00 até 02:00, marque '
                  '“Fecha no dia seguinte”.',
                  style: TextStyle(color: ClubbarColors.textoPrincipal),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClubbarCard(
          elevation: 0,
          borderColor: _funciona24x7 ? ClubbarColors.erro : ClubbarColors.borda,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _funciona24x7,
            onChanged: _salvando
                ? null
                : (value) {
                    setState(() => _aberto24x7 = value ? 'S' : 'N');
                  },
            activeTrackColor: ClubbarColors.erro,
            title: const Text(
              'Aberto 24 horas',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              _funciona24x7
                  ? 'A loja funciona todos os dias, durante 24 horas.'
                  : 'Ative para não precisar informar horários por dia.',
            ),
            secondary: const Icon(
              Icons.all_inclusive_rounded,
              color: ClubbarColors.erro,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (!_funciona24x7) ...List.generate(_horarios.length, _cardDia),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _salvando
                  ? 'Salvando...'
                  : _funciona24x7
                  ? 'Salvar funcionamento 24 horas'
                  : 'Salvar horários',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ClubbarColors.ambar,
              foregroundColor: ClubbarColors.preto,
              disabledBackgroundColor: ClubbarColors.ambarClaro,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
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
              titulo: 'Horário de funcionamento',
              subtitulo: widget.nomeLoja,
            ),
            Expanded(
              child: _carregando
                  ? _estadoCarregando()
                  : _erro != null
                  ? _estadoErro()
                  : _conteudo(),
            ),
          ],
        ),
      ),
    );
  }
}
