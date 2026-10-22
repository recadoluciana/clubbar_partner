import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as client;

export 'package:http/http.dart'
    show MultipartFile, MultipartRequest, Response, StreamedResponse;

// Evita que uma tela permaneça carregando indefinidamente quando a rede ou a
// API estiver indisponível. Operações de escrita não recebem repetição
// automática: em caso de falha, a tela deve consultar o estado antes de tentar
// novamente para não duplicar cadastros, vendas ou entregas.
const Duration _readTimeout = Duration(seconds: 20);
const Duration _writeTimeout = Duration(seconds: 30);

Future<client.Response> _executar(
  Future<client.Response> Function(client.Client) requisicao,
  Duration limite,
) async {
  final httpClient = client.Client();
  try {
    return await requisicao(httpClient).timeout(
      limite,
      onTimeout: () {
        httpClient.close();
        throw TimeoutException('Tempo limite de conexão excedido', limite);
      },
    );
  } finally {
    httpClient.close();
  }
}

Future<client.Response> get(Uri url, {Map<String, String>? headers}) =>
    _executar(
      (httpClient) => httpClient.get(url, headers: headers),
      _readTimeout,
    );

Future<client.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _executar(
  (httpClient) =>
      httpClient.post(url, headers: headers, body: body, encoding: encoding),
  _writeTimeout,
);

Future<client.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _executar(
  (httpClient) =>
      httpClient.put(url, headers: headers, body: body, encoding: encoding),
  _writeTimeout,
);

Future<client.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _executar(
  (httpClient) =>
      httpClient.patch(url, headers: headers, body: body, encoding: encoding),
  _writeTimeout,
);

Future<client.Response> delete(Uri url, {Map<String, String>? headers}) =>
    _executar(
      (httpClient) => httpClient.delete(url, headers: headers),
      _writeTimeout,
    );

Future<client.StreamedResponse> sendMultipart(
  client.MultipartRequest request,
) => request.send().timeout(
  _writeTimeout,
  onTimeout: () =>
      throw TimeoutException('Tempo limite de envio excedido', _writeTimeout),
);
