import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_ordering.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_status.dart';

/// Prioridade e busca na lista de contas a pagar.
///
/// A regra que estes testes fixam: a lista é uma FILA DE TAREFAS, não um extrato
/// cronológico. Vencido vem antes de vence-hoje (é o que já gera multa), e pago
/// sai do caminho mesmo tendo vencido antes de todo o resto.
void main() {
  final hoje = DateTime(2026, 8, 15);

  Expense conta(
    String desc,
    String venc, {
    String? pagoEm,
    String? categoria,
  }) =>
      Expense(
        id: desc,
        description: desc,
        dueDate: '${venc}T00:00:00.000Z',
        paidAt: pagoEm == null ? null : '${pagoEm}T12:00:00.000Z',
        categoryId: categoria,
      );

  List<String> nomes(List<Expense> l) => l.map((e) => e.description).toList();

  group('ordenarPorUrgencia', () {
    test('vencido vem antes de vence-hoje, e pago vai para o fim', () {
      final lista = [
        conta('adiante', '2026-08-28'),
        conta('paga-antiga', '2026-08-01', pagoEm: '2026-08-01'),
        conta('vence-hoje', '2026-08-15'),
        conta('vencida', '2026-08-10'),
        conta('em-breve', '2026-08-17'),
      ];
      expect(
        nomes(ordenarPorUrgencia(lista, hoje: hoje)),
        ['vencida', 'vence-hoje', 'em-breve', 'adiante', 'paga-antiga'],
      );
    });

    test('entre vencidas, a mais antiga primeiro (atrasa há mais tempo)', () {
      final lista = [
        conta('atrasa-3-dias', '2026-08-12'),
        conta('atrasa-14-dias', '2026-08-01'),
        conta('atrasa-1-dia', '2026-08-14'),
      ];
      expect(
        nomes(ordenarPorUrgencia(lista, hoje: hoje)),
        ['atrasa-14-dias', 'atrasa-3-dias', 'atrasa-1-dia'],
      );
    });

    test('ordem é ESTÁVEL: mesmo dia desempata por descrição', () {
      // Sem desempate determinístico a lista "pisca" entre carregamentos e o
      // usuário perde o dedo na linha que ia tocar.
      final a = [conta('Zebra', '2026-08-20'), conta('Alfa', '2026-08-20')];
      final b = [conta('Alfa', '2026-08-20'), conta('Zebra', '2026-08-20')];
      expect(nomes(ordenarPorUrgencia(a, hoje: hoje)), ['Alfa', 'Zebra']);
      expect(
        nomes(ordenarPorUrgencia(b, hoje: hoje)),
        nomes(ordenarPorUrgencia(a, hoje: hoje)),
      );
    });

    test('não muta a lista recebida', () {
      final original = [conta('b', '2026-08-20'), conta('a', '2026-08-10')];
      final copia = [...original];
      ordenarPorUrgencia(original, hoje: hoje);
      expect(nomes(original), nomes(copia));
    });

    test('conta paga em atraso NÃO é tratada como vencida', () {
      // Mostrá-la no topo em vermelho faria a cliente pagar de novo.
      final lista = [
        conta('paga-atrasada', '2026-08-02', pagoEm: '2026-08-14'),
        conta('aberta-hoje', '2026-08-15'),
      ];
      expect(
        nomes(ordenarPorUrgencia(lista, hoje: hoje)),
        ['aberta-hoje', 'paga-atrasada'],
      );
    });

    test('lista vazia não estoura', () {
      expect(ordenarPorUrgencia([], hoje: hoje), isEmpty);
    });
  });

  group('filtrarPorTexto', () {
    final lista = [
      conta('CPFL 08/2026', '2026-08-10', categoria: 'cat-energia'),
      conta('Aluguel galpão', '2026-08-05', categoria: 'cat-aluguel'),
      conta('Contador', '2026-08-20'),
    ];
    String nomeCat(String id) =>
        {'cat-energia': 'Energia', 'cat-aluguel': 'Aluguel'}[id] ?? '';

    test('busca vazia devolve tudo', () {
      expect(filtrarPorTexto(lista, '   ').length, 3);
    });

    test('acha pela descrição, sem ligar para caixa', () {
      expect(nomes(filtrarPorTexto(lista, 'cpfl')), ['CPFL 08/2026']);
      expect(nomes(filtrarPorTexto(lista, 'CONTADOR')), ['Contador']);
    });

    test('acha pelo NOME DA CATEGORIA — é como a pessoa pensa a conta', () {
      // A descrição diz "CPFL 08/2026", mas quem procura digita "energia".
      expect(
        nomes(filtrarPorTexto(lista, 'energia', nomeDaCategoria: nomeCat)),
        ['CPFL 08/2026'],
      );
    });

    test('sem resolvedor de categoria, busca só na descrição', () {
      expect(filtrarPorTexto(lista, 'energia'), isEmpty);
    });

    test('nada encontrado devolve vazio (não a lista toda)', () {
      expect(filtrarPorTexto(lista, 'zzz', nomeDaCategoria: nomeCat), isEmpty);
    });
  });

  group('contasQuePedemAtencao', () {
    test('conta vencidas + vencendo hoje, ignorando o resto', () {
      final lista = [
        conta('vencida', '2026-08-10'),
        conta('hoje', '2026-08-15'),
        conta('em-breve', '2026-08-17'),
        conta('adiante', '2026-08-30'),
        conta('paga', '2026-08-01', pagoEm: '2026-08-01'),
      ];
      expect(contasQuePedemAtencao(lista, hoje: hoje), 2);
    });

    test('mês tranquilo devolve zero', () {
      expect(
        contasQuePedemAtencao([conta('adiante', '2026-08-30')], hoje: hoje),
        0,
      );
    });
  });

  group('coerência com a derivação de status', () {
    test('vencido é o único estado com peso máximo de urgência', () {
      // Guarda contra alguém mexer na janela de "em breve" e inverter a fila.
      final s = statusDaDespesa(
        dueDate: DateTime(2026, 8, 10),
        hoje: hoje,
      );
      expect(s, ExpenseStatus.vencido);
    });
  });
}
