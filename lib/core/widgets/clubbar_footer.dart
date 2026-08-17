import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../repositories/loja_repository.dart';
import '../services/storage_service.dart';
import '../theme/clubbar_colors.dart';

class ClubbarFooter extends StatefulWidget {
  const ClubbarFooter({super.key});

  static final ValueNotifier<bool> visibility = ValueNotifier<bool>(true);

  @override
  State<ClubbarFooter> createState() => _ClubbarFooterState();
}

class _ClubbarFooterState extends State<ClubbarFooter> {
  String _nomeUsuario = 'Usuário';
  String _cargo = 'Usuário';
  String _nomeLoja = 'Todas as lojas';

  DateTime _agora = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _carregarUsuario();
    StorageService.sessaoAlterada.addListener(_carregarUsuario);

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
    StorageService.sessaoAlterada.removeListener(_carregarUsuario);
    super.dispose();
  }

  Future<void> _carregarUsuario() async {
    final dados = await Future.wait<dynamic>([
      StorageService.getNomeUsuario(),
      StorageService.getCargo(),
      StorageService.getLojaId(),
      StorageService.getOrganizacaoId(),
    ]);
    final nomeUsuario = dados[0] as String?;
    final cargo = dados[1] as String?;
    final lojaId = dados[2] as int?;
    final organizacaoId = dados[3] as int?;
    var nomeLoja = 'Todas as lojas';

    if (lojaId != null && lojaId > 0 && organizacaoId != null) {
      try {
        final lojas = await LojaRepository().listar(organizacaoId);
        nomeLoja = lojas
            .where((loja) => loja.lojaId == lojaId)
            .map((loja) => loja.nmloja.trim())
            .firstWhere(
              (nome) => nome.isNotEmpty,
              orElse: () => 'Loja #$lojaId',
            );
      } catch (_) {
        nomeLoja = 'Loja #$lojaId';
      }
    }

    if (!mounted) return;
    setState(() {
      _nomeUsuario = nomeUsuario?.trim().isNotEmpty == true
          ? nomeUsuario!.trim()
          : 'Usuário';
      _cargo = _formatarCargo(
        cargo?.trim().isNotEmpty == true ? cargo!.trim() : 'Usuário',
      );
      _nomeLoja = nomeLoja;
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

    return ColoredBox(
      color: ClubbarColors.preto,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: const BoxDecoration(
            color: ClubbarColors.preto,
            border: Border(
              top: BorderSide(color: ClubbarColors.branco, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 17,
                color: ClubbarColors.branco,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  '$_nomeUsuario • $_cargo • $_nomeLoja',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ClubbarColors.branco,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: ClubbarColors.branco,
              ),

              const SizedBox(width: 4),

              Text(
                data,
                style: const TextStyle(
                  color: ClubbarColors.branco,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: ClubbarColors.branco,
              ),

              const SizedBox(width: 4),

              Text(
                hora,
                style: const TextStyle(
                  color: ClubbarColors.branco,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
