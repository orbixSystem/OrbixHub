import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('João Lima'), findsOneWidget);
    // A conversa de Maria tem 3 não-lidos → bolha "3".
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Meu carro já está pronto?'), findsOneWidget);
  });
}
