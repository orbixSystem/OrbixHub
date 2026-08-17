import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Uma linha por falha de HTTP, no console do app.
///
/// O motivo de existir: quando uma tela quebrava, o app ficava mudo — a UI
/// mostrava um estado vazio genérico e não havia nada no console dizendo QUAL
/// chamada falhou, com que status, nem como achar aquilo no servidor. Cada
/// falha agora sai assim:
///
/// ```
/// [HTTP] GET /public/track/abc -> 500 · req=8f2c… · Internal server error
/// [HTTP] POST /inventory -> SEM RESPOSTA (connectionError) · Connection refused
/// ```
///
/// O `req=` é o `x-request-id` que o backend também escreveu na linha de log
/// dele — é por ele que se casam os dois lados.
String formatFalhaHttp(DioException e) {
  final req = e.requestOptions;
  final res = e.response;
  final onde = '${req.method} ${req.path}';

  final partes = <String>[];
  if (res != null) {
    partes.add('$onde -> ${res.statusCode}');
  } else {
    // Sem resposta: servidor fora, DNS, timeout, CORS. Nunca invente status.
    partes.add('$onde -> SEM RESPOSTA (${e.type.name})');
  }

  final requestId = _requestId(res);
  if (requestId != null) partes.add('req=$requestId');

  final causa = _causa(e);
  if (causa != null && causa.isNotEmpty) partes.add(causa);

  return '[HTTP] ${partes.join(' · ')}';
}

String? _requestId(Response<dynamic>? res) {
  final data = res?.data;
  if (data is Map) {
    final noCorpo = data['requestId']?.toString();
    if (noCorpo != null && noCorpo.isNotEmpty) return noCorpo;
  }
  final noHeader = res?.headers.value('x-request-id');
  return (noHeader != null && noHeader.isNotEmpty) ? noHeader : null;
}

/// A causa TÉCNICA — inclusive a do `ValidationPipe` (array), que a UI esconde
/// de propósito. No log ela é justamente o que revela o descompasso entre o
/// que o app manda e o que o backend espera.
String? _causa(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final msg = data['message'];
    if (msg is List) return msg.join(', ');
    if (msg != null) return msg.toString();
  }
  if (data is String && data.isNotEmpty) return data;
  return e.message;
}

/// Interceptor que só OBSERVA: escreve a linha e repassa o erro intacto para
/// quem for tratá-lo (o `AuthInterceptor`, o repository, a tela).
class ErrorLogInterceptor extends Interceptor {
  ErrorLogInterceptor({void Function(String linha)? sink})
      : _sink = sink ?? _padrao;

  final void Function(String linha) _sink;

  // debugPrint (e não print) porque ele respeita o throttle do Flutter e some
  // no build de release.
  static void _padrao(String linha) => debugPrint(linha);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _sink(formatFalhaHttp(err));
    handler.next(err);
  }
}
