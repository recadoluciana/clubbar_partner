import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class CampanhasDoacaoPage extends StatefulWidget {
  const CampanhasDoacaoPage({super.key});

  @override
  State<CampanhasDoacaoPage> createState() => _CampanhasDoacaoPageState();
}

class _CampanhasDoacaoPageState extends State<CampanhasDoacaoPage> {
  final _lojaRepository = LojaRepository();
  List<Loja> _lojas = [];
  List<Map<String, dynamic>> _campanhas = [];
  List<Map<String, dynamic>> _eventos = [];
  int? _lojaId;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  dynamic _resposta(dynamic response) {
    final dados = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        dados is Map
            ? dados['detail'] ?? 'Não foi possível concluir.'
            : 'Não foi possível concluir.',
      );
    }
    return dados;
  }

  Future<void> _inicializar() async {
    setState(() => _carregando = true);
    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      if (organizacaoId == null || organizacaoId <= 0) {
        throw Exception('Empresa não identificada.');
      }
      final lojas = await _lojaRepository.listar(organizacaoId);
      final salva = await StorageService.getLojaId();
      final lojaId = lojas.any((loja) => loja.lojaId == salva)
          ? salva
          : (lojas.isEmpty ? null : lojas.first.lojaId);
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _lojaId = lojaId;
      });
      if (lojaId != null) {
        await Future.wait([_carregarEventos(lojaId), _carregarCampanhas()]);
      }
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarCampanhas() async {
    final lojaId = _lojaId;
    if (lojaId == null) {
      if (mounted) setState(() => _campanhas = []);
      return;
    }
    final dados =
        _resposta(await ApiService.get('/campanhas-doacao/lojas/$lojaId'))
            as List;
    if (mounted) {
      setState(
        () => _campanhas = dados
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    }
  }

  Future<void> _carregarEventos(int lojaId) async {
    final dados =
        _resposta(await ApiService.get('/eventos/loja/$lojaId')) as List;
    if (mounted) {
      setState(() {
        _eventos = dados
            .map((item) => Map<String, dynamic>.from(item))
            .where(
              (evento) => '${evento['statusevento']}'.toUpperCase() == 'ATIVO',
            )
            .toList();
      });
    }
  }

  Future<void> _trocarLoja(int? lojaId) async {
    if (lojaId == null || lojaId == _lojaId) return;
    setState(() {
      _lojaId = lojaId;
      _campanhas = [];
      _eventos = [];
      _carregando = true;
    });
    try {
      await Future.wait([_carregarEventos(lojaId), _carregarCampanhas()]);
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviarLogoCampanha(int campanhaId, XFile logo) async {
    final requisicao = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/campanhas-doacao/$campanhaId/logo'),
    );
    final token = await StorageService.getToken();
    if (token?.isNotEmpty == true) {
      requisicao.headers['Authorization'] = 'Bearer $token';
    }
    requisicao.files.add(
      kIsWeb
          ? http.MultipartFile.fromBytes(
              'logo',
              await logo.readAsBytes(),
              filename: logo.name,
            )
          : await http.MultipartFile.fromPath('logo', logo.path),
    );
    final resposta = await requisicao.send();
    final corpo = await resposta.stream.bytesToString();
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw Exception(
        corpo.trim().isEmpty
            ? 'Não foi possível enviar a logo da campanha.'
            : corpo,
      );
    }
  }

  Future<void> _editar([Map<String, dynamic>? atual]) async {
    final lojaId = _lojaId;
    if (lojaId == null) return;
    final formKey = GlobalKey<FormState>();
    final nome = TextEditingController(text: '${atual?['nome'] ?? ''}');
    final beneficiario = TextEditingController(
      text: '${atual?['beneficiario'] ?? ''}',
    );
    final pix = TextEditingController(text: '${atual?['chave_pix'] ?? ''}');
    final wallet = TextEditingController(
      text: '${atual?['asaas_wallet_id'] ?? ''}',
    );
    final percentual = TextEditingController(
      text: '${atual?['percentual_doacao'] ?? ''}',
    );
    final mensagem = TextEditingController(text: '${atual?['mensagem'] ?? ''}');
    XFile? logoSelecionada;
    Uint8List? logoBytes;
    final logoAtual = '${atual?['url_logo'] ?? ''}'.trim();
    var ativa = '${atual?['situacao'] ?? 'ATIVA'}'.toUpperCase() == 'ATIVA';
    var eventoId = (atual?['evento_id'] as num?)?.toInt() ?? -1;
    InputDecoration decoracaoCampo(String rotulo, {String? ajuda}) =>
        InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          isDense: true,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        );
    const estiloCampo = TextStyle(fontSize: 14);

    final salvou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(
            atual == null ? 'Nova campanha de doação' : 'Editar campanha',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: logoBytes != null
                                ? Image.memory(logoBytes!, fit: BoxFit.cover)
                                : logoAtual.isNotEmpty
                                ? Image.network(
                                    ApiConfig.buildUrl(logoAtual),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.volunteer_activism_rounded,
                                    ),
                                  )
                                : const ColoredBox(
                                    color: Color(0xFFFFF3CD),
                                    child: Icon(
                                      Icons.volunteer_activism_rounded,
                                      color: Color(0xFF9A6700),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final arquivo = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 88,
                              );
                              if (arquivo == null) return;
                              final bytes = await arquivo.readAsBytes();
                              atualizar(() {
                                logoSelecionada = arquivo;
                                logoBytes = bytes;
                              });
                            },
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              logoSelecionada == null
                                  ? 'Escolher logo da campanha'
                                  : 'Trocar logo da campanha',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nome,
                      style: estiloCampo,
                      decoration: decoracaoCampo('Nome da campanha'),
                      validator: (valor) => (valor ?? '').trim().length < 3
                          ? 'Informe o nome da campanha.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: beneficiario,
                      style: estiloCampo,
                      decoration: decoracaoCampo('Beneficiário / destino'),
                      validator: (valor) => (valor ?? '').trim().length < 3
                          ? 'Informe quem receberá a doação.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: pix,
                      style: estiloCampo,
                      decoration: decoracaoCampo(
                        'Chave PIX (para identificação)',
                      ),
                      validator: (valor) => (valor ?? '').trim().length < 3
                          ? 'Informe a chave PIX.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: wallet,
                      style: estiloCampo,
                      decoration: decoracaoCampo(
                        'Wallet ID Asaas do beneficiário',
                        ajuda:
                            'Use o Wallet ID do Asaas; não informe a chave PIX.',
                      ),
                      validator: (valor) =>
                          RegExp(
                            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                          ).hasMatch((valor ?? '').trim())
                          ? null
                          : 'Informe o Wallet ID Asaas, não a chave PIX.',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: eventoId,
                      style: estiloCampo,
                      isDense: true,
                      decoration: decoracaoCampo('Aplicar em'),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('Toda a loja (produtos e eventos)'),
                        ),
                        ..._eventos.map(
                          (evento) => DropdownMenuItem(
                            value: (evento['evento_id'] as num).toInt(),
                            child: Text('Evento: ${evento['nmtituloevento']}'),
                          ),
                        ),
                      ],
                      onChanged: (valor) =>
                          atualizar(() => eventoId = valor ?? -1),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: percentual,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: estiloCampo,
                      decoration: decoracaoCampo(
                        'Percentual destinado à campanha',
                      ),
                      validator: (valor) {
                        final numero = double.tryParse(
                          (valor ?? '').replaceAll(',', '.'),
                        );
                        return numero == null || numero <= 0 || numero > 100
                            ? 'Informe um percentual entre 0,01 e 100.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: mensagem,
                      maxLines: 2,
                      style: estiloCampo,
                      decoration: decoracaoCampo(
                        'Mensagem para o cliente (opcional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Campanha ativa',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Somente uma campanha ativa é aplicada por estabelecimento.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: ativa,
                      onChanged: (valor) => atualizar(() => ativa = valor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dados = <String, dynamic>{
                  'nmcampanha': nome.text.trim(),
                  'nmbeficiario': beneficiario.text.trim(),
                  'chavepix': pix.text.trim(),
                  'asaas_wallet_id': wallet.text.trim(),
                  'percentual_doacao': double.parse(
                    percentual.text.replaceAll(',', '.'),
                  ),
                  'dsmensagem': mensagem.text.trim().isEmpty
                      ? null
                      : mensagem.text.trim(),
                  'evento_id': eventoId > 0 ? eventoId : null,
                  'sitcampanha': ativa ? 'ATIVA' : 'INATIVA',
                };
                try {
                  final resposta = atual == null
                      ? _resposta(
                          await ApiService.post(
                            '/campanhas-doacao/lojas/$lojaId',
                            dados,
                          ),
                        )
                      : _resposta(
                          await ApiService.put(
                            '/campanhas-doacao/${atual['campanha_doacao_id']}',
                            dados,
                          ),
                        );
                  if (logoSelecionada != null) {
                    final campanhaId = int.tryParse(
                      '${(resposta as Map)['campanha_doacao_id'] ?? ''}',
                    );
                    if (campanhaId == null) {
                      throw Exception(
                        'A campanha não retornou um identificador.',
                      );
                    }
                    await _enviarLogoCampanha(campanhaId, logoSelecionada!);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (erro) {
                  if (dialogContext.mounted) {
                    AppSnackBar.erro(
                      dialogContext,
                      erro.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    nome.dispose();
    beneficiario.dispose();
    pix.dispose();
    wallet.dispose();
    percentual.dispose();
    mensagem.dispose();
    if (salvou == true) await _carregarCampanhas();
  }

  Future<void> _inativar(Map<String, dynamic> campanha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inativar campanha?'),
        content: Text(
          'A campanha "${campanha['nome']}" deixará de ser aplicada nas novas compras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Inativar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      _resposta(
        await ApiService.delete(
          '/campanhas-doacao/${campanha['campanha_doacao_id']}',
        ),
      );
      await _carregarCampanhas();
      if (mounted) AppSnackBar.sucesso(context, 'Campanha inativada.');
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      floatingActionButton: _lojaId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editar(),
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: const Text('Nova campanha'),
            ),
      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Para quem doar?',
            subtitulo:
                'Destine parte das vendas a uma entidade ou campanha de necessidade.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<int>(
              key: ValueKey(_lojaId),
              initialValue: _lojaId,
              decoration: const InputDecoration(labelText: 'Estabelecimento'),
              items: _lojas
                  .map(
                    (loja) => DropdownMenuItem(
                      value: loja.lojaId,
                      child: Text(loja.nmloja),
                    ),
                  )
                  .toList(),
              onChanged: _carregando ? null : _trocarLoja,
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _campanhas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nenhuma campanha cadastrada. Cadastre uma entidade ou uma situação emergencial para começar.',
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregarCampanhas,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: _campanhas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, indice) {
                        final campanha = _campanhas[indice];
                        final ativa =
                            '${campanha['situacao']}'.toUpperCase() == 'ATIVA';
                        final percentual =
                            double.tryParse(
                              '${campanha['percentual_doacao']}',
                            ) ??
                            0;
                        final eventoId = (campanha['evento_id'] as num?)
                            ?.toInt();
                        final evento = eventoId == null
                            ? null
                            : _eventos.cast<Map<String, dynamic>?>().firstWhere(
                                (item) => item?['evento_id'] == eventoId,
                                orElse: () => null,
                              );
                        return Card(
                          child: ListTile(
                            leading: ClipOval(
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child:
                                    '${campanha['url_logo'] ?? ''}'
                                        .trim()
                                        .isEmpty
                                    ? CircleAvatar(
                                        backgroundColor: ativa
                                            ? const Color(0xFFE4F5E8)
                                            : Colors.grey.shade200,
                                        child: Icon(
                                          Icons.volunteer_activism_outlined,
                                          color: ativa
                                              ? const Color(0xFF18743A)
                                              : Colors.grey,
                                        ),
                                      )
                                    : Image.network(
                                        ApiConfig.buildUrl(
                                          '${campanha['url_logo']}',
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.volunteer_activism_outlined,
                                          color: ativa
                                              ? const Color(0xFF18743A)
                                              : Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              '${campanha['nome']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${campanha['beneficiario']}\n${percentual.toStringAsFixed(percentual % 1 == 0 ? 0 : 2)}% do valor líquido • ${evento == null ? 'Toda a loja' : 'Evento: ${evento['nmtituloevento']}'} • ${ativa ? 'Ativa' : 'Inativa'}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (acao) => acao == 'editar'
                                  ? _editar(campanha)
                                  : _inativar(campanha),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                                if (ativa)
                                  const PopupMenuItem(
                                    value: 'inativar',
                                    child: Text('Inativar'),
                                  ),
                              ],
                            ),
                            onTap: () => _editar(campanha),
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
