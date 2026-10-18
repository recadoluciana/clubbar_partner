import '../core/utils/horario_brasil.dart';

class ProdutoPendente {
  final int lojaId;
  final String loja;
  final String produto;
  final String imagemProduto;
  final int quantidade;
  final double valorTotal;

  const ProdutoPendente({
    required this.lojaId,
    required this.loja,
    required this.produto,
    required this.imagemProduto,
    required this.quantidade,
    required this.valorTotal,
  });

  factory ProdutoPendente.fromJson(Map<String, dynamic> json) =>
      ProdutoPendente(
        lojaId: (json['loja_id'] as num).toInt(),
        loja: json['nmloja']?.toString() ?? '',
        produto: json['nmproduto']?.toString() ?? '',
        imagemProduto: json['urlfotoproduto']?.toString() ?? '',
        quantidade: (json['quantidade_pendente'] as num?)?.toInt() ?? 0,
        valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
      );
}

class ProdutosPendentesResumo {
  final int quantidadeTotal;
  final double valorTotal;
  final List<ProdutoPendente> itens;

  const ProdutosPendentesResumo({
    required this.quantidadeTotal,
    required this.valorTotal,
    required this.itens,
  });

  factory ProdutosPendentesResumo.fromJson(
    Map<String, dynamic> json,
  ) => ProdutosPendentesResumo(
    quantidadeTotal: (json['quantidade_total'] as num?)?.toInt() ?? 0,
    valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
    itens: ((json['itens'] as List?) ?? const [])
        .map(
          (item) =>
              ProdutoPendente.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class CompraProduto {
  final int itemVendaId;
  final int vendaId;
  final String loja;
  final String cliente;
  final String emailCliente;
  final String produto;
  final String imagemProduto;
  final int quantidade;
  final double precoUnitario;
  final double valorTotal;
  final DateTime dataCompra;
  final bool retirado;
  final DateTime? dataRetirada;
  final String responsavelRetirada;
  final bool cortesia;

  const CompraProduto({
    required this.itemVendaId,
    required this.vendaId,
    required this.loja,
    required this.cliente,
    required this.emailCliente,
    required this.produto,
    required this.imagemProduto,
    required this.quantidade,
    required this.precoUnitario,
    required this.valorTotal,
    required this.dataCompra,
    required this.retirado,
    required this.dataRetirada,
    required this.responsavelRetirada,
    required this.cortesia,
  });

  factory CompraProduto.fromJson(Map<String, dynamic> json) => CompraProduto(
    itemVendaId: (json['itvenda_id'] as num).toInt(),
    vendaId: (json['venda_id'] as num).toInt(),
    loja: json['nmloja']?.toString() ?? '',
    cliente: json['nmcliente']?.toString() ?? 'Cliente não identificado',
    emailCliente: json['emailcliente']?.toString() ?? '',
    produto: json['nmproduto']?.toString() ?? '',
    imagemProduto: json['urlfotoproduto']?.toString() ?? '',
    quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
    precoUnitario: (json['preco_unitario'] as num?)?.toDouble() ?? 0,
    valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
    dataCompra: HorarioBrasil.deTextoBrasil(json['dtcompra']) ?? DateTime(1970),
    retirado: json['retirado'] == true,
    dataRetirada: HorarioBrasil.deTextoBrasil(json['dtretirada']),
    responsavelRetirada: json['responsavel_retirada']?.toString() ?? '',
    cortesia: json['cortesia'] == true,
  );
}

class EventoVendaResumo {
  final int eventoId;
  final String nome;
  final String loja;
  final String imagemEvento;
  final DateTime dataHora;
  final String status;
  final int quantidade;
  final double valorTotal;

  const EventoVendaResumo({
    required this.eventoId,
    required this.nome,
    required this.loja,
    required this.imagemEvento,
    required this.dataHora,
    required this.status,
    required this.quantidade,
    required this.valorTotal,
  });

  factory EventoVendaResumo.fromJson(Map<String, dynamic> json) =>
      EventoVendaResumo(
        eventoId: (json['evento_id'] as num).toInt(),
        nome: json['nmtituloevento']?.toString() ?? '',
        loja: json['nmloja']?.toString() ?? '',
        imagemEvento: json['urlbannerevento']?.toString() ?? '',
        dataHora: DateTime.parse(json['dtinicioevento'].toString()),
        status: json['statusevento']?.toString() ?? '',
        quantidade: (json['quantidade_vendida'] as num?)?.toInt() ?? 0,
        valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
      );
}

class LoteVendaResumo {
  final int loteId;
  final int numero;
  final String nome;
  final String setor;
  final String tipo;
  final double valorUnitario;
  final int quantidade;
  final int quantidadeVendidaLote;
  final int? capacidadeLote;
  final int? quantidadeRestante;
  final double valorTotal;

  const LoteVendaResumo({
    required this.loteId,
    required this.numero,
    required this.nome,
    required this.setor,
    required this.tipo,
    required this.valorUnitario,
    required this.quantidade,
    required this.quantidadeVendidaLote,
    required this.capacidadeLote,
    required this.quantidadeRestante,
    required this.valorTotal,
  });

  factory LoteVendaResumo.fromJson(Map<String, dynamic> json) =>
      LoteVendaResumo(
        loteId: (json['lote_id'] as num).toInt(),
        numero: (json['nrlote'] as num?)?.toInt() ?? 0,
        nome: json['nmlote']?.toString() ?? '',
        setor: json['setor']?.toString() ?? '',
        tipo: json['tipo']?.toString() ?? '',
        valorUnitario: (json['valor_unitario'] as num?)?.toDouble() ?? 0,
        quantidade: (json['quantidade_vendida'] as num?)?.toInt() ?? 0,
        quantidadeVendidaLote:
            (json['quantidade_vendida_lote'] as num?)?.toInt() ?? 0,
        capacidadeLote: (json['capacidade_lote'] as num?)?.toInt(),
        quantidadeRestante: (json['quantidade_restante'] as num?)?.toInt(),
        valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
      );
}

class EventoVendaDetalhe {
  final String nome;
  final DateTime dataHora;
  final int quantidade;
  final int quantidadePendente;
  final int capacidadeTotal;
  final int quantidadeRestante;
  final double percentualOcupacao;
  final double valorTotal;
  final List<LoteVendaResumo> lotes;

  const EventoVendaDetalhe({
    required this.nome,
    required this.dataHora,
    required this.quantidade,
    required this.quantidadePendente,
    required this.capacidadeTotal,
    required this.quantidadeRestante,
    required this.percentualOcupacao,
    required this.valorTotal,
    required this.lotes,
  });

  factory EventoVendaDetalhe.fromJson(
    Map<String, dynamic> json,
  ) => EventoVendaDetalhe(
    nome: json['nmtituloevento']?.toString() ?? '',
    dataHora: DateTime.parse(json['dtinicioevento'].toString()),
    quantidade: (json['quantidade_vendida'] as num?)?.toInt() ?? 0,
    quantidadePendente: (json['quantidade_pendente'] as num?)?.toInt() ?? 0,
    capacidadeTotal: (json['capacidade_total'] as num?)?.toInt() ?? 0,
    quantidadeRestante: (json['quantidade_restante'] as num?)?.toInt() ?? 0,
    percentualOcupacao: (json['percentual_ocupacao'] as num?)?.toDouble() ?? 0,
    valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0,
    lotes: ((json['lotes'] as List?) ?? const [])
        .map(
          (item) =>
              LoteVendaResumo.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class IngressoVendido {
  final int id;
  final int quantidade;
  final double preco;
  final double taxa;
  final int vendaId;
  final DateTime dataCompra;
  final String cliente;
  final String telefoneCliente;
  final String participante;
  final String cpfParticipante;
  final int numeroLote;
  final String lote;
  final String setor;
  final String modalidade;
  final bool utilizado;
  final DateTime? dataValidacao;

  const IngressoVendido({
    required this.id,
    required this.quantidade,
    required this.preco,
    required this.taxa,
    required this.vendaId,
    required this.dataCompra,
    required this.cliente,
    required this.telefoneCliente,
    required this.participante,
    required this.cpfParticipante,
    required this.numeroLote,
    required this.lote,
    required this.setor,
    required this.modalidade,
    required this.utilizado,
    required this.dataValidacao,
  });

  factory IngressoVendido.fromJson(Map<String, dynamic> json) =>
      IngressoVendido(
        id: (json['itvenda_id'] as num).toInt(),
        quantidade: (json['quantidade'] as num?)?.toInt() ?? 1,
        preco: (json['preco'] as num?)?.toDouble() ?? 0,
        taxa: (json['taxa'] as num?)?.toDouble() ?? 0,
        vendaId: (json['venda_id'] as num).toInt(),
        dataCompra:
            HorarioBrasil.deTextoBrasil(json['dtcompra']) ?? DateTime(1970),
        cliente: json['cliente']?.toString() ?? '',
        telefoneCliente: json['telefone_cliente']?.toString() ?? '',
        participante: json['participante']?.toString() ?? '',
        cpfParticipante: json['cpf_participante']?.toString() ?? '',
        numeroLote: (json['numero_lote'] as num?)?.toInt() ?? 0,
        lote: json['lote']?.toString() ?? '',
        setor: json['setor']?.toString() ?? '',
        modalidade: json['modalidade']?.toString() ?? '',
        utilizado: json['utilizado'] == true,
        dataValidacao: HorarioBrasil.deTextoBrasil(json['dtvalidacao']),
      );
}
