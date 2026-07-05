import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sale_repository.dart';

/// Declarado aqui (lança por padrão) e ganha a impl real (dio) em `di.dart`,
/// espelhando os demais repos. Testes sobrescrevem com o fake. A venda avulsa é
/// uma AÇÃO no Caixa (não tem tela/list própria) — por isso só o repo aqui; o
/// histórico de vendas vive na lente "Vendas" do Relatório.
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  throw UnimplementedError('saleRepositoryProvider deve ser sobrescrito em di.dart');
});
