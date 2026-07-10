import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/cashier_models.dart';
import '../domain/cashier_repository.dart';

/// [CashierRepository] real, sobre dio.
class CashierRepositoryImpl implements CashierRepository {
  CashierRepositoryImpl(this._dio, this._deviceId);

  final Dio _dio;

  /// Id estável do device (uuid v4, `DeviceIdentity`/B2) que identifica o
  /// PONTO de caixa (dispositivo/terminal) nas rotas de sessão/lançamento —
  /// injetado como função (não valor) para não travar a construção do repo
  /// enquanto o SharedPreferences resolve; cada chamada aguarda e envia o id
  /// atual. Cada navegador/instalação tem o seu (inclusive na web).
  final Future<String> Function() _deviceId;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// Resolve o deviceId degradando graciosamente: se a leitura falhar (ex.:
  /// falha de plataforma do SharedPreferences na primeira leitura), retorna
  /// null e a chamada segue SEM o campo — o backend trata `deviceId` como
  /// opcional (ausente = ponto legado/NULL). Assim uma exceção crua da fonte
  /// do id nunca vaza por fora do contrato [AppException] nem derruba o caixa.
  Future<String?> _deviceIdOrNull() async {
    try {
      return await _deviceId();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(Object? data) =>
      (data as Map).cast<String, dynamic>();

  @override
  Future<CashierConfig> fetchConfig() => _guard(() async {
        final res = await _dio.get<Object?>('/cashier/config');
        return CashierConfig.fromJson(_asMap(res.data));
      });

  @override
  Future<CashierConfig> updateConfig({
    List<String>? paymentMethods,
    bool? requireOpenSession,
    bool? countCashOnly,
  }) =>
      _guard(() async {
        final res = await _dio.patch<Object?>('/cashier/config', data: {
          'paymentMethods': ?paymentMethods,
          'requireOpenSession': ?requireOpenSession,
          'countCashOnly': ?countCashOnly,
        });
        return CashierConfig.fromJson(_asMap(res.data));
      });

  @override
  Future<CashSession?> currentSession() => _guard(() async {
        final deviceId = await _deviceIdOrNull();
        final res = await _dio.get<Object?>(
          '/cashier/sessions/current',
          queryParameters: {'deviceId': ?deviceId},
        );
        final data = res.data;
        if (data == null || (data is Map && data.isEmpty)) return null;
        return CashSession.fromJson(_asMap(data));
      });

  @override
  Future<CashSession> openSession({double? openingAmount, String? notes}) =>
      _guard(() async {
        final deviceId = await _deviceIdOrNull();
        final res = await _dio.post<Object?>('/cashier/sessions/open', data: {
          'openingAmount': ?openingAmount,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'deviceId': ?deviceId,
        });
        return CashSession.fromJson(_asMap(res.data));
      });

  @override
  Future<CashSession> closeSession({
    required double countedAmount,
    String? notes,
  }) =>
      _guard(() async {
        final deviceId = await _deviceIdOrNull();
        final res = await _dio.post<Object?>('/cashier/sessions/close', data: {
          'countedAmount': countedAmount,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'deviceId': ?deviceId,
        });
        return CashSession.fromJson(_asMap(res.data));
      });

  @override
  Future<SessionPage> listSessions({int page = 1}) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/cashier/sessions',
          queryParameters: {'page': page},
        );
        return SessionPage.fromJson(_asMap(res.data));
      });

  @override
  Future<CashEntry> createEntry(EntryDraft draft) => _guard(() async {
        final deviceId = await _deviceIdOrNull();
        final res = await _dio.post<Object?>('/cashier/entries', data: {
          ...draft.toJson(),
          'deviceId': ?deviceId,
        });
        return CashEntry.fromJson(_asMap(res.data));
      });

  @override
  Future<CashEntry> reverseEntry(String id, String reason) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/cashier/entries/$id/reverse',
          data: {'reason': reason},
        );
        return CashEntry.fromJson(_asMap(res.data));
      });

  @override
  Future<EntryPage> listEntries({
    String? sessionId,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>('/cashier/entries', queryParameters: {
          'sessionId': ?sessionId,
          'direction': ?direction,
          'method': ?method,
          'category': ?category,
          'saleKind': ?saleKind,
          'saleId': ?saleId,
          'from': ?from,
          'to': ?to,
          'page': page,
        });
        return EntryPage.fromJson(_asMap(res.data));
      });

  @override
  Future<CashSummary> summary({String? from, String? to}) => _guard(() async {
        final res = await _dio.get<Object?>('/cashier/summary', queryParameters: {
          'from': ?from,
          'to': ?to,
        });
        return CashSummary.fromJson(_asMap(res.data));
      });

  @override
  Future<PaymentDetail> paymentSummary({
    required String saleKind,
    required String saleId,
    double? total,
  }) =>
      _guard(() async {
        final res =
            await _dio.get<Object?>('/cashier/payment-summary', queryParameters: {
          'saleKind': saleKind,
          'saleId': saleId,
          'total': ?total,
        });
        return PaymentDetail.fromJson(_asMap(res.data));
      });
}
