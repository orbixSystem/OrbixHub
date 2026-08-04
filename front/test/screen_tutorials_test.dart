import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';
import 'package:orbixhub_front/features/shell/presentation/screen_tutorials.dart';

/// Tutoriais por tela: o REGISTRO é o contrato (rota → conteúdo). Testar isto por
/// fora da árvore de widgets é o que permite garantir cobertura de TODAS as telas
/// sem montar dez telas.
void main() {
  test('toda tela do menu tem tutorial (nenhuma fica sem ajuda)', () {
    // Deriva as rotas do MENU REAL (`gatedNavItems`) com um usuário que tem tudo
    // — assim, módulo novo no menu sem tutorial quebra este teste, em vez de
    // passar despercebido.
    final tudo = Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      activeTenant: const Tenant(id: 't1', slug: 'demo', name: 'Demo'),
      role: 'owner',
      permissions: const [
        'os.read', 'os.write', 'customer.read', 'customer.write',
        'subject.read', 'inventory.read', 'inventory.write', 'cashier.read',
        'cashier.write', 'cashier.manage', 'sale.read', 'sale.write',
        'report.read', 'users.manage', 'billing.manage', 'settings.manage',
        'finance.read', 'invoice.read', 'tracking.manage',
      ],
      modules: const [
        'os', 'customers', 'inventory', 'cashier', 'sale', 'report', 'invoice',
      ],
    );
    final semTutorial = <String>[];
    for (final item in gatedNavItems(tudo)) {
      // Nenhuma exceção: o Início também entra no registro, para o "?" do chrome
      // global funcionar nele como em qualquer outra tela.
      if (tutorialForRoute(item.route) == null) semTutorial.add(item.route);
    }
    expect(semTutorial, isEmpty,
        reason: 'telas sem tutorial: ${semTutorial.join(', ')}');
  });

  test('rota de detalhe herda o tutorial da área', () {
    // Abrir uma OS específica não deve ficar sem ajuda.
    expect(tutorialForRoute('/m/os/abc-123')?.id, 'tut_os_v1');
    expect(tutorialForRoute('/m/customers/xyz')?.id, 'tut_clientes_v1');
  });

  test('o Início TAMBÉM está no registro (ajuda padronizada)', () {
    // Antes o dashboard era dono do próprio tutorial e do próprio botão. Agora o
    // "?" do chrome global cobre todas as telas, e para isso o Início precisa
    // estar aqui como as outras.
    expect(tutorialForRoute('/')?.id, 'tut_inicio_v1');
  });

  test('rota desconhecida não tem tutorial', () {
    expect(tutorialForRoute('/qualquer/coisa'), isNull);
  });

  group('qualidade do conteúdo', () {
    test('ids são únicos e versionados (mudar id remostra o tutorial)', () {
      final ids = todosOsTutoriais.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id, startsWith('tut_'));
        expect(id, endsWith('_v1'));
      }
    });

    test('todo tutorial tem pelo menos 2 passos com título e texto úteis', () {
      for (final t in todosOsTutoriais) {
        expect(t.steps.length, greaterThanOrEqualTo(2), reason: t.id);
        expect(t.titulo, isNotEmpty, reason: t.id);
        for (final s in t.steps) {
          expect(s.title.trim(), isNotEmpty, reason: t.id);
          // Texto curto demais não explica nada; o limite pega placeholder.
          expect(s.text.trim().length, greaterThan(40), reason: '${t.id}: ${s.title}');
        }
      }
    });

    test('nenhum passo usa targetKey direta (só alvo por NOME)', () {
      // `targetKey` morta DESCARTA o passo; alvo por nome degrada para cartão
      // centralizado. No celular vários elementos do desktop não existem, então
      // o registro central só pode usar nome — senão o tutorial apareceria pela
      // metade justamente no telefone.
      for (final t in todosOsTutoriais) {
        for (final s in t.steps) {
          expect(s.targetKey, isNull, reason: '${t.id}: ${s.title}');
        }
      }
    });

    test('alvo nomeado usa prefixo conhecido (evita nome inventado)', () {
      // Nome errado não quebra nada em runtime (vira cartão centralizado), e é
      // exatamente por isso que precisa de teste: o erro seria silencioso.
      const prefixos = {'shell.', 'caixa.', 'inicio.', 'os.', 'clientes.', 'estoque.'};
      for (final t in todosOsTutoriais) {
        for (final s in t.steps) {
          final nome = s.targetName;
          if (nome == null) continue;
          expect(prefixos.any(nome.startsWith), isTrue,
              reason: '${t.id}: alvo "$nome" fora dos prefixos conhecidos');
        }
      }
    });
  });
}
