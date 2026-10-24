import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class ClubbarActionBar extends StatelessWidget {
  final List<Widget> actions;
  final Color backgroundColor;
  final bool singleLine;

  const ClubbarActionBar({
    super.key,
    required this.actions,
    this.backgroundColor = Colors.white,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: 10,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: singleLine
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var indice = 0;
                        indice < actions.length;
                        indice++
                      ) ...[
                        if (indice > 0) const SizedBox(width: 10),
                        actions[indice],
                      ],
                    ],
                  ),
                )
              : Wrap(
                  alignment: WrapAlignment.end,
                  runAlignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions,
                ),
        ),
      ),
    );
  }
}

class ClubbarAddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool primary;

  const ClubbarAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary ? ClubbarColors.primaria : Colors.white;
    final foreground = primary ? Colors.white : ClubbarColors.primariaEscuro;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        backgroundColor: background,
        foregroundColor: foreground,
        side: primary ? null : const BorderSide(color: ClubbarColors.primaria),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
