import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/validators.dart';

/// Prompts for the caller's current password (owner-gated mutations require it)
/// and returns the typed value on confirm, or null if canceled/dismissed.
Future<String?> showReauthDialog(
  BuildContext context, {
  String title = 'Confirme sua senha',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReauthDialog(title: title),
  );
}

class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog({required this.title});

  final String title;

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: widget.title,
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Confirmar',
          icon: Icons.check_rounded,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por segurança, confirme sua senha para continuar.',
            ),
            const SizedBox(height: 16),
            // O olhinho vem do próprio NeuTextField desde que ele passou a
            // cuidar disso — antes era montado aqui à mão, com o ícone invertido
            // em relação ao da tela de certificado fiscal.
            NeuTextField(
              label: 'Senha atual *',
              controller: _controller,
              autofocus: true,
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              validator: Validators.required('Senha atual'),
            ),
          ],
        ),
      ),
    );
  }
}
