import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_filtro.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_query.dart';

/// A MESMA tabela é lida pelo jest (`receivables.filtro.spec.ts`). Um lado
/// mudar a regra sem o outro deixa os dois vermelhos — é o que impede o
/// offline (Dart) de discordar do servidor (TS) sobre quem está vencido.
const _caminhoCasos =
    '../back/src/modules/receivables/receivables-filtro.casos.json';

/// O caso carrega o `id` para o teste comparar listas por nome do caso, não
/// por objeto — igual ao `{ ...classificar(d), id }` do lado TS.
class _Caso extends DevedorClassificado {
  _Caso(this.id, DevedorClassificado c)
      : super(
          customerId: c.customerId,
          customerName: c.customerName,
          totalDue: c.totalDue,
          titleCount: c.titleCount,
          oldestAt: c.oldestAt,
          titulos: c.titulos,
          nextDueAt: c.nextDueAt,
          overdue: c.overdue,
        );

  final String id;
}

VencimentoFiltro _vencimento(String wire) =>
    VencimentoFiltro.values.firstWhere((v) => v.wire == wire);
OrigemFiltro _origem(String wire) =>
    OrigemFiltro.values.firstWhere((v) => v.wire == wire);
OrdemDevedores _ordem(String wire) =>
    OrdemDevedores.values.firstWhere((v) => v.wire == wire);

List<String> _ids(List<_Caso> l) => l.map((c) => c.id).toList();

void main() {
  final casos = jsonDecode(File(_caminhoCasos).readAsStringSync())
      as Map<String, dynamic>;
  final hoje = DateTime.parse(casos['hoje'] as String);

  final classificados = (casos['devedores'] as List).map((raw) {
    final d = raw as Map<String, dynamic>;
    final devedor = DevedorParaFiltro(
      customerId: d['customerId'] as String?,
      customerName: d['customerName'] as String,
      totalDue: d['totalDue'] as num,
      titleCount: d['titleCount'] as int,
      oldestAt: d['oldestAt'] as String?,
      titulos: (d['titulos'] as List)
          .map((t) => t as Map<String, dynamic>)
          .map(
            (t) => TituloParaFiltro(
              origin: t['origin'] as String,
              createdAt: t['createdAt'] as String?,
              balance: t['balance'] as num,
              proximaParcelaEm: t['proximaParcelaEm'] as String?,
            ),
          )
          .toList(),
    );
    return _Caso(d['id'] as String, classificar(devedor, hoje));
  }).toList();

  group('receivables_filtro (tabela compartilhada com o backend)', () {
    final classificacao = casos['classificacao'] as Map<String, dynamic>;
    for (final entrada in classificacao.entries) {
      test('classifica ${entrada.key}', () {
        final esperado = entrada.value as Map<String, dynamic>;
        final d = classificados.firstWhere((c) => c.id == entrada.key);
        expect(d.nextDueAt, esperado['nextDueAt']);
        expect(d.overdue, esperado['overdue']);
      });
    }

    for (final raw in casos['filtros'] as List) {
      final c = raw as Map<String, dynamic>;
      final f = c['f'] as Map<String, dynamic>;
      test('filtro ${c['nome']}', () {
        final r = filtrarDevedores(
          classificados,
          q: f['q'] as String?,
          vencimento: _vencimento(f['vencimento'] as String),
          origem: _origem(f['origem'] as String),
          hoje: hoje,
        );
        expect(
          _ids(r)..sort(),
          (c['esperado'] as List).cast<String>().toList()..sort(),
        );
      });
    }

    for (final raw in casos['ordenacoes'] as List) {
      final c = raw as Map<String, dynamic>;
      test('ordem ${c['ordem']}', () {
        final r = ordenarDevedores(classificados, _ordem(c['ordem'] as String));
        expect(_ids(r), (c['esperado'] as List).cast<String>());
      });
    }

    test('paginação devolve a página pedida e o total geral', () {
      final p = casos['paginacao'] as Map<String, dynamic>;
      final ordenados =
          ordenarDevedores(classificados, _ordem(p['ordem'] as String));
      final r = paginar(ordenados, p['page'] as int, p['pageSize'] as int);
      expect(_ids(r.items), (p['esperadoIds'] as List).cast<String>());
      expect(r.total, p['total']);
    });

    test('página além do fim devolve vazio, mas mantém o total', () {
      final r = paginar(classificados, 99, 2);
      expect(r.items, isEmpty);
      expect(r.total, classificados.length);
    });
  });

  group('semAcento', () {
    test('remove acento e baixa caixa como o NFD do servidor', () {
      expect(semAcento('Célia'), 'celia');
      expect(semAcento('DÁRIO Ção'), 'dario cao');
    });
  });
}
