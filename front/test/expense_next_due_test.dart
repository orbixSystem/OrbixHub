import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_next_due.dart';

/// "Quando vence de novo?" — a pergunta que o dono fez ao ver a baixa.
///
/// Dar baixa numa conta fixa parece encerrar o assunto, mas o aluguel volta mês
/// que vem. Estas contas de calendário erram em fevereiro e na virada de ano, e
/// mostrar data errada sobre dinheiro é pior que não mostrar.
void main() {
  ExpenseRecurrence regra({
    String freq = 'monthly',
    int dia = 10,
    int? mes,
    String? fim,
    String status = 'active',
  }) =>
      ExpenseRecurrence(
        id: 'r1',
        description: 'Aluguel',
        frequency: freq,
        dayOfMonth: dia,
        monthOfYear: mes,
        endsOn: fim,
        status: status,
      );

  String iso(DateTime? d) => d == null ? 'null' : d.toIso8601String().substring(0, 10);

  group('proximaOcorrencia — mensal', () {
    test('depois do vencimento deste mês, cai no mês seguinte', () {
      final p = proximaOcorrencia(regra(dia: 10),
          depoisDe: DateTime.utc(2026, 8, 10));
      expect(iso(p), '2026-09-10');
    });

    test('paga antes do dia: a próxima ainda é DESTE mês', () {
      // Conta do dia 20 quitada no dia 5 — dizer "20/09" esconderia que ela
      // ainda vence este mês.
      final p = proximaOcorrencia(regra(dia: 20),
          depoisDe: DateTime.utc(2026, 8, 5));
      expect(iso(p), '2026-08-20');
    });

    test('dia 31 encurta em fevereiro', () {
      final p = proximaOcorrencia(regra(dia: 31),
          depoisDe: DateTime.utc(2026, 1, 31));
      expect(iso(p), '2026-02-28');
    });

    test('dia 31 em fevereiro bissexto dá 29', () {
      final p = proximaOcorrencia(regra(dia: 31),
          depoisDe: DateTime.utc(2028, 1, 31));
      expect(iso(p), '2028-02-29');
    });

    test('dezembro vira janeiro do ANO seguinte', () {
      final p = proximaOcorrencia(regra(dia: 10),
          depoisDe: DateTime.utc(2026, 12, 10));
      expect(iso(p), '2027-01-10');
    });
  });

  group('proximaOcorrencia — anual', () {
    test('mesma data do ano seguinte quando a deste ano já passou', () {
      final p = proximaOcorrencia(regra(freq: 'yearly', dia: 15, mes: 3),
          depoisDe: DateTime.utc(2026, 3, 15));
      expect(iso(p), '2027-03-15');
    });

    test('ainda neste ano quando o mês não chegou', () {
      final p = proximaOcorrencia(regra(freq: 'yearly', dia: 15, mes: 11),
          depoisDe: DateTime.utc(2026, 3, 15));
      expect(iso(p), '2026-11-15');
    });

    test('anual SEM mês não inventa data', () {
      // O backend barra na criação; aqui preferimos não mostrar nada a mostrar
      // um mês chutado.
      final p = proximaOcorrencia(regra(freq: 'yearly', dia: 15),
          depoisDe: DateTime.utc(2026, 3, 15));
      expect(p, isNull);
    });
  });

  group('proximaOcorrencia — fim da regra', () {
    test('depois de endsOn não há próxima', () {
      final p = proximaOcorrencia(
        regra(dia: 10, fim: '2026-08-31'),
        depoisDe: DateTime.utc(2026, 8, 10),
      );
      expect(p, isNull);
    });

    test('dentro de endsOn continua', () {
      final p = proximaOcorrencia(
        regra(dia: 10, fim: '2026-12-31'),
        depoisDe: DateTime.utc(2026, 8, 10),
      );
      expect(iso(p), '2026-09-10');
    });

    test('regra desativada não tem próxima', () {
      final p = proximaOcorrencia(
        regra(status: 'disabled'),
        depoisDe: DateTime.utc(2026, 8, 10),
      );
      expect(p, isNull);
    });
  });

  group('proximaCobranca', () {
    Expense conta({
      String venc = '2026-08-10',
      String? regraId,
      int? parcela,
      int? total,
      String? grupo,
    }) =>
        Expense(
          id: 'e-$parcela',
          description: 'x',
          dueDate: '${venc}T00:00:00.000Z',
          recurrenceId: regraId,
          installmentNo: parcela,
          installmentTotal: total,
          installmentGroupId: grupo,
        );

    test('avulsa não tem próxima cobrança', () {
      expect(
        proximaCobranca(conta(), regras: const [], irmas: const []),
        isNull,
      );
    });

    test('fixa calcula pela REGRA (a próxima é linha de outro mês)', () {
      final p = proximaCobranca(
        conta(regraId: 'r1'),
        regras: [regra(dia: 10)],
        irmas: const [],
      );
      expect(iso(p), '2026-09-10');
    });

    test('fixa sem a regra em mãos não chuta data', () {
      final p = proximaCobranca(
        conta(regraId: 'r-ausente'),
        regras: [regra()],
        irmas: const [],
      );
      expect(p, isNull);
    });

    test('parcelada usa a IRMÃ seguinte, que é fato gravado', () {
      // Calcular daria a data errada se alguém tivesse corrigido o vencimento de
      // uma parcela — e corrigir uma parcela é caso comum.
      final irmas = [
        conta(venc: '2026-08-10', parcela: 1, total: 3, grupo: 'g'),
        conta(venc: '2026-09-25', parcela: 2, total: 3, grupo: 'g'),
        conta(venc: '2026-10-10', parcela: 3, total: 3, grupo: 'g'),
      ];
      final p = proximaCobranca(irmas[0], regras: const [], irmas: irmas);
      expect(iso(p), '2026-09-25');
    });

    test('última parcela não tem próxima', () {
      final irmas = [
        conta(venc: '2026-08-10', parcela: 1, total: 2, grupo: 'g'),
        conta(venc: '2026-09-10', parcela: 2, total: 2, grupo: 'g'),
      ];
      final p = proximaCobranca(irmas[1], regras: const [], irmas: irmas);
      expect(p, isNull);
    });

    test('irmãs fora de ordem não confundem o resultado', () {
      final desordenadas = [
        conta(venc: '2026-10-10', parcela: 3, total: 3, grupo: 'g'),
        conta(venc: '2026-08-10', parcela: 1, total: 3, grupo: 'g'),
        conta(venc: '2026-09-10', parcela: 2, total: 3, grupo: 'g'),
      ];
      final p = proximaCobranca(
        desordenadas[1],
        regras: const [],
        irmas: desordenadas,
      );
      expect(iso(p), '2026-09-10');
    });
  });
}
