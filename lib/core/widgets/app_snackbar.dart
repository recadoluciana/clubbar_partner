import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class AppSnackBar {
  AppSnackBar._();

  static void sucesso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      cor: ClubbarColors.sucesso,
      icone: Icons.check_circle_rounded,
    );
  }

  static void erro(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      cor: ClubbarColors.erro,
      icone: Icons.error_rounded,
    );
  }

  static void aviso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      cor: ClubbarColors.aviso,
      icone: Icons.warning_amber_rounded,
      corTexto: Colors.black,
    );
  }

  static void info(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      cor: ClubbarColors.info,
      icone: Icons.info_rounded,
    );
  }

  static void _mostrar(
    BuildContext context,
    String mensagem, {
    required Color cor,
    required IconData icone,
    Color corTexto = Colors.white,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cor,
          elevation: 4,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(icone, color: corTexto, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style: TextStyle(
                    color: corTexto,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
