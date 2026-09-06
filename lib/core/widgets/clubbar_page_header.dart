import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class ClubbarPageHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? tituloWidget;
  final Widget? subtituloWidget;
  final Widget? trailing;
  final TextStyle? tituloStyle;
  final EdgeInsetsGeometry padding;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.tituloWidget,
    this.subtituloWidget,
    this.trailing,
    this.tituloStyle,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFECB3), ClubbarColors.fundo],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: ClubbarColors.sombra,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textos = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tituloWidget ??
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        tituloStyle ??
                        const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: ClubbarColors.textoPrincipal,
                        ),
                  ),
              const SizedBox(height: 4),
              subtituloWidget ??
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: ClubbarColors.textoSecundario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ],
          );

          if (trailing != null && constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                textos,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textos),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          );
        },
      ),
    );
  }
}
