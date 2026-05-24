import 'dart:convert';
import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/repositories/usuario_repository.dart';
import '../../models/loja.dart';
import '../../models/usuario.dart';
import 'usuario_form_page.dart';

class UsuarioListPage extends StatefulWidget {
  final int organizacaoId;

  const UsuarioListPage({super.key, required this.organizacaoId});

  @override
  State<UsuarioListPage> createState() => _UsuarioListPageState();
}

class _UsuarioListPageState extends State<UsuarioListPage> {
  final _repository = UsuarioRepository();
  final _lojaRepository = LojaRepository();
  final _buscaController = TextEditingController();

  bool _carregando = true;

  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  List<Loja> _lojas = [];

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _extrairMensagemErro(Object e) {
    final texto = e.toString();

    try {
      final inicio = texto.indexOf('{');
      final fim = texto.lastIndexOf('}');

      if (inicio != -1 && fim != -1) {
        final jsonStr = texto.substring(inicio, fim + 1);
        final jsonMap = jsonDecode(jsonStr);

        if (jsonMap is Map && jsonMap['detail'] != null) {
          return jsonMap['detail'].toString();
        }
      }
    } catch (_) {}

    return texto.replaceAll('Exception:', '').trim();
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
    });

    try {
      final usuarios = await _repository.listar(widget.organizacaoId);
      final lojas = await _lojaRepository.listar(widget.organizacaoId);

      if (!mounted) return;

      setState(() {
        _usuarios = usuarios;
        _usuariosFiltrados = usuarios;
        _lojas = lojas;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_extrairMensagemErro(e))));
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _filtrar(String texto) {
    final busca = texto.trim().toLowerCase();

    setState(() {
      if (busca.isEmpty) {
        _usuariosFiltrados = _usuarios;
      } else {
        _usuariosFiltrados = _usuarios.where((usuario) {
          return usuario.usuarioId.toString().contains(busca) ||
              usuario.nmusuario.toLowerCase().contains(busca) ||
              usuario.emailuser.toLowerCase().contains(busca) ||
              (usuario.situsuario ?? '').toLowerCase().contains(busca);
        }).toList();
      }
    });
  }

  String _nomeLoja(int? lojaId) {
    if (lojaId == null) return '-';

    for (final loja in _lojas) {
      if (loja.lojaId == lojaId) {
        return loja.nmloja;
      }
    }

    return '-';
  }

  Future<void> _abrirNovoUsuario() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(organizacaoId: widget.organizacaoId),
      ),
    );

    if (result == true && mounted) {
      await _carregarTudo();
    }
  }

  Future<void> _abrirEdicao(Usuario usuario) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(
          organizacaoId: widget.organizacaoId,
          usuario: usuario,
        ),
      ),
    );

    if (result == true && mounted) {
      await _carregarTudo();
    }
  }

  Future<void> _confirmarExclusao(Usuario usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir o usuário "${usuario.nmusuario}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _repository.excluir(
        organizacaoId: widget.organizacaoId,
        usuarioId: usuario.usuarioId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário excluído com sucesso')),
      );

      _carregarTudo();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_extrairMensagemErro(e))));
    }
  }

  Widget _buildTabela() {
    if (_usuariosFiltrados.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Nenhum usuário encontrado.')),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Nome')),
            DataColumn(label: Text('E-mail')),
            DataColumn(label: Text('Loja')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ações')),
          ],
          rows: _usuariosFiltrados.map((usuario) {
            return DataRow(
              cells: [
                DataCell(Text(usuario.usuarioId.toString())),
                DataCell(Text(usuario.nmusuario)),
                DataCell(Text(usuario.emailuser)),
                DataCell(Text(_nomeLoja(usuario.lojaId))),
                DataCell(Text(usuario.situsuario ?? '-')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => _abrirEdicao(usuario),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        onPressed: () => _confirmarExclusao(usuario),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    onChanged: _filtrar,
                    decoration: const InputDecoration(
                      labelText: 'Buscar usuário',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _abrirNovoUsuario,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _carregarTudo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTabela(),
            ),
          ],
        ),
      ),
    );
  }
}
