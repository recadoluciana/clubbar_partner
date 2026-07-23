import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/clubbar_colors.dart';

class ClubbarPageHeader extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData? icone;

  /// Permite informar uma imagem manualmente.
  /// Caso esteja vazio, será utilizada a logo da loja do usuário.
  final String? imagemUrl;

  final Widget? trailing;

  /// Permite esconder organização, usuário, cargo, data e hora.
  final bool mostrarDadosSessao;

  /// Permite esconder somente a data e a hora.
  final bool mostrarDataHora;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.icone,
    this.imagemUrl,
    this.trailing,
    this.mostrarDadosSessao = true,
    this.mostrarDataHora = true,
  });

  @override
  State<ClubbarPageHeader> createState() => _ClubbarPageHeaderState();
}

class _ClubbarPageHeaderState extends State<ClubbarPageHeader> {
  bool _carregando = true;

  String _nomeOrganizacao = '';
  String _nomeUsuario = '';
  String _cargo = '';
  String _logoLoja = '';

  DateTime _agora = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _carregarDadosSessao();

    if (widget.mostrarDadosSessao && widget.mostrarDataHora) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;

        setState(() {
          _agora = DateTime.now();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
      final usuarioId = await StorageService.getUsuarioId();

      final nomeOrganizacao = (await StorageService.getNomeOrganizacao() ?? '')
          .trim();

      final nomeUsuario = (await StorageService.getNomeUsuario() ?? '').trim();

      final cargo = (await StorageService.getCargo() ?? '').trim();

      String logoLoja = '';

      if (usuarioId != null && usuarioId > 0) {
        try {
          final resposta = await ApiService.buscarLojaDoUsuario(
            usuarioId: usuarioId,
          );

          logoLoja = (resposta['urllogoloja'] ?? '').toString().trim();
        } catch (e) {
          /*
           * SUPERADMIN e administradores gerais
           * podem não possuir loja vinculada.
           */
          debugPrint('[PAGE HEADER] Não foi possível carregar a loja: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = nomeOrganizacao.isEmpty
            ? 'Organização não identificada'
            : nomeOrganizacao;

        _nomeUsuario = nomeUsuario.isEmpty
            ? 'Usuário não identificado'
            : nomeUsuario;

        _cargo = cargo.isEmpty ? 'Usuário' : _formatarCargo(cargo);

        _logoLoja = logoLoja;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('[PAGE HEADER] Erro ao carregar dados da sessão: $e');

      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = 'Organização não identificada';

        _nomeUsuario = 'Usuário não identificado';

        _cargo = 'Usuário';
        _carregando = false;
      });
    }
  }

  String _formatarCargo(String valor) {
    final texto = valor.trim().replaceAll('_', ' ').toLowerCase();

    if (texto.isEmpty) return 'Usuário';

    return texto
        .split(' ')
        .where((parte) => parte.trim().isNotEmpty)
        .map((parte) => parte[0].toUpperCase() + parte.substring(1))
        .join(' ');
  }

  String _montarUrlImagem(String? caminhoOriginal) {
    final caminho = (caminhoOriginal ?? '').trim();

    if (caminho.isEmpty) return '';

    if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
      return caminho;
    }

    return caminho.startsWith('/')
        ? '${ApiConfig.baseUrl}$caminho'
        : '${ApiConfig.baseUrl}/$caminho';
  }

  Widget _avatarPadrao({double tamanho = 56}) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ClubbarColors.branco,
        shape: BoxShape.circle,
        border: Border.all(color: ClubbarColors.ambar, width: 2),
        boxShadow: const [
          BoxShadow(
            color: ClubbarColors.sombra,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        widget.icone ?? Icons.admin_panel_settings_rounded,
        size: 27,
        color: ClubbarColors.preto,
      ),
    );
  }

  Widget _logo() {
    final imagemInformada = (widget.imagemUrl ?? '').trim();

    final caminhoImagem = imagemInformada.isNotEmpty
        ? imagemInformada
        : _logoLoja;

    final url = _montarUrlImagem(caminhoImagem);

    if (url.isEmpty) {
      return _avatarPadrao();
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: ClubbarColors.branco,
        shape: BoxShape.circle,
        border: Border.all(color: ClubbarColors.branco, width: 2),
        boxShadow: const [
          BoxShadow(
            color: ClubbarColors.sombra,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _avatarPadrao(tamanho: 58);
          },
        ),
      ),
    );
  }

  Widget _linhaInformacao({required IconData icone, required String texto}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icone, size: 14, color: ClubbarColors.textoSecundario),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: ClubbarColors.textoSecundario,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dadosSessao() {
    if (!widget.mostrarDadosSessao) {
      return const SizedBox.shrink();
    }

    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ClubbarColors.ambarEscuro,
          ),
        ),
      );
    }

    final data = DateFormat('dd/MM/yyyy', 'pt_BR').format(_agora);

    final hora = DateFormat('HH:mm:ss', 'pt_BR').format(_agora);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 7),

        _linhaInformacao(
          icone: Icons.business_rounded,
          texto: _nomeOrganizacao,
        ),

        _linhaInformacao(
          icone: Icons.person_rounded,
          texto: '$_nomeUsuario • $_cargo',
        ),

        if (widget.mostrarDataHora)
          _linhaInformacao(
            icone: Icons.schedule_rounded,
            texto: '$data • $hora',
          ),
      ],
    );
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
          _logo(),

          const SizedBox(width: 13),

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

                const SizedBox(height: 3),

                Text(
                  widget.subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: ClubbarColors.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                _dadosSessao(),
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
