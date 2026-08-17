import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'send_tracking_email_dialog.dart';

/// URL pública de acompanhamento da OS. A origem vem de `Uri.base.origin` na
/// WEB; em desktop/mobile `Uri.base` é `file://` (sem origin http → `.origin`
/// lança StateError), então usamos `AppConfig.publicWebUrl`. O app usa hash URL
/// strategy, então o link precisa do `/#/` — sem ele a rota pública não casa e o
/// cliente cai no login.
String osTrackingUrl(String token) {
  final origin = kIsWeb
      ? Uri.base.origin
      : AppConfig.publicWebUrl.replaceFirst(RegExp(r'/+$'), '');
  return '$origin/#/t/$token';
}

/// O link em si + as formas de entregá-lo ao cliente: copiar, WhatsApp (em
/// breve) e e-mail (o SERVIDOR envia — ver [SendTrackingEmailDialog]).
///
/// Um só lugar para os dois pontos onde o link é oferecido: a aba **Cliente** da
/// OS e o diálogo que aparece logo depois de criar a OS.
class OsTrackingLinkActions extends ConsumerWidget {
  const OsTrackingLinkActions({super.key, required this.order});

  final ServiceOrder order;

  String get _url => osTrackingUrl(order.publicToken!);

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copiado')));
  }

  /// Envio por e-mail: confirma o endereço do cliente ANTES de disparar (o
  /// cadastro pode estar errado/desatualizado) e o servidor é quem envia.
  Future<void> _email(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(osRepositoryProvider);
    final sent = await SendTrackingEmailDialog.show(
      context,
      repo: repo,
      order: order,
    );
    if (sent == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Link enviado para $sent')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: SelectableText(
            _url,
            style: TextStyle(fontSize: 13, color: neu.inkMuted),
          ),
        ),
        const SizedBox(height: 14),
        // Enviar o link ao cliente é a ÚNICA coisa da OS que não funciona
        // offline (o cliente precisa alcançar o servidor pelo link).
        RequiresConnection(
          reason: 'o envio do link ao cliente exige internet',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NeuButton(
                label: 'Copiar link',
                icon: Icons.copy_rounded,
                onPressed: () => _copy(context),
              ),
              // Desabilitado de propósito: o envio por WhatsApp ainda não
              // está pronto — o botão fica visível (o usuário sabe que vem)
              // mas inerte (`onPressed: null` → opacidade + sem clique).
              const Tooltip(
                message: 'Envio por WhatsApp em breve',
                child: NeuButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_outlined,
                  kind: NeuButtonKind.secondary,
                  onPressed: null,
                ),
              ),
              NeuButton(
                label: 'E-mail',
                icon: Icons.email_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: () => _email(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Passo de entrega do link logo depois de criar a OS: a hora em que o cliente
/// ainda está no balcão é a hora de mandar o link. Só depois do "Abrir a OS" o
/// app navega para a ficha — sair antes disso empurraria o envio para um card
/// que o atendente teria de ir procurar.
///
/// Só aparece quando a OS já tem `publicToken` (OS criada offline nasce sem
/// token: o link só existe depois que o servidor a registra).
class OsTrackingLinkDialog extends StatelessWidget {
  const OsTrackingLinkDialog({super.key, required this.order});

  final ServiceOrder order;

  static Future<void> show(
    BuildContext context, {
    required ServiceOrder order,
  }) {
    return showDialog<void>(
      context: context,
      // Fechar no clique fora seria fácil de disparar sem querer ao selecionar
      // o link — a saída daqui é o botão.
      barrierDismissible: false,
      builder: (_) => OsTrackingLinkDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final customer = order.customerName?.trim();
    return NeuDialog(
      title: '${order.number} criada',
      maxWidth: context.isMobile ? 560 : 520,
      actions: [
        NeuButton(
          label: 'Abrir a OS',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer != null && customer.isNotEmpty
                ? 'Envie o link de acompanhamento para $customer seguir a OS em '
                    'tempo real e falar com a oficina.'
                : 'Envie o link de acompanhamento para o cliente seguir a OS em '
                    'tempo real e falar com a oficina.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          OsTrackingLinkActions(order: order),
          const SizedBox(height: 12),
          Text(
            'Dá para enviar depois pela aba Cliente da OS.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}
