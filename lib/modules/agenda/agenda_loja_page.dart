import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'agenda_mensal_page.dart';

class AgendaLojaPage extends StatefulWidget {
  final int organizacaoId;

  const AgendaLojaPage({super.key, required this.organizacaoId});

  @override
  State<AgendaLojaPage> createState() => _AgendaLojaPageState();
}

class _AgendaLojaPageState extends State<AgendaLojaPage> {
  final _repository = LojaRepository();
  List<Loja> _lojas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lojas = await _repository.listar(widget.organizacaoId);
      if (mounted) setState(() => _lojas = lojas);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String? _imagem(Loja loja) {
    final valor = (loja.urllogoloja ?? loja.urlfachadaloja ?? '').trim();
    if (valor.isEmpty) return null;
    return valor.startsWith('http') ? valor : ApiConfig.buildUrl(valor);
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregando && _lojas.length == 1) {
      return AgendaMensalPage(loja: _lojas.first);
    }
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Agenda Mensal',
            subtitulo: 'Escolha o estabelecimento que deseja visualizar',
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: _lojas.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    'Nenhum estabelecimento cadastrado.',
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _lojas.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Selecione o estabelecimento',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              final loja = _lojas[index - 1];
                              final imagem = _imagem(loja);
                              final ativo =
                                  (loja.sitloja ?? '').toUpperCase() == 'ATIVA';
                              return Card(
                                child: ListTile(
                                  leading: imagem == null
                                      ? const Icon(Icons.storefront_outlined)
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            imagem,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.storefront_outlined,
                                                ),
                                          ),
                                        ),
                                  title: Text(loja.nmloja),
                                  subtitle: Text(
                                    ativo ? 'Ativo' : 'Inativo',
                                    style: TextStyle(
                                      color: ativo
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AgendaMensalPage(loja: loja),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
