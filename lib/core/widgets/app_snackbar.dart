import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static void sucesso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.green.shade700,
      Colors.white,
      Icons.check_circle_rounded,
    );
  }

  static void erro(
    BuildContext context,
    String mensagem, {
    Duration duration = const Duration(seconds: 4),
    bool mostrarFechar = false,
  }) {
    _mostrar(
      context,
      mensagemSegura(mensagem),
      Colors.red.shade700,
      Colors.white,
      Icons.error_rounded,
      duration: duration,
      mostrarFechar: mostrarFechar,
    );
  }

  /// Impede que respostas cruas de infraestrutura sejam exibidas ao parceiro.
  /// Erros de regra de negócio, já escritos de forma clara pela API, são
  /// preservados.
  static String mensagemSegura(String mensagem) {
    final texto = mensagem.trim();
    final textoLower = texto.toLowerCase();
    if (textoLower.contains('timeout')) {
      return 'O servidor demorou para responder. Tente novamente.';
    }
    if (textoLower.contains('socketexception') ||
        textoLower.contains('failed host lookup') ||
        textoLower.contains('connection refused') ||
        textoLower.contains('clientfailed to fetch') ||
        textoLower.contains('clientexception: failed to fetch')) {
      return 'Sem conexão com a internet ou servidor indisponível.';
    }
    final contemDetalheTecnico =
        texto.isEmpty ||
        texto.startsWith('{') ||
        texto.startsWith('[') ||
        texto.length > 350 ||
        textoLower.contains('traceback') ||
        textoLower.contains('stack trace') ||
        textoLower.contains('sqlalchemy') ||
        textoLower.contains('pymysql') ||
        textoLower.contains('mysql') ||
        textoLower.contains('socketexception') ||
        textoLower.contains('formatexception') ||
        textoLower.contains('internal server error') ||
        textoLower.contains('<html');

    if (contemDetalheTecnico) {
      return 'Não foi possível concluir a operação agora. Tente novamente em instantes.';
    }
    return texto;
  }

  static void aviso(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.amber.shade700,
      Colors.black,
      Icons.warning_amber_rounded,
    );
  }

  static void info(BuildContext context, String mensagem) {
    _mostrar(
      context,
      mensagem,
      Colors.blue.shade700,
      Colors.white,
      Icons.info_rounded,
    );
  }

  static void _mostrar(
    BuildContext context,
    String mensagem,
    Color cor,
    Color corTexto,
    IconData icone, {
    Duration duration = const Duration(seconds: 4),
    bool mostrarFechar = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        elevation: 6,
        duration: duration,
        showCloseIcon: mostrarFechar,
        closeIconColor: corTexto,
        backgroundColor: cor,
        content: Row(
          children: [
            Icon(icone, color: corTexto, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: TextStyle(
                  color: corTexto,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
