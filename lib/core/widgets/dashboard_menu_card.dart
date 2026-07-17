import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class DashboardMenuCard extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final VoidCallback onTap;
  final Color? corIcone;
  final Widget? badge;

  const DashboardMenuCard({
    super.key,
    required this.titulo,
    required this.icone,
    required this.onTap,
    this.subtitulo,
    this.corIcone,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ClubbarColors.branco,
      elevation: 1,
      shadowColor: ClubbarColors.sombra,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClubbarColors.borda),
          ),
          child: Stack(
            children: [
              if (badge != null) Positioned(top: 0, right: 0, child: badge!),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: ClubbarColors.ambarClaro,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icone,
                        size: 23,
                        color: corIcone ?? ClubbarColors.preto,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: ClubbarColors.textoPrincipal,
                      ),
                    ),

                    if (subtitulo != null && subtitulo!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),

                      Text(
                        subtitulo!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          height: 1.1,
                          color: ClubbarColors.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
