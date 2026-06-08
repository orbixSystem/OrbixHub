import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/team_models.dart';
import 'reauth_dialog.dart';
import 'team_providers.dart';

/// Expiry presets offered for invites — label → API `expiresIn` token.
const List<(String, String)> inviteExpiryOptions = [
  ('15 minutos', '15min'),
  ('30 minutos', '30min'),
  ('1 dia', '1day'),
  ('15 dias', '15days'),
  ('Sem expiração', 'never'),
];

/// Opens the "Convidar" form: email + role + expiry. On submit, re-authenticates
/// (current password) and calls `invite`, then refreshes the pending list.
Future<void> showInviteDialog(BuildContext context, WidgetRef ref) async {
  final rolesAsync = ref.read(teamRolesProvider);
  final roles = rolesAsync.asData?.value ?? const <RoleOption>[];
  if (roles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível carregar os cargos.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => _InviteDialog(ref: ref, roles: roles),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.ref, required this.roles});

  final WidgetRef ref;
  final List<RoleOption> roles;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late String _role = widget.roles.first.key;
  String _expiresIn = '15days';
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final password = await showReauthDialog(context);
    if (password == null) return;
    if (!mounted) return;

    setState(() => _busy = true);
    final repo = widget.ref.read(teamRepositoryProvider);
    try {
      await repo.invite(
        email: _emailController.text.trim(),
        role: _role,
        expiresIn: _expiresIn,
        currentPassword: password,
      );
      widget.ref.invalidate(pendingInvitesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite enviado.')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convidar para a equipe'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Informe um e-mail.';
                if (!value.contains('@')) return 'E-mail inválido.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Cargo'),
              items: [
                for (final r in widget.roles)
                  DropdownMenuItem(value: r.key, child: Text(r.name)),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _expiresIn,
              decoration: const InputDecoration(labelText: 'Validade'),
              items: [
                for (final (label, token) in inviteExpiryOptions)
                  DropdownMenuItem(value: token, child: Text(label)),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _expiresIn = v ?? _expiresIn),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar convite'),
        ),
      ],
    );
  }
}
