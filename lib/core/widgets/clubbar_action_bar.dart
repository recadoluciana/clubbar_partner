import 'package:flutter/material.dart';

import '../theme/clubbar_colors.dart';

class ClubbarActionBar extends StatelessWidget {
  final List<Widget> actions;
  final Color backgroundColor;
  final bool singleLine;

  const ClubbarActionBar({
    super.key,
    required this.actions,
    this.backgroundColor = ClubbarColors.primaria,
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
        child: Theme(
          data: Theme.of(context).copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ClubbarColors.primariaEscuro,
                disabledBackgroundColor: Colors.white30,
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white60,
                side: const BorderSide(color: Colors.white),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final empilhar =
                    !singleLine &&
                    actions.length > 2 &&
                    constraints.maxWidth < 460;
                if (empilhar) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var indice = 0;
                        indice < actions.length;
                        indice++
                      ) ...[
                        if (indice > 0) const SizedBox(height: 8),
                        actions[indice],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var indice = 0; indice < actions.length; indice++) ...[
                      if (indice > 0) const SizedBox(width: 10),
                      Expanded(child: actions[indice]),
                    ],
                  ],
                );
              },
            ),
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
    final background = primary ? Colors.white : Colors.transparent;
    final foreground = primary ? ClubbarColors.primariaEscuro : Colors.white;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        backgroundColor: background,
        foregroundColor: foreground,
        side: const BorderSide(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
