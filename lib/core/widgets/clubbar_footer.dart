import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/storage_service.dart';
import '../theme/clubbar_colors.dart';

class ClubbarFooter extends StatefulWidget {
  const ClubbarFooter({super.key});

  @override
  State<ClubbarFooter> createState() => _ClubbarFooterState();
}

class _ClubbarFooterState extends State<ClubbarFooter> {
  String _nomeUsuario = 'Usuário';
  String _cargo = 'Usuário';

  DateTime _agora = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _carregarUsuario();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _agora = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarUsuario() async {
    final nomeUsuario = await StorageService.getNomeUsuario();
    final cargo = await StorageService.getCargo();

    if (!mounted) return;

    setState(() {
      _nomeUsuario = nomeUsuario?.trim().isNotEmpty == true
          ? nomeUsuario!.trim()
          : 'Usuário';

      _cargo = _formatarCargo(
        cargo?.trim().isNotEmpty == true ? cargo!.trim() : 'Usuário',
      );
    });
  }

  String _formatarCargo(String valor) {
    final texto = valor.trim().replaceAll('_', ' ').toLowerCase();

    if (texto.isEmpty) return 'Usuário';

    return texto
        .split(' ')
        .where((parte) => parte.isNotEmpty)
        .map((parte) => '${parte[0].toUpperCase()}${parte.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final data = DateFormat('dd/MM/yyyy', 'pt_BR').format(_agora);

    final hora = DateFormat('HH:mm:ss', 'pt_BR').format(_agora);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        color: ClubbarColors.ambar,
        border: Border(
          top: BorderSide(color: ClubbarColors.ambarEscuro, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_rounded,
            size: 17,
            color: ClubbarColors.preto,
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              '$_nomeUsuario • $_cargo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ClubbarColors.preto,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(width: 8),

          const Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: ClubbarColors.preto,
          ),

          const SizedBox(width: 4),

          Text(
            data,
            style: const TextStyle(
              color: ClubbarColors.preto,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(width: 8),

          const Icon(
            Icons.schedule_rounded,
            size: 15,
            color: ClubbarColors.preto,
          ),

          const SizedBox(width: 4),

          Text(
            hora,
            style: const TextStyle(
              color: ClubbarColors.preto,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
