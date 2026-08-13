class Categoria {
  final int categoriaId;
  final String nmcategoria;
  final String? sitcategoria;
  final int? organizacaoId;
  final int? lojaId;
  final int? idordcategoria;

  Categoria({
    required this.categoriaId,
    required this.nmcategoria,
    required this.idordcategoria,
    this.sitcategoria,
    this.organizacaoId,
    this.lojaId,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      categoriaId: json['categoria_id'] ?? 0,
      nmcategoria: json['nmcategoria'] ?? '',
      idordcategoria: json['idordcategoria'] ?? 0,
      sitcategoria: json['sitcategoria']?.toString(),
      organizacaoId: json['organizacao_id'],
      lojaId: json['loja_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoria_id': categoriaId,
      'nmcategoria': nmcategoria,
      'idordcategoria': idordcategoria,
      'sitcategoria': sitcategoria,
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
    };
  }
}
