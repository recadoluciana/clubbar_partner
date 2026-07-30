import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/clubbar_colors.dart';

class ClubbarPageHeader extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData? icone;
  final String? imagemUrl;
  final Widget? trailing;

  /// Quando verdadeiro, o subtítulo exibirá:
  /// Nome do usuário • Cargo
  ///
  /// Quando falso, exibirá o subtítulo informado pela tela.
  final bool mostrarDadosSessao;

  /// Mantido para não quebrar telas que ainda informam esse parâmetro.
  /// A data e a hora não são mais exibidas no PageHeader.
  final bool mostrarDataHora;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.icone,
    this.imagemUrl,
    this.trailing,
    this.mostrarDadosSessao = true,
    this.mostrarDataHora = false,
  });

  @override
  State<ClubbarPageHeader> createState() => _ClubbarPageHeaderState();
}

class _ClubbarPageHeaderState extends State<ClubbarPageHeader> {
  bool _carregando = true;

  String _nomeUsuario = '';
  String _cargo = '';

  @override
  void initState() {
    super.initState();
    _carregarDadosSessao();
  }

  Future<void> _carregarDadosSessao() async {
    if (!widget.mostrarDadosSessao) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      return;
    }

    try {
      final nomeUsuario = (await StorageService.getNomeUsuario() ?? '').trim();

      final cargo = (await StorageService.getCargo() ?? '').trim();

      if (!mounted) return;

      setState(() {
        _nomeUsuario = nomeUsuario.isEmpty
            ? 'Usuário não identificado'
            : nomeUsuario;

        _cargo = cargo.isEmpty ? 'Usuário' : _formatarCargo(cargo);

        _carregando = false;
      });
    } catch (e) {
      debugPrint('[PAGE HEADER] Erro ao carregar dados da sessão: $e');

      if (!mounted) return;

      setState(() {
        _nomeUsuario = 'Usuário não identificado';
        _cargo = 'Usuário';
        _carregando = false;
      });
    }
  }

  String _formatarCargo(String valor) {
    final texto = valor.trim().replaceAll('_', ' ').toLowerCase();

    if (texto.isEmpty) {
      return 'Usuário';
    }

    return texto
        .split(' ')
        .where((parte) => parte.trim().isNotEmpty)
        .map(
          (parte) =>
              '${parte[0].toUpperCase()}'
              '${parte.substring(1)}',
        )
        .join(' ');
  }

  String _subtituloExibido() {
    if (!widget.mostrarDadosSessao) {
      return widget.subtitulo;
    }

    if (_carregando) {
      return 'Carregando usuário...';
    }

    return '$_nomeUsuario • $_cargo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtituloExibido(),
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
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
