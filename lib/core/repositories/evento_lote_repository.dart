import 'dart:convert';

import '../../models/evento_lote.dart';
import '../services/api_service.dart';

class EventoLoteRepository {
  Exception _erro(dynamic response, String mensagemPadrao) {
    try {
      final conteudo = jsonDecode(response.body);
      if (conteudo is Map && conteudo['detail'] != null) {
        final detalhe = conteudo['detail'].toString().trim();
        if (detalhe.isNotEmpty) return Exception(detalhe);
      }
    } catch (_) {}
    return Exception(mensagemPadrao);
  }

  Future<List<EventoLote>> listar(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/lotes_todos');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => EventoLote.fromJson(e)).toList();
    }

    throw _erro(response, 'Não foi possível carregar os lotes do evento.');
  }

  Future<List<EventoLoteGlobal>> listarGlobais(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/lotes-globais');
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar os lotes do evento.');
    }
    return (jsonDecode(response.body) as List)
        .map(
          (item) => EventoLoteGlobal.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> criarGlobal({
    required int eventoId,
    required int organizacaoId,
    required int lojaId,
    required String nome,
    String? inicioVendas,
    required String fimVendas,
    required String gatilhoVirada,
    required List<Map<String, dynamic>> setores,
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/lotes', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'nmlote': nome,
      'dtiniciovenda': ?inicioVendas,
      'dtfimvenda': fimVendas,
      'gatilhovirada': gatilhoVirada,
      'setores': setores,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o lote global.');
    }
  }

  Future<void> atualizarGlobal({
    required int loteGlobalId,
    String? nome,
    String? inicioVendas,
    String? fimVendas,
    String? gatilhoVirada,
    String? situacao,
  }) async {
    final response =
        await ApiService.put('/eventos/lotes-globais/$loteGlobalId', {
          'nmlote': ?nome,
          'dtiniciovenda': ?inicioVendas,
          'dtfimvenda': ?fimVendas,
          'gatilhovirada': ?gatilhoVirada,
          'situacao': ?situacao,
        });
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o lote global.');
    }
  }

  Future<void> atualizarConfiguracaoSetor({
    required int loteId,
    int? limite,
    List<EventoLotePreco>? precos,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'qtlimite': ?limite,
      if (precos != null)
        'precos': precos
            .map(
              (preco) => {
                'nmpreco': preco.nome.trim(),
                'tipopreco': preco.tipo,
                'vrpreco': preco.valor,
                'aplicacotalegal': preco.aplicaCotaLegal,
                'exigecomprovante': preco.exigeComprovante,
                'situacao': preco.situacao,
                'nrordem': preco.ordem,
              },
            )
            .toList(),
    });
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o setor do lote.');
    }
  }

  Future<void> excluirSetorDoLote(int loteId) async {
    final response = await ApiService.delete('/eventos/lotes/$loteId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _erro(response, 'Não foi possível excluir o setor deste lote.');
    }
  }

  Future<void> excluirGlobal(int loteGlobalId) async {
    final response = await ApiService.delete(
      '/eventos/lotes-globais/$loteGlobalId',
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _erro(response, 'Não foi possível excluir o lote global.');
    }
  }

  Future<CapacidadeEvento> obterCapacidadeEvento(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/capacidade');
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível carregar a capacidade do evento.',
      );
    }
    return CapacidadeEvento.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<CapacidadeEvento> atualizarCapacidadeEvento({
    required int eventoId,
    required int capacidade,
  }) async {
    final response = await ApiService.put('/eventos/$eventoId/capacidade', {
      'qtcapacidadeevento': capacidade,
    });
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível atualizar a capacidade do evento.',
      );
    }
    return CapacidadeEvento.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<void> criar({
    required int eventoId,
    required int organizacaoId,
    required int lojaId,
    required String nome,
    required double preco,
    required int quantidadeTotal,
    required int quantidadeVendida,
    String? dtInicioVenda,
    String? dtFimVenda,
    String status = 'ATIVO',
    int? eventoSetorId,
    int numeroLote = 1,
    String tipoIngresso = 'UNICO',
    bool usarCapacidadeRestante = false,
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/lotes', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'nmlote': nome,
      'eventosetor_id': eventoSetorId,
      'nrlote': numeroLote,
      'qttotallote': usarCapacidadeRestante ? null : quantidadeTotal,
      'usarcapacidaderestante': usarCapacidadeRestante,
      'precos': _precosPadrao(preco),
      'dtiniciovenda': dtInicioVenda,
      'dtfimvenda': dtFimVenda,
      'statuslote': status,
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o lote.');
    }
  }

  Future<void> atualizar({
    required int loteId,
    int? organizacaoId,
    int? lojaId,
    int? eventoId,
    String? nome,
    double? preco,
    int? quantidadeTotal,
    int? quantidadeVendida,
    String? dtInicioVenda,
    String? dtFimVenda,
    String? status,
    int? eventoSetorId,
    int? numeroLote,
    String? tipoIngresso,
    bool? usarCapacidadeRestante,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'nmlote': nome,
      'eventosetor_id': eventoSetorId,
      'nrlote': numeroLote,
      'qttotallote': usarCapacidadeRestante == true ? null : quantidadeTotal,
      'usarcapacidaderestante': usarCapacidadeRestante,
      if (preco != null) 'precos': _precosPadrao(preco),
      'dtiniciovenda': dtInicioVenda,
      'dtfimvenda': dtFimVenda,
      'statuslote': status,
    });

    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o lote.');
    }
  }

  Future<void> atualizarPeriodoVendas({
    required int loteId,
    required String dtInicioVenda,
    required String dtFimVenda,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'dtiniciovenda': dtInicioVenda,
      'dtfimvenda': dtFimVenda,
    });

    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o período de vendas.');
    }
  }

  Future<void> atualizarModalidades({
    required int loteId,
    required List<EventoLotePreco> precos,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'precos': precos
          .map(
            (preco) => {
              'nmpreco': preco.nome.trim(),
              'tipopreco': preco.tipo,
              'vrpreco': preco.valor,
              'aplicacotalegal': preco.aplicaCotaLegal,
              'exigecomprovante': preco.exigeComprovante,
              'situacao': preco.situacao,
              'nrordem': preco.ordem,
            },
          )
          .toList(),
    });

    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar as modalidades.');
    }
  }

  List<Map<String, dynamic>> _precosPadrao(double inteira) => [
    {
      'nmpreco': 'Inteira',
      'tipopreco': 'INTEIRA',
      'vrpreco': inteira,
      'aplicacotalegal': false,
      'exigecomprovante': false,
      'nrordem': 1,
    },
    {
      'nmpreco': 'Meia-entrada',
      'tipopreco': 'MEIA_LEGAL',
      'vrpreco': inteira / 2,
      'aplicacotalegal': true,
      'exigecomprovante': true,
      'nrordem': 2,
    },
    {
      'nmpreco': 'Pessoa idosa',
      'tipopreco': 'MEIA_IDOSO',
      'vrpreco': inteira / 2,
      'aplicacotalegal': false,
      'exigecomprovante': true,
      'nrordem': 3,
    },
  ];

  Future<List<EventoSetor>> listarSetores(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/setores');
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar os setores.');
    }
    return (jsonDecode(response.body) as List)
        .map((e) => EventoSetor.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EventoSetor> criarSetor({
    required int eventoId,
    required String nome,
    required int capacidade,
    String descricao = '',
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/setores', {
      'nmsetor': nome,
      'dssetor': descricao,
      'qtcapacidade': capacidade,
      'nrordem': 1,
      'sitsetor': 'ATIVO',
    });
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o setor.');
    }
    return EventoSetor.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<EventoSetor> atualizarSetor({
    required EventoSetor setor,
    required String nome,
    required int capacidade,
  }) async {
    final response = await ApiService.put('/eventos/setores/${setor.id}', {
      'nmsetor': nome.trim(),
      'dssetor': setor.descricao,
      'qtcapacidade': capacidade,
      'nrordem': setor.ordem,
      'sitsetor': setor.situacao,
    });
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o setor.');
    }
    return EventoSetor.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<void> excluirSetor(int setorId) async {
    final response = await ApiService.delete('/eventos/setores/$setorId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _erro(response, 'Não foi possível excluir o setor.');
    }
  }

  Future<void> excluir(int loteId) async {
    final response = await ApiService.delete('/eventos/lotes/$loteId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _erro(response, 'Não foi possível excluir o lote.');
    }
  }
}
