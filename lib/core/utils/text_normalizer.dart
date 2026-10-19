/// Normaliza texto para comparações de busca que não distinguem maiúsculas,
/// espaços nas extremidades ou acentuação do português.
String normalizarTextoBusca(String texto) {
  return texto
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');
}
