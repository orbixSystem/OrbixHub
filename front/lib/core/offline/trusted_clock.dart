import 'package:shared_preferences/shared_preferences.dart';

/// S3 — relógio confiável (anti clock-rollback).
///
/// Guarda o maior timestamp já observado (`max_seen_ts`, device ou servidor)
/// e persiste esse valor: se o relógio do device for adiantado/atrasado
/// manualmente para trás do que já vimos, [clockRolledBack] denuncia. Usado
/// pelo login offline (B6) para recusar sessões cujo device parece ter tido o
/// relógio manipulado para reabrir uma sessão expirada/revogada.
///
/// Observar o tempo do servidor (respostas da API) é responsabilidade de quem
/// chama [observe] — este objeto só guarda o maior valor e detecta o desvio.
///
/// **Cold start:** o `max_seen_ts` persistido é carregado de forma assíncrona.
/// Quem depende de [clockRolledBack] para decisão de segurança (B6, login
/// offline) DEVE aguardar [ready] antes de confiar no valor — antes disso um
/// rollback real pode passar despercebido (falso negativo).
class TrustedClock {
  TrustedClock({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _key = 'orbix_trusted_clock_max_seen_ts';

  /// Tolerância para ajustes legítimos de relógio (fuso, horário de
  /// verão, deriva de NTP) antes de acusar rollback.
  static const tolerance = Duration(minutes: 5);

  final DateTime Function() _clock;

  DateTime? _maxSeenTs;
  Future<void>? _loading;

  /// Relógio do device (ou o injetado nos testes) — não é o `max_seen_ts`.
  DateTime get now => _clock();

  /// Maior timestamp já observado (via [observe]), ou `null` antes do
  /// primeiro `observe`/`load`.
  DateTime? get maxSeenTs => _maxSeenTs;

  /// `true` quando o relógio do device está atrasado em relação ao maior
  /// timestamp já visto, além da [tolerance]. Sem nenhum `max_seen_ts` ainda
  /// (nada observado/carregado), não há evidência de rollback.
  ///
  /// Para decisão de segurança, aguarde [ready] antes de ler — só então o
  /// valor persistido está garantidamente em memória.
  bool get clockRolledBack {
    final max = _maxSeenTs;
    if (max == null) return false;
    return now.isBefore(max.subtract(tolerance));
  }

  /// Completa quando o `max_seen_ts` persistido foi carregado ([load]).
  /// Memoizado — seguro aguardar quantas vezes for preciso. O consumidor de
  /// segurança (B6) DEVE `await ready` antes de confiar em [clockRolledBack].
  Future<void> get ready => load();

  /// Carrega o `max_seen_ts` persistido para memória. Idempotente/seguro
  /// chamar mais de uma vez (chamadas concorrentes compartilham o mesmo
  /// carregamento). Deve rodar no bootstrap do app antes de confiar em
  /// [clockRolledBack]. Nunca sobrescreve um valor mais recente já observado
  /// em memória (ex.: `observe` chamado antes do `load` terminar).
  Future<void> load() {
    return _loading ??= () async {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_key);
      if (iso == null) return;
      final persisted = DateTime.tryParse(iso);
      if (persisted == null) return;
      if (_maxSeenTs == null || persisted.isAfter(_maxSeenTs!)) {
        _maxSeenTs = persisted;
      }
    }();
  }

  /// Registra um timestamp observado (relógio local ou de uma resposta do
  /// servidor) — mantém só o maior já visto, persistido para sobreviver a
  /// restart/reinstalação não conseguir "esquecer" um rollback.
  Future<void> observe(DateTime ts) async {
    if (_maxSeenTs != null && !ts.isAfter(_maxSeenTs!)) return;
    _maxSeenTs = ts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ts.toUtc().toIso8601String());
  }
}
