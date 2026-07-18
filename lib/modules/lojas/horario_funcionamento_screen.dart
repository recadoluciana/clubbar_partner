import 'package:flutter/material.dart';

/// Tela de edição do horário semanal da loja.
///
/// O callback [onSalvar] recebe uma lista pronta para ser enviada à API.
class HorarioFuncionamentoScreen extends StatefulWidget {
  final int lojaId;
  final List<Map<String, dynamic>> horariosIniciais;
  final Future<void> Function(List<Map<String, dynamic>> horarios) onSalvar;

  const HorarioFuncionamentoScreen({
    super.key,
    required this.lojaId,
    required this.onSalvar,
    this.horariosIniciais = const [],
  });

  @override
  State<HorarioFuncionamentoScreen> createState() =>
      _HorarioFuncionamentoScreenState();
}

class _HorarioFuncionamentoScreenState
    extends State<HorarioFuncionamentoScreen> {
  late final List<_HorarioDia> _horarios;
  bool _salvando = false;

  static const _verde = Color(0xFF35B866);
  static const _fundo = Color(0xFF080E18);
  static const _painel = Color(0xFF111927);
  static const _linha = Color(0xFF182231);

  @override
  void initState() {
    super.initState();
    _horarios = List.generate(7, (index) {
      final dia = index + 1;
      Map<String, dynamic>? inicial;
      for (final item in widget.horariosIniciais) {
        if (item['dia_semana'] == dia) {
          inicial = item;
          break;
        }
      }

      return _HorarioDia(
        diaSemana: dia,
        nome: const [
          'Segunda-feira',
          'Terça-feira',
          'Quarta-feira',
          'Quinta-feira',
          'Sexta-feira',
          'Sábado',
          'Domingo',
        ][index],
        fechado: inicial?['fechado'] == true || inicial == null,
        abertura: _horaDoTexto(inicial?['hora_abertura']?.toString()),
        fechamento: _horaDoTexto(inicial?['hora_fechamento']?.toString()),
      );
    });
  }

  static TimeOfDay? _horaDoTexto(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return null;
    return TimeOfDay(hour: hora, minute: minuto);
  }

  String _horaFormatada(TimeOfDay? hora) {
    if (hora == null) return '--:--';
    return '${hora.hour.toString().padLeft(2, '0')}:'
        '${hora.minute.toString().padLeft(2, '0')}';
  }

  int _minutos(TimeOfDay hora) => hora.hour * 60 + hora.minute;

  Future<void> _selecionarHora(_HorarioDia dia, bool abertura) async {
    if (dia.fechado) return;
    final atual = abertura ? dia.abertura : dia.fechamento;
    final selecionada = await showTimePicker(
      context: context,
      initialTime: atual ??
          (abertura
              ? const TimeOfDay(hour: 18, minute: 0)
              : const TimeOfDay(hour: 2, minute: 0)),
      helpText: abertura ? 'HORÁRIO DE ABERTURA' : 'HORÁRIO DE FECHAMENTO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _verde,
            surface: _painel,
          ),
        ),
        child: child!,
      ),
    );

    if (selecionada != null) {
      setState(() {
        if (abertura) {
          dia.abertura = selecionada;
        } else {
          dia.fechamento = selecionada;
        }
      });
    }
  }

  Future<void> _salvar() async {
    for (final dia in _horarios.where((item) => !item.fechado)) {
      if (dia.abertura == null || dia.fechamento == null) {
        _mostrarMensagem(
          'Informe a abertura e o fechamento de ${dia.nome}.',
          erro: true,
        );
        return;
      }
      if (_minutos(dia.abertura!) == _minutos(dia.fechamento!)) {
        _mostrarMensagem(
          'Em ${dia.nome}, abertura e fechamento não podem ser iguais.',
          erro: true,
        );
        return;
      }
    }

    final dados = _horarios.map((dia) {
      final cruzaMeiaNoite = !dia.fechado &&
          _minutos(dia.fechamento!) < _minutos(dia.abertura!);
      return <String, dynamic>{
        'loja_id': widget.lojaId,
        'dia_semana': dia.diaSemana,
        'fechado': dia.fechado,
        'hora_abertura': dia.fechado ? null : _horaFormatada(dia.abertura),
        'hora_fechamento': dia.fechado ? null : _horaFormatada(dia.fechamento),
        'fechamento_dia_seguinte': cruzaMeiaNoite,
      };
    }).toList();

    setState(() => _salvando = true);
    try {
      await widget.onSalvar(dados);
      if (mounted) {
        _mostrarMensagem('Horários salvos com sucesso.');
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensagem('Não foi possível salvar os horários: $e', erro: true);
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarMensagem(String texto, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: erro ? Colors.red.shade700 : Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: _fundo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Horário de funcionamento'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _painel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cabecalho(),
                      const SizedBox(height: 18),
                      Divider(color: Colors.white.withValues(alpha: .08)),
                      const SizedBox(height: 14),
                      const Text(
                        'Defina os horários do seu estabelecimento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Nos dias em que a loja não funciona, marque como “Fechado”.',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 16),
                      ..._horarios.map(_linhaDia),
                      const SizedBox(height: 10),
                      _rodape(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecalho() => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconeVerde(icone: Icons.access_time_rounded, tamanho: 46),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horário de Funcionamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Informe os dias da semana e os respectivos horários da sua loja.',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _linhaDia(_HorarioDia dia) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _linha,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < 680;
          final horarios = Row(
            children: [
              Expanded(child: _campoHora(dia, true)),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
                child: Text('até', style: TextStyle(color: Colors.white70)),
              ),
              Expanded(child: _campoHora(dia, false)),
            ],
          );

          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _nomeDia(dia)),
                    _fechado(dia),
                  ],
                ),
                if (!dia.fechado) ...[
                  const SizedBox(height: 9),
                  horarios,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: _nomeDia(dia)),
              Expanded(flex: 5, child: horarios),
              const SizedBox(width: 20),
              SizedBox(width: 115, child: _fechado(dia)),
            ],
          );
        },
      ),
    );
  }

  Widget _nomeDia(_HorarioDia dia) => Text(
        dia.nome,
        style: TextStyle(
          color: dia.fechado ? Colors.white54 : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _campoHora(_HorarioDia dia, bool abertura) {
    final hora = abertura ? dia.abertura : dia.fechamento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          abertura ? 'Abertura' : 'Fechamento',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 3),
        InkWell(
          onTap: () => _selecionarHora(dia, abertura),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1420),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 17, color: Colors.white60),
                const SizedBox(width: 8),
                Text(
                  _horaFormatada(hora),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fechado(_HorarioDia dia) => CheckboxListTile(
        value: dia.fechado,
        onChanged: (valor) => setState(() => dia.fechado = valor ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: _verde,
        side: const BorderSide(color: Colors.white54),
        title: const Text(
          'Fechado',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      );

  Widget _rodape() => LayoutBuilder(
        builder: (context, constraints) {
          final dica = const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: _verde, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Você pode alterar esses horários quando quiser.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          );
          final botao = FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Salvar horários'),
            style: FilledButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [dica, const SizedBox(height: 14), botao],
            );
          }
          return Row(
            children: [Expanded(child: dica), const SizedBox(width: 16), botao],
          );
        },
      );
}

class _IconeVerde extends StatelessWidget {
  final IconData icone;
  final double tamanho;

  const _IconeVerde({required this.icone, required this.tamanho});

  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: const Color(0xFF35B866).withValues(alpha: .13),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icone, color: const Color(0xFF35B866)),
      );
}

class _HorarioDia {
  final int diaSemana;
  final String nome;
  bool fechado;
  TimeOfDay? abertura;
  TimeOfDay? fechamento;

  _HorarioDia({
    required this.diaSemana,
    required this.nome,
    required this.fechado,
    this.abertura,
    this.fechamento,
  });
}
