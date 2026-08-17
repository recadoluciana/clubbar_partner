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
    return LayoutBuilder(
      builder: (context, constraints) {
        final amplo = constraints.maxWidth >= 260;
        final tamanhoIconeContainer = amplo ? 64.0 : 52.0;
        final tamanhoIcone = amplo ? 32.0 : 27.0;

        return Material(
          color: ClubbarColors.branco,
          elevation: amplo ? 2 : 1,
          shadowColor: ClubbarColors.sombra,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(amplo ? 20 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ClubbarColors.borda),
              ),
              child: Stack(
                children: [
                  if (badge != null)
                    Positioned(top: 0, right: 0, child: badge!),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: tamanhoIconeContainer,
                          height: tamanhoIconeContainer,
                          decoration: BoxDecoration(
                            color: ClubbarColors.ambarClaro,
                            borderRadius: BorderRadius.circular(
                              amplo ? 20 : 17,
                            ),
                          ),
                          child: Icon(
                            icone,
                            size: tamanhoIcone,
                            color: corIcone ?? ClubbarColors.preto,
                          ),
                        ),
                        SizedBox(height: amplo ? 14 : 10),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: amplo ? 18 : 15,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: ClubbarColors.textoPrincipal,
                          ),
                        ),
                        if (subtitulo != null &&
                            subtitulo!.trim().isNotEmpty) ...[
                          SizedBox(height: amplo ? 6 : 4),
                          Text(
                            subtitulo!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: amplo ? 13.5 : 11.5,
                              height: 1.25,
                              color: ClubbarColors.textoSecundario,
                              fontWeight: FontWeight.w600,
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
      },
    );
  }
}
