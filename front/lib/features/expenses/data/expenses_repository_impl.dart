import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/expense_models.dart';
import '../domain/expenses_repository.dart';

/// [ExpensesRepository] real, sobre dio.
///
/// Os corpos são montados campo a campo, e não via `draft.toJson()`: o
/// `ValidationPipe` do backend usa whitelist, e um campo a mais (por exemplo
/// `limparCategoria` num POST, onde só o PATCH o aceita) viraria 400. Montar
/// explícito também deixa visível o que cada rota realmente recebe.
class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) =>
      (data as Map).cast<String, dynamic>();

  /// Remove as chaves nulas: ausência significa "não mexe" nos PATCHs do
  /// backend, então mandar `null` explícito apagaria o campo.
  Map<String, dynamic> _semNulos(Map<String, dynamic> m) =>
      Map.fromEntries(m.entries.where((e) => e.value != null));

  @override
  Future<ExpensesMonth> listarMes({required int ano, required int mes}) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/expenses',
          queryParameters: {'ano': ano, 'mes': mes},
        );
        return ExpensesMonth.fromJson(_asMap(res.data));
      });

  @override
  Future<ExpenseCategory> criarCategoria({
    required String name,
    String? icon,
    String? color,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/expenses/categories',
          data: _semNulos({'name': name, 'icon': icon, 'color': color}),
        );
        return ExpenseCategory.fromJson(_asMap(res.data));
      });

  @override
  Future<List<ExpenseCategory>> categorias() => _guard(() async {
        final res = await _dio.get<Object?>('/expenses/categories');
        final lista = (res.data as List).cast<Object?>();
        return lista.map((e) => ExpenseCategory.fromJson(_asMap(e))).toList();
      });

  @override
  Future<Expense> criar(ExpenseDraft draft) => _guard(() async {
        final r = draft.recorrencia;
        final res = await _dio.post<Object?>(
          '/expenses',
          data: _semNulos({
            'description': draft.description,
            'dueDate': draft.dueDate,
            'amount': draft.amount,
            'categoryId': draft.categoryId,
            'notes': draft.notes,
            'supplierName': draft.supplierName,
            'supplierDoc': draft.supplierDoc,
            // Parcelamento: `amount` acima é o TOTAL, e o servidor rateia.
            'parcelas': draft.parcelas,
            // Ids só no caminho offline (o decorator os gera); online o banco
            // resolve.
            'installmentIds': draft.installmentIds,
            'installmentGroupId': draft.installmentGroupId,
            if (r != null)
              'recorrencia': _semNulos({
                'frequency': r.frequency,
                'dayOfMonth': r.dayOfMonth,
                'monthOfYear': r.monthOfYear,
                'endsOn': r.endsOn,
              }),
          }),
        );
        return Expense.fromJson(_asMap(res.data));
      });

  @override
  Future<ExpenseDetail> detalhe(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/expenses/$id');
        return ExpenseDetail.fromJson(_asMap(res.data));
      });

  @override
  Future<ExpenseSupplierLookup> consultarCnpj(String cnpj) => _guard(() async {
        final res = await _dio.get<Object?>('/expenses/cnpj/$cnpj');
        return ExpenseSupplierLookup.fromJson(_asMap(res.data));
      });

  @override
  Future<Expense> editar(String id, ExpenseDraft draft) => _guard(() async {
        final body = _semNulos({
          'description': draft.description,
          'dueDate': draft.dueDate,
          'amount': draft.amount,
          'categoryId': draft.categoryId,
          'notes': draft.notes,
        });
        body.addAll(_semNulos({
          'supplierName': draft.supplierName,
          'supplierDoc': draft.supplierDoc,
        }));
        // Só viaja quando é verdade: `limparCategoria: false` é ruído, e o
        // backend já trata ausência como "não mexe".
        if (draft.limparCategoria) body['limparCategoria'] = true;
        if (draft.limparFornecedor) body['limparFornecedor'] = true;
        final res = await _dio.patch<Object?>('/expenses/$id', data: body);
        return Expense.fromJson(_asMap(res.data));
      });

  @override
  Future<Expense> marcarPaga(
    String id, {
    num? valor,
    String? forma,
    DateTime? quando,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/expenses/$id/pay',
          data: _semNulos({
            'amount': valor,
            'method': forma,
            'paidAt': quando?.toIso8601String(),
          }),
        );
        return Expense.fromJson(_asMap(res.data));
      });

  @override
  Future<Expense> desmarcarPaga(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/expenses/$id/unpay');
        return Expense.fromJson(_asMap(res.data));
      });

  @override
  Future<void> cancelar(String id) =>
      _guard(() => _dio.delete<Object?>('/expenses/$id'));
}
