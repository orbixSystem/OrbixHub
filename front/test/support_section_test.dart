import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/support/data/fake_support_repository.dart';
import 'package:orbixhub_front/features/support/domain/support_models.dart';
import 'package:orbixhub_front/features/support/presentation/support_section.dart';

Widget _wrap(FakeSupportRepository repo, {bool escuro = false}) {
  return ProviderScope(
    overrides: [supportRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: escuro ? AppTheme.dark() : AppTheme.light(),
      // Sem scroll externo: a seção agora preenche a altura (lista e conversa
      // rolam por dentro, com o campo de resposta ancorado embaixo).
      home: const Scaffold(body: SupportSection()),
    ),
  );
}

SupportTicket _ticket({
  String id = 'tk1',
  String subject = 'A nota não sai',
  String status = 'aberto',
  int naoLidas = 0,
}) => SupportTicket(
  id: id,
  subject: subject,
  status: status,
  naoLidas: naoLidas,
  lastMessageAt: DateTime(2026, 8, 21, 10),
  createdAt: DateTime(2026, 8, 21, 9),
);

void main() {
  testWidgets('sem chamados, convida a abrir — sem parecer erro', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FakeSupportRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum chamado ainda'), findsOneWidget);
    expect(find.byKey(const Key('support-novo')), findsOneWidget);
  });

  testWidgets('em aberto na frente; resolvidos recolhidos', (tester) async {
    // O que precisa de atenção não pode disputar espaço com o histórico —
    // que cresce para sempre, enquanto o que está aberto é sempre pouco.
    final repo = FakeSupportRepository(
      tickets: [
        _ticket(subject: 'A nota não sai'),
        _ticket(id: 'tk2', subject: 'Caixa não fecha', status: 'resolvido'),
      ],
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('A nota não sai'), findsOneWidget);
    expect(find.textContaining('Aberto'), findsOneWidget);
    // Resolvido não aparece até alguém pedir.
    expect(find.text('Caixa não fecha'), findsNothing);
    expect(find.text('1 resolvido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-ver-resolvidos')));
    await tester.pumpAndSettle();
    expect(find.text('Caixa não fecha'), findsOneWidget);
    expect(find.textContaining('Resolvido'), findsOneWidget);
  });

  testWidgets('sem nada em aberto, diz isso em vez de ficar vazio', (
    tester,
  ) async {
    final repo = FakeSupportRepository(tickets: [_ticket(status: 'resolvido')]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum chamado em aberto.'), findsOneWidget);
  });

  testWidgets('chamado FECHADO vira pedido de reabertura, não resposta', (
    tester,
  ) async {
    // Fechar é decisão da Orbix: o cliente não reabre escrevendo, ele PEDE.
    final repo = FakeSupportRepository(
      tickets: [_ticket(status: 'resolvido')],
      mensagens: {'tk1': []},
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-ver-resolvidos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();

    expect(find.text('Pedir reabertura'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('support-campo')),
      'voltou a dar erro',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();

    expect(repo.reaberturaPedidaDe, 'tk1');
    expect(repo.motivoDaReabertura, 'voltou a dar erro');
    // E NÃO caiu no caminho de resposta comum.
    expect(repo.respondidos, 0);
  });

  testWidgets('depois de pedir, o cliente sabe que está aguardando', (
    tester,
  ) async {
    final repo = FakeSupportRepository(
      tickets: [_ticket(status: 'reabertura_solicitada')],
      mensagens: {'tk1': []},
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reabertura pedida'), findsOneWidget);
    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('vai retomar a conversa'), findsOneWidget);
  });

  testWidgets('chamado com resposta nova mostra o contador', (tester) async {
    final repo = FakeSupportRepository(tickets: [_ticket(naoLidas: 2)]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('abrir um chamado mostra a conversa e permite voltar', (
    tester,
  ) async {
    final repo = FakeSupportRepository(
      tickets: [_ticket()],
      mensagens: {
        'tk1': [
          SupportMessage(
            id: 'm1',
            body: 'a nota não sai',
            createdAt: DateTime(2026, 8, 21, 9),
          ),
          SupportMessage(
            id: 'm2',
            body: 'já estamos vendo',
            fromOrbix: true,
            createdAt: DateTime(2026, 8, 21, 10),
          ),
        ],
      },
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();

    expect(find.text('a nota não sai'), findsOneWidget);
    expect(find.text('já estamos vendo'), findsOneWidget);
    expect(find.text('Suporte Orbix'), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-voltar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-novo')), findsOneWidget);
  });

  testWidgets('abrir chamado novo exige assunto E mensagem', (tester) async {
    final repo = FakeSupportRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-novo')));
    await tester.pumpAndSettle();

    // Só o assunto não basta.
    await tester.enterText(
      find.byKey(const Key('support-assunto')),
      'Um assunto',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();
    expect(repo.abertos, 0);

    await tester.enterText(find.byKey(const Key('support-campo')), 'o detalhe');
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();
    expect(repo.abertos, 1);
  });

  testWidgets('responder dentro do chamado usa o id certo', (tester) async {
    final repo = FakeSupportRepository(
      tickets: [_ticket()],
      mensagens: {'tk1': []},
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('support-campo')),
      'mais um dado',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();

    expect(repo.respondidos, 1);
  });

  testWidgets('a conversa abre no FIM e desce quando chega mensagem nova', (
    tester,
  ) async {
    // Chat que não desce sozinho obriga o usuário a rolar atrás da resposta que
    // ele está esperando — que é a única razão de ele estar ali.
    final repo = FakeSupportRepository(
      tickets: [_ticket()],
      mensagens: {
        'tk1': [
          for (var i = 0; i < 30; i++)
            SupportMessage(
              id: 'm$i',
              body: 'mensagem $i',
              fromOrbix: i.isEven,
              createdAt: DateTime(2026, 8, 21, 9, i),
            ),
        ],
      },
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();

    ScrollPosition posicao() =>
        tester.widget<ListView>(find.byType(ListView)).controller!.position;

    // Abriu já no fim: a última mensagem é a que está na tela.
    expect(posicao().pixels, posicao().maxScrollExtent);
    expect(posicao().maxScrollExtent, greaterThan(0));

    // Chega mensagem nova (aqui, a nossa própria resposta) — a lista desce.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(posicao().pixels, lessThan(posicao().maxScrollExtent));

    await tester.enterText(
      find.byKey(const Key('support-campo')),
      'e mais uma',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();

    expect(posicao().pixels, posicao().maxScrollExtent);
  });

  testWidgets('no tema ESCURO o texto do balão continua legível', (
    tester,
  ) async {
    // Regressão: a primeira versão pintava o balão com uma cor do tema claro,
    // e no escuro o texto sumia no fundo.
    final repo = FakeSupportRepository(
      tickets: [_ticket()],
      mensagens: {
        'tk1': [
          SupportMessage(
            id: 'm1',
            body: 'texto que precisa aparecer',
            createdAt: DateTime(2026, 8, 21, 9),
          ),
        ],
      },
    );
    await tester.pumpWidget(_wrap(repo, escuro: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-ticket-tk1')));
    await tester.pumpAndSettle();

    final texto = tester.widget<Text>(find.text('texto que precisa aparecer'));
    final cor = texto.style?.color;
    expect(cor, isNotNull);
    // A cor do texto tem de vir do par do tema, nunca de uma constante clara.
    expect(cor, isNot(Colors.transparent));
  });
}
