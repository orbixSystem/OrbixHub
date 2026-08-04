import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../domain/expense_status.dart';

/// Ícone por CHAVE de categoria.
///
/// Mapa const de propósito: o servidor manda a chave ('energia'), não um
/// codepoint. Montar `IconData(codePoint)` em runtime quebra no build de release
/// — o Flutter faz tree-shake dos ícones e só preserva os que aparecem
/// literalmente no código, então o ícone viraria um quadrado vazio.
///
/// Chave desconhecida (categoria criada pela cliente) cai num ícone neutro em
/// vez de sumir.
const Map<String, IconData> _icones = {
  'aluguel': Icons.home_work_outlined,
  'energia': Icons.bolt_outlined,
  'agua': Icons.water_drop_outlined,
  'internet': Icons.wifi_rounded,
  'telefone': Icons.phone_in_talk_outlined,
  'impostos': Icons.account_balance_outlined,
  'fornecedor': Icons.local_shipping_outlined,
  'produto': Icons.inventory_2_outlined,
  'salarios': Icons.badge_outlined,
  'manutencao': Icons.handyman_outlined,
  'outros': Icons.receipt_long_outlined,
};

IconData iconeDaCategoria(String? chave) =>
    _icones[chave] ?? Icons.label_outline_rounded;

/// Chaves de ícone oferecidas ao criar categoria.
///
/// Derivadas do MAPA acima, não de uma lista paralela: o backend valida a chave
/// contra a whitelist dele (`ICON_KEYS`), e uma segunda lista escrita à mão aqui
/// divergiria no primeiro ícone novo — o formulário ofereceria uma chave que a
/// API recusa, ou deixaria de oferecer uma que ela aceita.
List<String> get chavesDeIcone => _icones.keys.toList(growable: false);

/// Converte `#RRGGBB` do servidor em [Color]. Valor inválido cai no cinza
/// neutro — cor de categoria é decoração, nunca motivo para a tela quebrar.
Color corHex(String? hex, {Color fallback = const Color(0xFF6B7280)}) {
  if (hex == null) return fallback;
  final s = hex.replaceFirst('#', '').trim();
  if (s.length != 6) return fallback;
  final v = int.tryParse(s, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Cor da SITUAÇÃO (não confundir com a cor da categoria).
///
/// Vem dos tokens do tema, não de hex solto: assim claro/escuro e futuros
/// ajustes de paleta valem aqui sem tocar nesta tela.
Color corDoStatus(NeuTokens neu, ExpenseStatus s) => switch (s) {
      ExpenseStatus.pago => neu.success,
      ExpenseStatus.vencido => neu.danger,
      // Tangerina: chama atenção sem gritar "erro" — vencer hoje é normal,
      // vencido é problema.
      ExpenseStatus.venceHoje => neu.accent,
      ExpenseStatus.venceEmBreve => neu.warning,
      ExpenseStatus.aPagar => neu.info,
    };

/// Fundo suave do mesmo par, para o chip de status.
Color corDoStatusTint(NeuTokens neu, ExpenseStatus s) => switch (s) {
      ExpenseStatus.pago => neu.successTint,
      ExpenseStatus.vencido => neu.dangerTint,
      ExpenseStatus.venceHoje => neu.accentTint,
      ExpenseStatus.venceEmBreve => neu.warningTint,
      ExpenseStatus.aPagar => neu.infoTint,
    };

/// Ícone que acompanha o status — cor sozinha não serve para quem não a
/// distingue (daltonismo) nem em impressão preto-e-branco.
IconData iconeDoStatus(ExpenseStatus s) => switch (s) {
      ExpenseStatus.pago => Icons.check_circle_outline_rounded,
      ExpenseStatus.vencido => Icons.error_outline_rounded,
      ExpenseStatus.venceHoje => Icons.today_outlined,
      ExpenseStatus.venceEmBreve => Icons.schedule_rounded,
      ExpenseStatus.aPagar => Icons.event_outlined,
    };

/// "vence em 3 dias" / "venceu há 6 dias" — o texto que a cliente lê primeiro.
String textoDoPrazo(ExpenseStatus s, int dias) => switch (s) {
      ExpenseStatus.pago => 'Pago',
      ExpenseStatus.venceHoje => 'Vence hoje',
      ExpenseStatus.vencido =>
        dias == -1 ? 'Venceu ontem' : 'Venceu há ${-dias} dias',
      _ => dias == 1 ? 'Vence amanhã' : 'Vence em $dias dias',
    };
