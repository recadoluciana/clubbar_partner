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

    final larguraTela = MediaQuery.sizeOf(context).width;
    final celular = larguraTela < 600;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: celular
              ? SnackBarBehavior.fixed
              : SnackBarBehavior.floating,
          width: celular ? null : 520,
          backgroundColor: cor,
          elevation: 8,
          duration: const Duration(seconds: 4),
          dismissDirection: DismissDirection.down,
          showCloseIcon: true,
          closeIconColor: corTexto,
          shape: RoundedRectangleBorder(
            borderRadius: celular
                ? const BorderRadius.vertical(top: Radius.circular(18))
                : BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          content: Row(
            children: [
              Icon(icone, color: corTexto, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style: TextStyle(
                    color: corTexto,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
