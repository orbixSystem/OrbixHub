import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/cashier_format.dart';
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
  Future<double?> lastClosingAmount() => _guard(() async {
        final deviceId = await _deviceIdOrNull();
        // Filtra por PONTO de caixa: o troco na gaveta é daquele terminal, não
        // do caixa do vizinho. `status: closed` + ordenação desc no backend ⇒
        // a primeira linha é o último fechamento.
        final res = await _dio.get<Object?>(
          '/cashier/sessions',
          queryParameters: {
            'page': 1,
            'pageSize': 1,
            'status': 'closed',
            'deviceId': ?deviceId,
          },
        );
        final page = SessionPage.fromJson(_asMap(res.data));
        if (page.items.isEmpty) return null;
        final contado = page.items.first.closingAmountCounted;
        return contado == null ? null : moneyToDouble(contado);
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
  Future<CashEntry> updateEntry(
    String id, {
    String? description,
    String? category,
  }) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/cashier/entries/$id',
          data: {'description': ?description, 'category': ?category},
        );
        return CashEntry.fromJson(_asMap(res.data));
      });

  @override
  Future<CashEntry> correctEntry(
    String id, {
    required String reason,
    double? amount,
    String? method,
    String? category,
    String? description,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/cashier/entries/$id/correct',
          data: {
            'reason': reason,
            'amount': ?amount,
            'method': ?method,
            'category': ?category,
            'description': ?description,
          },
        );
        // Devolve o lançamento NOVO (o original fica estornado no histórico).
        return CashEntry.fromJson(_asMap(res.data));
      });

  @override
  Future<EntryPage> listEntries({
    String? sessionId,
    String? q,
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
          'q': ?q,
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

  // --- despesas fixas ---
  @override
  Future<List<ExpenseTemplate>> listExpenseTemplates({
    bool includeDisabled = false,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/cashier/expense-templates',
          queryParameters: {if (includeDisabled) 'includeDisabled': true},
        );
        final data = res.data;
        if (data is! List) return const <ExpenseTemplate>[];
        return data
            .map((e) => ExpenseTemplate.fromJson(_asMap(e)))
            .toList(growable: false);
      });

  @override
  Future<ExpenseTemplate> createExpenseTemplate(ExpenseTemplateDraft draft) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/cashier/expense-templates',
          data: draft.toJson(),
        );
        return ExpenseTemplate.fromJson(_asMap(res.data));
      });

  @override
  Future<ExpenseTemplate> updateExpenseTemplate(
    String id,
    ExpenseTemplateDraft draft,
  ) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/cashier/expense-templates/$id',
          data: draft.toJson(),
        );
        return ExpenseTemplate.fromJson(_asMap(res.data));
      });

  @override
  Future<ExpenseTemplate> disableExpenseTemplate(String id) =>
      _guard(() async {
        final res = await _dio.delete<Object?>('/cashier/expense-templates/$id');
        return ExpenseTemplate.fromJson(_asMap(res.data));
      });

  // --- parcelas de fiado ---

  @override
  Future<List<Installment>> listInstallments({
    required String saleKind,
    required String saleId,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/cashier/installments',
          queryParameters: {'saleKind': saleKind, 'saleId': saleId},
        );
        final data = res.data;
        if (data is! List) return const <Installment>[];
        return data
            .map((e) => Installment.fromJson(_asMap(e)))
            .toList(growable: false);
      });

  @override
  Future<void> createInstallmentPlan(InstallmentPlanDraft draft) =>
      _guard(() async {
        await _dio.post<void>('/cashier/installments', data: draft.toJson());
      });

  @override
  Future<Installment> payInstallment({
    required String installmentId,
    required String method,
    String? description,
    double discount = 0,
    String? discountReason,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/cashier/installments/$installmentId/pay',
          data: {
            'method': method,
            'description': ?description,
            if (discount > 0) 'discount': discount,
            if (discount > 0 && (discountReason ?? '').isNotEmpty)
              'discountReason': discountReason,
          },
        );
        return Installment.fromJson(_asMap(res.data));
      });
}
