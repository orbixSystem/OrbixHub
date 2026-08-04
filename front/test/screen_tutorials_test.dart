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

  test('sub-tela tem tutorial próprio (não herda mais o da lista)', () {
    // Este teste dizia o contrário: que o detalhe HERDAVA o tutorial da área.
    // Era o comportamento antigo (casamento por prefixo) e virou o alvo da
    // mudança — detalhe do cliente e detalhe do veículo pedem decisões
    // diferentes da lista, então cada um tem o seu.
    expect(tutorialForRoute('/m/os/abc-123')?.titulo, 'Ordem de serviço');
    expect(tutorialForRoute('/m/customers/xyz')?.titulo, 'Ficha do cliente');
    expect(tutorialForRoute('/m/customers/xyz/veiculo/v1')?.titulo, 'Veículo');
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
        // Versionado: subir de `_v1` para `_v2` é o jeito de REMOSTRAR um
        // tutorial que mudou de conteúdo a quem já o tinha visto.
        expect(id, matches(RegExp(r'_v\d+$')), reason: id);
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
      const prefixos = {
        'shell.',
        'caixa.',
        'inicio.',
        'os.',
        'clientes.',
        'estoque.',
        'relatorios.',
        // sub-telas
        'cliente.',
        'veiculo.',
        'equipe.',
        'planos.',
        'agenda.',
        'horarios.',
        'mensagens.',
        'fiscal.',
        'config.',
      };
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
  group('cobertura contra as rotas REAIS do router', () {
    /// Rotas do shell, espelhando `app_router.dart`. Esta lista existe porque o
    /// teste anterior derivava do MENU — e "Planos" está escondido do menu, então
    /// o tutorial dele (registrado com o caminho errado, `/planos` em vez de
    /// `/billing`) nunca disparava e nada acusava.
    const rotasDoShell = <String>[
      '/',
      '/billing',
      '/equipe',
      '/configuracoes',
      '/agenda',
      '/agenda/horarios',
      '/mensagens',
      '/mensagens/abc',
      '/m/customers',
      '/m/customers/abc',
      '/m/customers/abc/veiculo/xyz',
      '/m/inventory',
      '/m/os',
      '/m/os/templates',
      '/m/os/abc',
      '/m/invoice',
      '/m/invoice/config',
      '/m/invoice/abc',
      '/m/cashier',
      '/m/report',
    ];

    test('toda rota do shell tem tutorial', () {
      final sem = rotasDoShell.where((r) => tutorialForRoute(r) == null).toList();
      expect(sem, isEmpty, reason: 'rotas sem tutorial: ${sem.join(', ')}');
    });

    test('sub-tela tem tutorial PRÓPRIO, não o da lista', () {
      // O que o usuário pediu: detalhe explica o detalhe. Por prefixo puro os
      // dois cairiam no mesmo tutorial.
      expect(tutorialForRoute('/m/customers')!.id,
          isNot(tutorialForRoute('/m/customers/abc')!.id));
      expect(tutorialForRoute('/m/customers/abc')!.id,
          isNot(tutorialForRoute('/m/customers/abc/veiculo/xyz')!.id));
      expect(tutorialForRoute('/m/os')!.id,
          isNot(tutorialForRoute('/m/os/abc')!.id));
      expect(tutorialForRoute('/m/os/abc')!.id,
          isNot(tutorialForRoute('/m/os/templates')!.id));
      expect(tutorialForRoute('/m/invoice/abc')!.id,
          isNot(tutorialForRoute('/m/invoice/config')!.id));
    });

    test('rota literal vence o padrão :id (templates não é uma OS)', () {
      expect(tutorialForRoute('/m/os/templates')!.titulo, 'Modelos de OS');
      expect(tutorialForRoute('/m/invoice/config')!.titulo,
          'Configuração fiscal');
      expect(tutorialForRoute('/agenda/horarios')!.titulo, 'Horários');
    });

    test('sub-rota desconhecida cai no ancestral, não fica sem ajuda', () {
      expect(tutorialForRoute('/m/os/abc/algo-novo')?.id,
          tutorialForRoute('/m/os/abc')!.id);
    });

    test('rota fora do shell não tem tutorial', () {
      for (final r in ['/login', '/t/token123', '/splash']) {
        expect(tutorialForRoute(r), isNull, reason: r);
      }
    });
  });

  group('botão de ajuda: rota sem tutorial não mostra o de outra tela', () {
    test('rota fora do mapa devolve null (o botão some)', () {
      // O bug: o botão era `const` e não rebuildava, então guardava o tutorial da
      // primeira rota — numa tela sem tutorial ele oferecia o anterior. A parte
      // testável aqui é a resolução: fora do mapa é `null`, e o widget trata
      // `null` escondendo-se.
      for (final r in ['/design', '/dev/ui', '/nao-existe']) {
        expect(tutorialForRoute(r), isNull, reason: r);
      }
    });

    test('Configurações TEM tutorial (a tela existe no mapa)', () {
      expect(tutorialForRoute('/configuracoes')?.titulo, 'Configurações');
    });

    test('trocar de rota troca o tutorial', () {
      final a = tutorialForRoute('/m/cashier')!.id;
      final b = tutorialForRoute('/configuracoes')!.id;
      final c = tutorialForRoute('/m/customers/abc/veiculo/x')!.id;
      expect({a, b, c}.length, 3);
    });
  });

}
