import 'package:flutter/material.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool mostrarVoltar;
  final bool mostrarSair;
  final VoidCallback? onVoltar;
  final VoidCallback? onSair;
  final String logoPath;
  final bool centralizarLogo;
  final double alturaLogo;
  final List<Widget>? actions;

  const ClubbarAppBar({
    super.key,
    this.mostrarVoltar = false,
    this.mostrarSair = false,
    this.onVoltar,
    this.onSair,
    this.logoPath = 'assets/images/clubbar_topbar.png',
    this.centralizarLogo = false,
    this.alturaLogo = 52,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: centralizarLogo,
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      titleSpacing: 8,

      leading: mostrarVoltar
          ? IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded, size: 25),
              onPressed:
                  onVoltar ??
                  () {
                    Navigator.maybePop(context);
                  },
            )
          : null,

      title: SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: centralizarLogo ? 1 : 4),
          child: Align(
            alignment: centralizarLogo
                ? Alignment.center
                : Alignment.centerLeft,
            child: Image.asset(
              logoPath,
              height: alturaLogo,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return const Text(
                  'CLUBBAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                );
              },
            ),
          ),
        ),
      ),

      actions: [
        if (actions != null) ...actions!,

        if (mostrarSair)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout_rounded, size: 24),
              onPressed: onSair,
            ),
          ),
      ],
    );
  }
}
