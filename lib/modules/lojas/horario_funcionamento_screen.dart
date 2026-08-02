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

  const HorarioFuncionamentoScreen({
    super.key,
    required this.lojaId,
    required this.nomeLoja,
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
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_carregando && _horarios.isNotEmpty) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
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

    _atualizarDia(
      index,
      abertura
          ? atual.copyWith(horaAbertura: selecionada)
          : atual.copyWith(horaFechamento: selecionada),
    );
  }

  String? _validar() {
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

      if (_minutos(horario.horaAbertura!) ==
          _minutos(horario.horaFechamento!)) {
        return 'Em ${horario.nomeDiaSemana}, abertura e fechamento '
            'não podem ser iguais.';
      }
    }

    return null;
  }

  Future<void> _salvar() async {
    if (_salvando) return;

    final erro = _validar();
    if (erro != null) {
      AppSnackBar.aviso(context, erro);
      return;
    }

    setState(() => _salvando = true);

    try {
      await _repository.salvarTodos(widget.lojaId, _horarios);
      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Horários salvos com sucesso.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _limparErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  int _minutos(TimeOfDay horario) => horario.hour * 60 + horario.minute;

  String _formatarHora(TimeOfDay? horario) {
    if (horario == null) return '--:--';
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
          _formatarHora(valor),
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
            SwitchListTile(
              value: horario.fechaDiaSeguinte,
              onChanged: _salvando
                  ? null
                  : (value) => _atualizarDia(
                      index,
                      horario.copyWith(fechaDiaSeguinte: value),
                    ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Fecha no dia seguinte',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: horario.fechaDiaSeguinte
                  ? Text(
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
        ...List.generate(_horarios.length, _cardDia),
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
            label: Text(_salvando ? 'Salvando...' : 'Salvar horários'),
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
