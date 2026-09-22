import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// Nota Fiscal ANUNCIADA, não escondida.
///
/// O módulo `invoice` está no plano (trial e pro), o backend emite, mas o fluxo
/// ponta a ponta ainda não é do cliente. Esconder faria parecer que o sistema
/// não emite nota; por isso os pontos de NF ficam visíveis, inertes e marcados
/// "Em breve".
///
/// `gatedNavItems` recebe o flag por parâmetro exatamente para que os dois
/// lados sejam testáveis: em debug `kInvoiceEnabled` é `true`, então sem essa
/// injeção o caminho "Em breve" só existiria num build de release — nunca em
/// teste.
Me _me({List<String> modules = const ['os', 'cashier', 'invoice']}) => Me(
      user: const User(id: 'u1', email: 'dono@x.dev', fullName: 'Dono'),
      activeTenant: const Tenant(id: 't1', slug: 'x', name: 'X'),
      role: 'owner',
      permissions: const [
        'os.read',
        'cashier.read',
        'invoice.issue',
        'invoice.read',
      ],
      modules: modules,
    );

void main() {
  test('NF não liberada: o item FICA, marcado "Em breve"', () {
    final itens = gatedNavItems(_me(), invoiceEnabled: false)
        .where((i) => i.route == '/m/invoice')
        .toList();

    // O que NÃO pode acontecer é o item desaparecer: era assim antes, e o
    // cliente concluía que o produto não emite nota.
    expect(itens, hasLength(1));
    expect(itens.single.label, 'Notas Fiscais');
    expect(itens.single.emBreve, isTrue);
  });

  test('NF liberada: o item volta a ser um destino normal', () {
    final itens = gatedNavItems(_me(), invoiceEnabled: true)
        .where((i) => i.route == '/m/invoice')
        .toList();

    expect(itens, hasLength(1));
    expect(itens.single.emBreve, isFalse);
  });

  test('sem o módulo no plano, NF não aparece nem como "Em breve"', () {
    // "Em breve" é promessa. Não se promete o que o cliente não contratou.
    for (final ligada in [true, false]) {
      final itens = gatedNavItems(
        _me(modules: const ['os', 'cashier']),
        invoiceEnabled: ligada,
      );
      expect(itens.where((i) => i.route == '/m/invoice'), isEmpty);
    }
  });

  test('o item em breve não rouba a seleção da rota atual', () {
    // A rota segue no NavItem (é a identidade do item) e o router manda
    // /m/invoice para a home enquanto o flag estiver desligado. O que não pode
    // é o item inerte aparecer ATIVO por causa de um prefixo de rota.
    final itens = gatedNavItems(_me(), invoiceEnabled: false);
    final selecionado = itens[selectedNavIndex(itens, '/m/cashier')];
    expect(selecionado.route, '/m/cashier');
  });
}
