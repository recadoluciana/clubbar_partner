import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/repositories/loja_horario_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import '../agenda/agenda_mensal_page.dart';
import '../cardapio/cardapio_digital_page.dart';
import '../cardapio/cardapio_padrao_page.dart';
import '../../core/repositories/cardapio_padrao_repository.dart';
import 'horario_funcionamento_screen.dart';
import 'loja_form_page.dart';
import 'loja_imagens_page.dart';
import 'loja_conteudo_page.dart';
import 'loja_politica_ingresso_page.dart';
import 'loja_configuracao_produtos_page.dart';

class LojaListPage extends StatefulWidget {
  final int organizacaoId;
  final bool embedded;

  const LojaListPage({
    super.key,
    required this.organizacaoId,
    this.embedded = false,
  });

  @override
  State<LojaListPage> createState() => _LojaListPageState();
}

class _LojaListPageState extends State<LojaListPage> {
  final TextEditingController _buscaController = TextEditingController();
  final LojaRepository _repository = LojaRepository();
  final LojaHorarioRepository _horarioRepository = LojaHorarioRepository();
  final CardapioPadraoRepository _cardapioPadraoRepository =
      CardapioPadraoRepository();

  bool _carregando = true;
  bool _excluindo = false;

  String? _erro;
  String _nomeOrganizacao = 'Empresa não identificada';
  bool _carregandoOrganizacao = true;
  String _cargo = '';
  int? _lojaUsuarioId;
  bool _carregandoPermissoes = true;
  int? _alterandoStatusLojaId;

  List<Loja> _lojas = [];
  List<Loja> _lojasFiltradas = [];
  Set<int> _horariosDefinidos = {};

  @override
  void initState() {
    super.initState();
    _carregarLojas();
    _carregarNomeOrganizacao();
    _carregarPermissoes();
  }

  Future<void> _carregarPermissoes() async {
    final resultados = await Future.wait<dynamic>([
      StorageService.getCargo(),
      StorageService.getLojaId(),
    ]);

    if (!mounted) return;

    setState(() {
      _cargo = (resultados[0] as String? ?? '').trim().toUpperCase();
      _lojaUsuarioId = resultados[1] as int?;
      _carregandoPermissoes = false;
    });
  }

  bool get _cargoGerencial =>
      _cargo == 'SUPERADMIN' || _cargo == 'ADMIN' || _cargo == 'GERENTE';

  bool get _podeIncluirLoja {
    return !_carregandoPermissoes && _cargoGerencial && _lojaUsuarioId == null;
  }

  bool _podeAlterarLoja(Loja loja) {
    if (_carregandoPermissoes) return false;
    if (!_cargoGerencial) return false;
    return _lojaUsuarioId == null || _lojaUsuarioId == loja.lojaId;
  }

  void _avisarSomenteConsulta() {
    AppSnackBar.aviso(
      context,
      'Você não pode alterar este estabelecimento. Seu acesso permite apenas consultá-lo.',
    );
  }

  Future<void> _carregarNomeOrganizacao() async {
    try {
      final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = nome.isEmpty ? 'Empresa não identificada' : nome;
        _carregandoOrganizacao = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _nomeOrganizacao = 'Empresa não identificada';
        _carregandoOrganizacao = false;
      });
    }
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _extrairMensagemErro(Object erro) {
    final texto = erro.toString();

    try {
      final inicio = texto.indexOf('{');
      final fim = texto.lastIndexOf('}');

      if (inicio != -1 && fim != -1 && fim > inicio) {
        final jsonTexto = texto.substring(inicio, fim + 1);
        final decoded = jsonDecode(jsonTexto);

        if (decoded is Map && decoded['detail'] != null) {
          return decoded['detail'].toString();
        }
      }
    } catch (_) {}

    final mensagem = texto
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception:', '')
        .trim();

    return mensagem.isEmpty ? 'Ocorreu um erro inesperado.' : mensagem;
  }

  Future<void> _carregarLojas() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final lista = await _repository.listar(widget.organizacaoId);
      final horariosDefinidos = <int>{};
      await Future.wait(
        lista.map((loja) async {
          try {
            final horarios = await _horarioRepository.buscarPorLoja(
              loja.lojaId,
            );
            if (horarios.any((item) => item.lojaHorarioId != null)) {
              horariosDefinidos.add(loja.lojaId);
            }
          } catch (_) {
            // A listagem principal continua disponível mesmo se um horário falhar.
          }
        }),
      );

      if (!mounted) return;

      setState(() {
        _lojas = lista;
        _lojasFiltradas = _aplicarFiltro(lista, _buscaController.text);
        _horariosDefinidos = horariosDefinidos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      final mensagem = _extrairMensagemErro(e);

      setState(() {
        _carregando = false;
        _erro = mensagem;
      });

      AppSnackBar.erro(context, mensagem);
    }
  }

  List<Loja> _aplicarFiltro(List<Loja> lojas, String texto) {
    final busca = texto.trim().toLowerCase();

    if (busca.isEmpty) {
      return List<Loja>.from(lojas);
    }

    return lojas.where((loja) {
      final nome = loja.nmloja.toLowerCase();
      final endereco = (loja.endloja ?? '').toLowerCase();
      final bairro = (loja.dsbairroloja ?? '').toLowerCase();
      final instagram = (loja.dsinstaloja ?? '').toLowerCase();
      final telefone = (loja.nrtelloja ?? '').toLowerCase();
      final status = (loja.sitloja ?? '').toLowerCase();
      final estado = (loja.nmestado ?? '').toLowerCase();
      final siglaEstado = (loja.sgestado ?? '').toLowerCase();
      final cidade = (loja.nmcidade ?? '').toLowerCase();

      return loja.lojaId.toString().contains(busca) ||
          nome.contains(busca) ||
          endereco.contains(busca) ||
          bairro.contains(busca) ||
          instagram.contains(busca) ||
          telefone.contains(busca) ||
          status.contains(busca) ||
          estado.contains(busca) ||
          siglaEstado.contains(busca) ||
          cidade.contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _lojasFiltradas = _aplicarFiltro(_lojas, texto);
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _abrirNovaLoja() async {
    if (!_podeIncluirLoja) {
      AppSnackBar.aviso(
        context,
        _lojaUsuarioId != null
            ? 'Seu usuário está vinculado a um estabelecimento e não pode cadastrar outro.'
            : 'Somente administradores e gerentes podem cadastrar estabelecimentos.',
      );
      return;
    }

    final resultado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const LojaFormPage()));

    if (resultado == true) {
      await _carregarLojas();
    }
  }

  Future<void> _abrirEdicao(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      _avisarSomenteConsulta();
      return;
    }

    final resultado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LojaFormPage(loja: loja)));

    if (resultado == true) {
      await _carregarLojas();
    }
  }

  Future<void> _abrirHorarios(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      AppSnackBar.aviso(
        context,
        'A função Horários não é permitida para este usuário/cargo.',
      );
      return;
    }

    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HorarioFuncionamentoScreen(
          lojaId: loja.lojaId,
          nomeLoja: loja.nmloja,
          aberto24x7Inicial: loja.aberto24x7,
          onSalvarAberto24x7: (valor) =>
              _repository.atualizarAberto24x7(loja, valor),
        ),
      ),
    );

    if (alterado == true && mounted) {
      await _carregarLojas();
    }
  }

  Future<void> _abrirImagens(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      AppSnackBar.aviso(
        context,
        'A função Imagens não é permitida para este usuário/cargo.',
      );
      return;
    }

    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LojaImagensPage(loja: loja)),
    );

    if (alterado == true && mounted) {
      await _carregarLojas();
    }
  }

  Future<void> _abrirConteudo(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      AppSnackBar.aviso(
        context,
        'A função Conteúdo não é permitida para este usuário/cargo.',
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LojaConteudoPage(loja: loja)),
    );
  }

  Future<void> _abrirPoliticaIngressos(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      AppSnackBar.aviso(
        context,
        'A função Política de Ingressos não é permitida para este usuário/cargo.',
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LojaPoliticaIngressoPage(loja: loja)),
    );
  }

  Future<void> _abrirConfiguracaoProdutos(
    Loja loja,
    LojaConfiguracaoTipo tipo,
  ) async {
    if (!_podeAlterarLoja(loja)) {
      _avisarSomenteConsulta();
      return;
    }
    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LojaConfiguracaoProdutosPage(loja: loja, tipo: tipo),
      ),
    );
    if (alterado == true && mounted) await _carregarLojas();
  }

  Future<void> _abrirCardapio(Loja loja) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CardapioDigitalPage(loja: loja)),
    );
  }

  Future<void> _abrirCardapioPadrao() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CardapioPadraoPage(
          organizacaoId: widget.organizacaoId,
          nomeOrganizacao: _nomeOrganizacao,
          lojas: _lojas,
        ),
      ),
    );
  }

  Future<void> _importarCardapioPadrao(Loja loja) async {
    if (!_podeAlterarLoja(loja)) {
      _avisarSomenteConsulta();
      return;
    }
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar cardápio padrão'),
        content: Text(
          'As categorias e os produtos que ainda não existem em “${loja.nmloja}” serão copiados. '
          'Itens com o mesmo nome serão preservados, inclusive seus preços atuais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    try {
      final resposta = await _cardapioPadraoRepository.importar(loja.lojaId);
      if (!mounted) return;
      final criados = resposta['produtos_criados'] ?? 0;
      final ignorados = resposta['produtos_ignorados'] ?? 0;
      AppSnackBar.sucesso(
        context,
        'Cardápio importado: $criados produtos incluídos e $ignorados preservados.',
      );
      await _abrirCardapio(loja);
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, _extrairMensagemErro(e));
    }
  }

  Future<void> _abrirAgenda(Loja loja) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AgendaMensalPage(loja: loja)),
    );
  }

  Future<bool> _confirmarExclusao(Loja loja) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ClubbarColors.fundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ClubbarColors.erro,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Excluir estabelecimento',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir o estabelecimento '
            '"${loja.nmloja}"?\n\n'
            'Essa ação não poderá ser desfeita.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text(
                'Cancelar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(color: ClubbarColors.borda),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_rounded),
              label: const Text(
                'Excluir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.erro,
                foregroundColor: ClubbarColors.branco,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    return confirmar == true;
  }

  Future<void> _excluirLoja(Loja loja) async {
    if (_excluindo) return;

    if (!_podeAlterarLoja(loja)) {
      _avisarSomenteConsulta();
      return;
    }

    final confirmou = await _confirmarExclusao(loja);

    if (!confirmou) return;

    setState(() {
      _excluindo = true;
    });

    try {
      await _repository.excluir(loja.lojaId);

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Estabelecimento excluído com sucesso.');

      await _carregarLojas();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, _extrairMensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  Widget _controleStatus(Loja loja) {
    final ativa = _lojaAtiva(loja);
    final alterando = _alterandoStatusLojaId == loja.lojaId;

    return Container(
      padding: const EdgeInsets.only(left: 13, right: 5, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: ativa ? ClubbarColors.sucessoClaro : ClubbarColors.erroClaro,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (ativa ? ClubbarColors.sucesso : ClubbarColors.erro)
              .withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ativa ? 'Ativo' : 'Inativo',
            style: TextStyle(
              color: ativa ? ClubbarColors.sucesso : ClubbarColors.erro,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          if (alterando)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Transform.scale(
              scale: 0.78,
              child: Switch.adaptive(
                value: ativa,
                activeTrackColor: ClubbarColors.sucesso,
                onChanged: _podeAlterarLoja(loja)
                    ? (_) => _alterarStatus(loja)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _indicadorConfiguracao({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required bool definido,
    Color? cor,
    VoidCallback? onTap,
  }) {
    final destaque =
        cor ??
        (definido ? ClubbarColors.sucesso : ClubbarColors.textoSecundario);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: destaque.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: destaque.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: destaque.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 20, color: destaque),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: destaque,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: ClubbarColors.textoSecundario,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              onTap != null
                  ? Icons.chevron_right_rounded
                  : definido
                  ? Icons.check_circle_rounded
                  : Icons.pending_outlined,
              size: 18,
              color: destaque,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoConfiguracoes(Loja loja) {
    final logoDefinida = (loja.urllogoloja ?? '').trim().isNotEmpty;
    final fachadaDefinida = (loja.urlfachadaloja ?? '').trim().isNotEmpty;
    final aberto24Horas = loja.aberto24x7 == 'S';
    final horarioDefinido =
        aberto24Horas || _horariosDefinidos.contains(loja.lojaId);
    final usaCashback = loja.usacashback == 'S';
    final itens = [
      _indicadorConfiguracao(
        icone: Icons.savings_outlined,
        titulo: 'Usar cashback',
        subtitulo: usaCashback ? 'Sim' : 'Não',
        definido: usaCashback,
        cor: usaCashback ? ClubbarColors.sucesso : ClubbarColors.erro,
        onTap: () =>
            _abrirConfiguracaoProdutos(loja, LojaConfiguracaoTipo.cashback),
      ),
      _indicadorConfiguracao(
        icone: Icons.image_outlined,
        titulo: logoDefinida ? 'Foto logo definida' : 'Foto logo pendente',
        subtitulo: logoDefinida
            ? 'Identidade visual pronta'
            : 'Toque para adicionar',
        definido: logoDefinida,
        onTap: () => _abrirImagens(loja),
      ),
      _indicadorConfiguracao(
        icone: Icons.storefront_outlined,
        titulo: fachadaDefinida
            ? 'Foto fachada definida'
            : 'Foto fachada pendente',
        subtitulo: fachadaDefinida
            ? 'Imagem cadastrada'
            : 'Toque para adicionar',
        definido: fachadaDefinida,
        onTap: () => _abrirImagens(loja),
      ),
      _indicadorConfiguracao(
        icone: aberto24Horas
            ? Icons.schedule_rounded
            : Icons.access_time_rounded,
        titulo: aberto24Horas
            ? 'Horário definido: 24 horas'
            : horarioDefinido
            ? 'Horário definido'
            : 'Horário pendente',
        subtitulo: aberto24Horas
            ? 'Atendimento contínuo'
            : horarioDefinido
            ? 'Atendimento configurado'
            : 'Defina o atendimento',
        definido: horarioDefinido,
        cor: horarioDefinido ? ClubbarColors.info : null,
        onTap: () => _abrirHorarios(loja),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                itens[i],
                if (i < itens.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < itens.length; i++) ...[
              Expanded(child: itens[i]),
              if (i < itens.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  bool _lojaAtiva(Loja loja) {
    final status = (loja.sitloja ?? 'ATIVA').trim().toUpperCase();
    return status == 'ATIVA' || status == 'ATIVO';
  }

  Future<void> _alterarStatus(Loja loja) async {
    if (_alterandoStatusLojaId != null) return;

    if (!_podeAlterarLoja(loja)) {
      AppSnackBar.aviso(
        context,
        'A função Inativar/Reativar não é permitida para este usuário/cargo.',
      );
      return;
    }

    final ativa = _lojaAtiva(loja);
    final acao = ativa ? 'inativar' : 'reativar';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            ativa ? 'Inativar estabelecimento' : 'Reativar estabelecimento',
          ),
          content: Text(
            'Deseja realmente $acao o estabelecimento “${loja.nmloja}”?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(ativa ? 'Inativar' : 'Reativar'),
            ),
          ],
        );
      },
    );

    if (confirmou != true || !mounted) return;

    setState(() => _alterandoStatusLojaId = loja.lojaId);

    try {
      if (ativa) {
        await _repository.inativar(loja.lojaId);
      } else {
        await _repository.reativar(loja.lojaId);
      }

      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        ativa
            ? 'Estabelecimento inativado com sucesso.'
            : 'Estabelecimento reativado com sucesso.',
      );
      await _carregarLojas();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _extrairMensagemErro(e));
    } finally {
      if (mounted) setState(() => _alterandoStatusLojaId = null);
    }
  }

  Widget _linhaInformacao({required IconData icone, required String texto}) {
    if (texto.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 17, color: ClubbarColors.textoSecundario),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: ClubbarColors.textoSecundario,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuAcoesLoja(Loja loja) {
    return PopupMenuButton<String>(
      tooltip: 'Ações do estabelecimento',
      icon: const Icon(Icons.more_vert_rounded),
      color: ClubbarColors.branco,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (acao) {
        switch (acao) {
          case 'cardapio':
            _abrirCardapio(loja);
          case 'agenda':
            _abrirAgenda(loja);
          case 'conteudo':
            _abrirConteudo(loja);
          case 'politica':
            _abrirPoliticaIngressos(loja);
          case 'politica_produtos':
            _abrirConfiguracaoProdutos(
              loja,
              LojaConfiguracaoTipo.politicaProdutos,
            );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'cardapio',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restaurant_menu_rounded),
            title: Text('Cardápio Digital'),
          ),
        ),
        const PopupMenuItem(
          value: 'agenda',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_month_rounded),
            title: Text('Agenda Mensal'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'conteudo',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_stories_outlined),
            title: Text('Conteúdo do estabelecimento'),
          ),
        ),
        const PopupMenuItem(
          value: 'politica',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.policy_outlined),
            title: Text('Política de ingressos'),
          ),
        ),
        const PopupMenuItem(
          value: 'politica_produtos',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('Política de produtos'),
          ),
        ),
      ],
    );
  }

  Widget _cardLoja(Loja loja) {
    final endereco = (loja.endloja ?? '').trim();
    final numeroEndereco = loja.nrendeloja.trim();
    final cep = Formatters.cep(loja.nrceploja.trim());
    final bairro = (loja.dsbairroloja ?? '').trim();
    final telefone = Formatters.telefone((loja.nrtelloja ?? '').trim());
    final cidade = (loja.nmcidade ?? '').trim();
    final siglaEstado = (loja.sgestado ?? '').trim();

    final localidade = [
      cidade,
      siglaEstado,
    ].where((valor) => valor.isNotEmpty).join(' - ');

    final logradouroComNumero = [
      endereco,
      numeroEndereco,
    ].where((valor) => valor.isNotEmpty).join(', ');

    final enderecoCompleto = [
      logradouroComNumero,
      bairro,
      localidade,
      if (cep.isNotEmpty) 'CEP $cep',
    ].where((valor) => valor.isNotEmpty).join(' • ');

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            loja.nmloja,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: ClubbarColors.info,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Editar estabelecimento',
                          onPressed: () => _abrirEdicao(loja),
                          icon: const Icon(Icons.edit_rounded),
                          color: ClubbarColors.info,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Excluir estabelecimento',
                          onPressed: _excluindo
                              ? null
                              : () => _excluirLoja(loja),
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: ClubbarColors.erro,
                          visualDensity: VisualDensity.compact,
                        ),
                        _menuAcoesLoja(loja),
                      ],
                    ),

                    if (enderecoCompleto.isNotEmpty)
                      _linhaInformacao(
                        icone: Icons.location_on_outlined,
                        texto: enderecoCompleto,
                      ),

                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          if (telefone.isNotEmpty) ...[
                            const Icon(
                              Icons.phone_outlined,
                              size: 17,
                              color: ClubbarColors.textoSecundario,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                telefone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ClubbarColors.textoSecundario,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                        ],
                      ),
                    ),

                    _linhaInformacao(
                      icone: loja.idvalidadeprod == 'S'
                          ? Icons.event_available_outlined
                          : Icons.event_busy_outlined,
                      texto: loja.idvalidadeprod == 'S'
                          ? 'Validade dos tickets de produtos: ${loja.nrdiavalidade ?? 90} dias'
                          : 'Tickets de produtos sem prazo de validade',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: _controleStatus(loja)),
          const SizedBox(height: 10),
          _resumoConfiguracoes(loja),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _importarCardapioPadrao(loja),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Importar cardápio padrão da empresa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar estabelecimento',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: ClubbarColors.textoSecundario,
        ),
        suffixIcon: _buscaController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Limpar busca',
                onPressed: _limparBusca,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: ClubbarColors.branco,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
        ),
      ),
    );
  }

  Widget _botaoCircularHeader({
    required String tooltip,
    required IconData icone,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icone, size: 22),
          color: ClubbarColors.preto,
          disabledColor: ClubbarColors.textoSecundario,
          style: IconButton.styleFrom(
            backgroundColor: ClubbarColors.ambar,
            disabledBackgroundColor: ClubbarColors.borda,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }

  Widget _acoesHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _botaoCircularHeader(
          tooltip: 'Cardápio padrão da empresa',
          icone: Icons.menu_book_rounded,
          onPressed: _podeIncluirLoja ? _abrirCardapioPadrao : null,
        ),
        const SizedBox(width: 8),
        _botaoCircularHeader(
          tooltip: 'Atualizar',
          icone: Icons.refresh_rounded,
          onPressed: _carregando ? null : _carregarLojas,
        ),
        const SizedBox(width: 8),
        _botaoCircularHeader(
          tooltip: 'Adicionar estabelecimento',
          icone: Icons.add_rounded,
          onPressed: _abrirNovaLoja,
        ),
      ],
    );
  }

  String _subtituloHeader() {
    if (_carregando) {
      return 'Carregando estabelecimentos...';
    }

    return '${_lojas.length} '
        '${_lojas.length == 1 ? 'estabelecimento cadastrado' : 'estabelecimentos cadastrados'}';
  }

  Widget _estadoVazio() {
    final temBusca = _buscaController.text.trim().isNotEmpty;

    return ClubbarCard(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: ClubbarColors.ambarClaro,
                shape: BoxShape.circle,
              ),
              child: Icon(
                temBusca ? Icons.search_off_rounded : Icons.storefront_rounded,
                size: 39,
                color: ClubbarColors.preto,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              temBusca
                  ? 'Nenhum estabelecimento encontrado'
                  : 'Nenhum estabelecimento cadastrado',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 7),

            Text(
              temBusca
                  ? 'Tente pesquisar usando outro nome, bairro ou endereço.'
                  : 'Cadastre o primeiro estabelecimento da sua empresa.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: ClubbarColors.textoSecundario,
                height: 1.4,
              ),
            ),

            if (!temBusca) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _abrirNovaLoja,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Adicionar estabelecimento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClubbarColors.ambar,
                  foregroundColor: ClubbarColors.preto,
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _estadoErro() {
    return ClubbarCard(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 62,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 14),

            const Text(
              'Não foi possível carregar os estabelecimentos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            Text(
              _erro ?? 'Tente novamente em instantes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ClubbarColors.textoSecundario,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _carregarLojas,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudoLista() {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 70),
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }

    if (_erro != null) {
      return _estadoErro();
    }

    if (_lojasFiltradas.isEmpty) {
      return _estadoVazio();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: _lojasFiltradas.map(_cardLoja).toList());
        }
        const espacamento = 16.0;
        final larguraCard = (constraints.maxWidth - espacamento) / 2;
        return Wrap(
          spacing: espacamento,
          runSpacing: espacamento,
          children: _lojasFiltradas
              .map(
                (loja) => SizedBox(width: larguraCard, child: _cardLoja(loja)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _lista({required bool mostrarTitulo}) {
    return Column(
      children: [
        if (mostrarTitulo)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estabelecimentos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: ClubbarColors.textoPrincipal,
                    ),
                  ),
                ),
                _acoesHeader(),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, mostrarTitulo ? 14 : 18, 20, 0),
          child: _campoBusca(),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregarLojas,
            color: ClubbarColors.ambar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: _conteudoLista(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(
        color: ClubbarColors.fundo,
        child: SafeArea(top: false, child: _lista(mostrarTitulo: true)),
      );
    }

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(
        mostrarVoltar: true,
        centralizarLogo: true,
        alturaLogo: 54,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: _carregandoOrganizacao
                  ? 'Carregando empresa...'
                  : _nomeOrganizacao,
              subtitulo: _subtituloHeader(),
              tituloStyle: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.blue,
              ),
              trailing: _acoesHeader(),
            ),
            Expanded(child: _lista(mostrarTitulo: false)),
          ],
        ),
      ),
    );
  }
}
