import 'package:flutter/material.dart';

class ClubbarPageHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData? icone;
  final String? imagemUrl;
  final Widget? trailing;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.icone,
    this.imagemUrl,
    this.trailing,
  });

  Widget _avatarPadrao() {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.shade200, width: 2),
      ),
      child: Icon(
        icone ?? Icons.admin_panel_settings_rounded,
        size: 25,
        color: Colors.black87,
      ),
    );
  }

  Widget _imagem() {
    final url = imagemUrl?.trim() ?? '';

    if (url.isEmpty) {
      return _avatarPadrao();
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _avatarPadrao();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFECB3), Color(0xFFF6F6F6)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          if (icone != null) ...[_avatarPadrao(), const SizedBox(width: 12)],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null)
            trailing!
          else if (imagemUrl != null && imagemUrl!.trim().isNotEmpty) ...[
            const SizedBox(width: 12),
            _imagem(),
          ],
        ],
      ),
    );
  }
}
