import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/widgets/read_ticks.dart';
import 'package:orbixhub_front/features/messages/data/fake_messages_repository.dart';
import 'package:orbixhub_front/features/messages/domain/messages_models.dart';
import 'package:orbixhub_front/features/messages/presentation/messages_inbox_screen.dart';
import 'package:orbixhub_front/features/messages/presentation/messages_providers.dart';

void main() {
  testWidgets('inbox lista conversas e mostra bolha de não-lidos',
      (tester) async {
    final fake = FakeMessagesRepository(
      conversations: const [
        Conversation(
          id: 'c1',
          title: 'Maria Souza',
          refLabel: 'OS-0001',
          staffUnread: 3,
          lastMessage: 'Meu carro já está pronto?',
        ),
        Conversation(id: 'c2', title: 'João Lima', lastMessage: 'Obrigado!'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagesRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scaffold(body: MessagesInboxScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
    // Rótulo da OS aparece ao lado do nome (distingue clientes homônimos).
    expect(find.text('· OS-0001'), findsOneWidget);
    expect(find.text('João Lima'), findsOneWidget);
    // A conversa de Maria tem 3 não-lidos → bolha "3".
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Meu carro já está pronto?'), findsOneWidget);
  });

  testWidgets('prévia do staff mostra tracinhos; lida = azul, não lida = cinza',
      (tester) async {
    final fake = FakeMessagesRepository(
      conversations: const [
        // Última mensagem do staff já vista pelo cliente → tracinhos azuis.
        Conversation(
          id: 'lida',
          title: 'Cliente Lida',
          lastMessage: 'Pronto, pode retirar!',
          lastMessageSender: 'staff',
          lastMessageRead: true,
          lastMessageAt: '2026-06-18T09:05:00Z',
        ),
        // Última mensagem do staff ainda não vista → tracinhos cinza.
        Conversation(
          id: 'naolida',
          title: 'Cliente NaoLida',
          lastMessage: 'Te aviso quando ficar pronto.',
          lastMessageSender: 'staff',
          lastMessageRead: false,
        ),
        // Última mensagem do cliente → sem tracinhos (mensagem recebida).
        Conversation(
          id: 'cliente',
          title: 'Cliente Falou',
          lastMessage: 'Bom dia!',
          lastMessageSender: 'customer',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [messagesRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: MessagesInboxScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Duas conversas do staff → dois conjuntos de tracinhos; a do cliente não.
    final ticks = tester.widgetList<ReadTicks>(find.byType(ReadTicks)).toList();
    expect(ticks.length, 2);
    expect(ticks.where((t) => t.read).length, 1); // só a "lida" é azul
  });
}
