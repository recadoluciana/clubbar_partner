import 'package:flutter/material.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool mostrarVoltar;
  final bool mostrarSair;
  final VoidCallback? onVoltar;
  final VoidCallback? onSair;
  final String logoPath;
  final List<Widget>? actions;

  const ClubbarAppBar({
    super.key,
    this.mostrarVoltar = false,
    this.mostrarSair = false,
    this.onVoltar,
    this.onSair,
    this.logoPath = 'assets/images/logo.png',
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
      centerTitle: true,
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      titleSpacing: 0,

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
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Image.asset(
            logoPath,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) {
              return const Center(
                child: Text(
                  'CLUBBAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              );
            },
          ),
        ),
      ),

      actions: [
        if (actions != null) ...actions!,

        if (mostrarSair)
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded, size: 24),
            onPressed: onSair,
          ),
      ],
    );
  }
}
