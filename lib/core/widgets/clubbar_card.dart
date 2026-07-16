import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class ClubbarCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double elevation;
  final VoidCallback? onTap;
  final bool clipContent;

  const ClubbarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 22,
    this.backgroundColor,
    this.borderColor,
    this.elevation = 2,
    this.onTap,
    this.clipContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    final card = Material(
      color: backgroundColor ?? ClubbarColors.fundoCard,
      elevation: elevation,
      shadowColor: ClubbarColors.sombra,
      borderRadius: radius,
      clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? ClubbarColors.borda),
          ),
          child: child,
        ),
      ),
    );

    if (margin == null) {
      return card;
    }

    return Padding(padding: margin!, child: card);
  }
}
