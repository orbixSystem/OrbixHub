import 'package:dio/dio.dart';

/// Hora do SERVIDOR, lida do header `Date` de toda resposta da API.
///
/// O login offline (B6) carimba `lastOnlineLoginAt` com esta hora — nunca com o
/// relógio do device, que o usuário pode adiantar para esticar a janela de 7
/// dias. Sem nenhuma resposta observada ainda, [lastServerTime] é `null` e quem
/// consome decide o fallback (o `TrustedClock`/S3 ainda protege do rollback).
class ServerTimeStore {
  DateTime? _last;

  /// Hora da última resposta do servidor (UTC), ou `null` se nada foi observado.
  DateTime? get lastServerTime => _last;

  /// Registra um instante do servidor — mantém o mais recente.
  void observe(DateTime ts) {
    final utc = ts.toUtc();
    if (_last == null || utc.isAfter(_last!)) _last = utc;
  }

  /// Registra o header HTTP `Date` (RFC 7231, ex.: `Mon, 13 Jul 2026 12:00:00 GMT`).
  /// Header ausente/ilegível é ignorado em silêncio.
  void observeHttpDate(String? httpDate) {
    final parsed = parseHttpDate(httpDate);
    if (parsed != null) observe(parsed);
  }

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  /// Parser do formato IMF-fixdate (`Sun, 06 Nov 1994 08:49:37 GMT`) — o único
  /// que servidores HTTP modernos emitem. Escrito à mão porque `HttpDate` vive
  /// em `dart:io` (não existe na web, e este arquivo é compilado lá também).
  /// Devolve `null` para qualquer coisa que não case.
  static DateTime? parseHttpDate(String? value) {
    if (value == null) return null;
    final m = RegExp(
      r'^\w{3},\s(\d{2})\s(\w{3})\s(\d{4})\s(\d{2}):(\d{2}):(\d{2})\sGMT$',
    ).firstMatch(value.trim());
    if (m == null) return null;
    final month = _months.indexOf(m.group(2)!.toLowerCase()) + 1;
    if (month == 0) return null;
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}

/// Interceptor que alimenta o [ServerTimeStore] com o header `Date` de toda
/// resposta (inclusive as de erro — um 401 também carrega a hora do servidor).
class ServerTimeInterceptor extends Interceptor {
  ServerTimeInterceptor(this._store);

  final ServerTimeStore _store;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _store.observeHttpDate(response.headers.value('date'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _store.observeHttpDate(err.response?.headers.value('date'));
    handler.next(err);
  }
}
