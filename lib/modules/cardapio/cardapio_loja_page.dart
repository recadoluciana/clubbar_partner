import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'cardapio_digital_page.dart';

class CardapioLojaPage extends StatefulWidget {
  final int organizacaoId;
  const CardapioLojaPage({super.key, required this.organizacaoId});

  @override
  State<CardapioLojaPage> createState() => _CardapioLojaPageState();
}

class _CardapioLojaPageState extends State<CardapioLojaPage> {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        const ClubbarPageHeader(
          titulo: 'Cardápio Digital',
          subtitulo: 'Escolha o estabelecimento que deseja configurar',
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
                                child: Text('Nenhum estabelecimento cadastrado.'),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1,
                                mainAxisExtent: 150,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _lojas.length,
                          itemBuilder: (context, index) {
                            final loja = _lojas[index];
                            final imagem = _imagem(loja);
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CardapioDigitalPage(loja: loja),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 125,
                                      height: double.infinity,
                                      child: imagem == null
                                          ? const ColoredBox(
                                              color: ClubbarColors.ambarClaro,
                                              child: Icon(
                                                Icons.storefront,
                                                size: 48,
                                              ),
                                            )
                                          : Image.network(
                                              imagem,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.storefront,
                                                    size: 48,
                                                  ),
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              loja.nmloja,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              [loja.dsbairroloja, loja.nmcidade]
                                                  .where(
                                                    (e) =>
                                                        e?.trim().isNotEmpty ==
                                                        true,
                                                  )
                                                  .join(' • '),
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 10),
                                            const Row(
                                              children: [
                                                Text(
                                                  'Abrir cardápio',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
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
