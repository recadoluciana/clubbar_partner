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
          behavior: SnackBarBehavior.floating,
          width: celular ? null : 520,
          margin: celular ? const EdgeInsets.fromLTRB(8, 0, 8, 8) : null,
          backgroundColor: cor,
          elevation: 5,
          duration: const Duration(seconds: 3),
          dismissDirection: DismissDirection.down,
          showCloseIcon: !celular,
          closeIconColor: corTexto,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          content: Row(
            children: [
              Icon(icone, color: corTexto, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensagem,
                  style: TextStyle(
                    color: corTexto,
                    fontSize: 13,
                    height: 1.2,
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
