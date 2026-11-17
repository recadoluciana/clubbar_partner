import 'dart:convert';
import 'package:web/web.dart' as web;

bool baixarArquivo(String conteudo, String nome, String mime) {
  final uri = Uri.dataFromString(conteudo, mimeType: mime, encoding: utf8);
  final link = web.HTMLAnchorElement()
    ..href = uri.toString()
    ..download = nome;
  link.click();
  return true;
}
