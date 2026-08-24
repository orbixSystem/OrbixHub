import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import 'support_section.dart';

/// Suporte da Orbix — tela própria, alcançável pelo ícone do fone na barra
/// superior. Corpo apenas; a moldura é do shell.
///
/// Saiu de dentro de Configurações de propósito: pedir ajuda não é ajustar o
/// sistema, e quem está travado não deveria ter de procurar socorro dentro de
/// um menu de preferências. No topo, ao lado do sino, ele está sempre a um
/// clique de qualquer tela.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      // A seção preenche a altura (conversa rolando, campo ancorado embaixo),
      // então este Padding precisa entregar altura limitada — o shell entrega.
      child: const SupportSection(),
    );
  }
}
