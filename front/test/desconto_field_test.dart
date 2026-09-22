import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/presentation/desconto_field.dart';

/// Sessão com a permissão de conceder desconto. Sem ela o campo NÃO renderiza —
/// o que é o comportamento correto e tem teste próprio no fim.
class _SessaoComPermissao extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'dono@teste.com', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'oficina', name: 'Oficina'),
          role: 'owner',
          permissions: ['cashier.discount'],
          modules: ['os'],
        ),
      );
}

/// Cargo que recebe dinheiro mas não perdoa dívida.
class _SessaoSemPermissao extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u2', email: 'caixa@teste.com', fullName: 'Caixa'),
          activeTenant: Tenant(id: 't1', slug: 'oficina', name: 'Oficina'),
          role: 'caixa',
          permissions: ['cashier.write'],
          modules: ['os'],
        ),
      );
}

/// Dois defeitos que este arquivo existe para não deixar voltar:
///
/// 1. O campo ficava atrás de "só aparece se sobrar saldo". Como o valor
///    recebido nasce igual ao total, nunca sobrava — o campo era invisível e
///    descobri-lo exigia primeiro digitar um valor menor.
/// 2. O aviso "desconto maior que o saldo" disparava para QUALQUER valor,
///    porque o saldo passado já vinha descontado do valor digitado.
///
/// Os dois compilavam e passavam em revisão. Só aparecem ao montar a tela.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> montar(
    WidgetTester tester, {
    required double saldo,
    String texto = '',
    bool comPermissao = true,
  }) async {
    final ctrl = TextEditingController(text: texto);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(
            comPermissao ? _SessaoComPermissao.new : _SessaoSemPermissao.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DescontoField(
              controller: ctrl,
              motivoController: TextEditingController(),
              saldo: saldo,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('desconto dentro do saldo NÃO acusa excesso', (tester) async {
    await montar(tester, saldo: 100, texto: '10');
    expect(find.textContaining('maior que o saldo'), findsNothing);
  });

  testWidgets('desconto igual ao saldo é aceito — perdoar tudo é caso real',
      (tester) async {
    await montar(tester, saldo: 100, texto: '100');
    expect(find.textContaining('maior que o saldo'), findsNothing);
  });

  testWidgets('só acusa quando passa mesmo do saldo', (tester) async {
    await montar(tester, saldo: 100, texto: '150');
    expect(find.textContaining('maior que o saldo'), findsOneWidget);
  });

  testWidgets('é um campo de DINHEIRO: prefixo R\$ e número à direita',
      (tester) async {
    await montar(tester, saldo: 100);
    final campo = tester.widget<TextField>(find.byType(TextField).first);
    expect(campo.decoration?.prefixText, 'R\$ ');
    expect(campo.textAlign, TextAlign.right);
  });

  testWidgets('o motivo só aparece depois que há desconto', (tester) async {
    await montar(tester, saldo: 100);
    expect(find.textContaining('Motivo do desconto'), findsNothing);
    await montar(tester, saldo: 100, texto: '10');
    expect(find.textContaining('Motivo do desconto'), findsOneWidget);
  });

  testWidgets('sem cashier.discount o campo não existe na tela', (tester) async {
    // Esconder não é proteger (o backend valida de novo), mas oferecer um
    // controle que o cargo não pode usar é convidar ao erro.
    await montar(tester, saldo: 100, texto: '10', comPermissao: false);
    expect(find.byType(TextField), findsNothing);
  });
}
