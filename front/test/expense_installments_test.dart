import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_installments.dart';

/// Rateio e vencimentos de compra parcelada, no cliente.
///
/// O servidor é a autoridade, mas o cliente faz a MESMA conta para mostrar
/// "6x de R$ 194,44" enquanto a pessoa digita e para criar as parcelas sem rede.
/// Se as duas contas divergirem, o valor na tela não é o valor gravado.
void main() {
  /// Soma em centavos: comparar reais em double é o próprio bug sob teste.
  int somaCentavos(List<num> vs) =>
      vs.fold(0, (a, v) => a + (v * 100).round());

  group('ratearParcelas', () {
    test('resto vai na PRIMEIRA parcela e a soma fecha', () {
      expect(ratearParcelas(100, 3), [33.34, 33.33, 33.33]);
      expect(somaCentavos(ratearParcelas(100, 3)), 10000);
    });

    test('divisão exata não inventa resto', () {
      expect(ratearParcelas(900, 3), [300, 300, 300]);
    });

    test('fecha o total para QUALQUER n até o teto', () {
      // A única garantia que importa: nenhum centavo perdido ou criado. Se
      // falhar, a dívida cadastrada não é a dívida combinada.
      for (final total in [0.03, 1, 9.99, 100, 1234.56, 99999.99]) {
        for (var n = 2; n <= maxParcelas; n++) {
          final vs = ratearParcelas(total, n);
          expect(vs.length, n);
          expect(somaCentavos(vs), (total * 100).round(),
              reason: 'total=$total n=$n');
        }
      }
    });

    test('nenhuma parcela negativa mesmo com total menor que n', () {
      final vs = ratearParcelas(0.02, 3);
      expect(vs.every((v) => v >= 0), isTrue);
      expect(somaCentavos(vs), 2);
    });

    test('n inválido devolve vazio em vez de estourar', () {
      // A tela chama isto a cada tecla digitada; jogar exceção no meio da
      // digitação transformaria um campo em branco em tela de erro.
      expect(ratearParcelas(100, 0), isEmpty);
    });
  });

  group('datasDasParcelas', () {
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);

    test('primeira é a informada; as outras de mês em mês', () {
      final ds = datasDasParcelas(DateTime.utc(2026, 8, 10), 3);
      expect(ds.map(iso), ['2026-08-10', '2026-09-10', '2026-10-10']);
    });

    test('mês curto ENCURTA o dia, não transborda', () {
      // 31/01 em 3x: fevereiro não tem 31. Transbordar para 03/03 jogaria a
      // parcela de fevereiro no mês de março.
      final ds = datasDasParcelas(DateTime.utc(2026, 1, 31), 3);
      expect(ds.map(iso), ['2026-01-31', '2026-02-28', '2026-03-31']);
    });

    test('ano bissexto dá 29 de fevereiro', () {
      final ds = datasDasParcelas(DateTime.utc(2028, 1, 31), 2);
      expect(ds.map(iso), ['2028-01-31', '2028-02-29']);
    });

    test('atravessa a virada do ano', () {
      final ds = datasDasParcelas(DateTime.utc(2026, 11, 15), 4);
      expect(ds.map(iso),
          ['2026-11-15', '2026-12-15', '2027-01-15', '2027-02-15']);
    });

    test('devolve datas em UTC (due_date é dia civil)', () {
      // Data local aqui deslocaria o dia em fuso a oeste — o mesmo erro que já
      // jogou o dia 1º para o mês anterior em `contasDoMes`.
      final ds = datasDasParcelas(DateTime.utc(2026, 8, 1), 2);
      expect(ds.every((d) => d.isUtc), isTrue);
      expect(iso(ds.first), '2026-08-01');
    });

    test('12x dá a volta no calendário sem perder o dia', () {
      final ds = datasDasParcelas(DateTime.utc(2026, 8, 5), 12);
      expect(ds.length, 12);
      expect(iso(ds.last), '2027-07-05');
    });
  });
}
