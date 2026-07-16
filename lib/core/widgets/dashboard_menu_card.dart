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
      elevation: 2,
      shadowColor: ClubbarColors.sombra,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 165,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ClubbarColors.borda),
          ),
          child: Stack(
            children: [
              if (badge != null) Positioned(top: 0, right: 0, child: badge!),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: ClubbarColors.ambarClaro,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icone,
                      size: 34,
                      color: corIcone ?? ClubbarColors.preto,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ClubbarColors.textoPrincipal,
                    ),
                  ),

                  if (subtitulo != null) ...[
                    const SizedBox(height: 6),

                    Text(
                      subtitulo!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ClubbarColors.textoSecundario,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
