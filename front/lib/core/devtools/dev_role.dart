import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Override de cargo SÓ para desenvolvimento (besouro): pré-visualizar a UI como
/// gerente/caixa/mecânico sem trocar de usuário. `null` = cargo real.
///
/// CLIENTE-ONLY: muda apenas o que a UI mostra (menu/botões/gating). O backend
/// continua enxergando o JWT real — então ações no servidor usam o cargo de
/// verdade. Serve para conferir rapidamente "como o atendente vê esta tela".
final devRoleOverrideProvider =
    NotifierProvider<DevRoleOverride, String?>(DevRoleOverride.new);

class DevRoleOverride extends Notifier<String?> {
  @override
  String? build() => null;

  /// `null` volta ao cargo real; senão força owner/gerente/caixa/mechanic.
  void set(String? role) => state = role;
}

/// Cargos que dá pra pré-visualizar (chave + rótulo PT-BR).
const devPreviewRoles = <(String, String)>[
  ('owner', 'Dono'),
  ('gerente', 'Gerente'),
  ('caixa', 'Caixa'),
  ('mechanic', 'Mecânico'),
];

const _allPerms = <String>[
  'customer.read', 'customer.write', 'subject.read', 'subject.write',
  'os.read', 'os.write', 'os.approve', 'inventory.read', 'tracking.manage',
  'cashier.read', 'cashier.write', 'cashier.manage', 'sale.read', 'sale.write',
  'invoice.issue', 'finance.read', 'finance.write', 'report.read',
  'users.manage', 'billing.manage', 'tenant.manage', 'settings.manage',
];

/// Mapa cargo→permissões que ESPELHA o seed do backend (para o preview do
/// besouro). Não é a verdade (o backend é) — só faz a UI refletir o cargo.
List<String> devPermissionsFor(String role) {
  switch (role) {
    case 'owner':
      return List.of(_allPerms);
    case 'gerente':
      return _allPerms.where((p) => p != 'billing.manage').toList();
    case 'caixa':
      return const [
        'customer.read', 'customer.write', 'subject.read', 'subject.write',
        'os.read', 'os.write', 'inventory.read',
        'cashier.read', 'cashier.write', 'sale.read', 'sale.write',
        'invoice.issue',
      ];
    case 'mechanic':
      return const [
        'customer.read', 'customer.write', 'subject.read', 'subject.write',
        'os.read', 'os.write', 'inventory.read', 'tracking.manage',
      ];
    default:
      return const [];
  }
}
