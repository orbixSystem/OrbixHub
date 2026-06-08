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
  // Wait for the roles future to resolve — on the FIRST open the provider is
  // still loading, so reading it synchronously used to bail with an error.
  List<RoleOption> roles;
  try {
    roles = await ref.read(teamRolesProvider.future);
  } on AppException {
    roles = const <RoleOption>[];
  } catch (_) {
    roles = const <RoleOption>[];
  }
  if (!context.mounted) return;
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
  DateTime? _accessExpiresAt; // null = acesso sem expiração
  bool _busy = false;

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickAccessDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _accessExpiresAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Acesso válido até',
    );
    if (picked != null) setState(() => _accessExpiresAt = picked);
  }

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
      final access = _accessExpiresAt;
      await repo.invite(
        email: _emailController.text.trim(),
        role: _role,
        expiresIn: _expiresIn,
        currentPassword: password,
        accessExpiresAt: access == null
            ? null
            : DateTime(access.year, access.month, access.day, 23, 59, 59)
                .toUtc()
                .toIso8601String(),
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
      // Pin a comfortable width so the form fields breathe and the action
      // buttons sit side by side instead of stacking vertically.
      content: SizedBox(
        width: 420,
        child: Form(
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
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Acesso válido até',
                helperText: 'Após esta data o funcionário perde o acesso.',
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _accessExpiresAt == null
                          ? 'Sem expiração'
                          : _fmtDate(_accessExpiresAt!),
                    ),
                  ),
                  if (_accessExpiresAt != null)
                    IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _accessExpiresAt = null),
                    ),
                  IconButton(
                    tooltip: 'Escolher data',
                    icon: const Icon(Icons.event, size: 20),
                    onPressed: _busy ? null : _pickAccessDate,
                  ),
                ],
              ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        // A single min-width Row keeps both buttons on the same line with a
        // clean gap; OverflowBar measures action children at unbounded width,
        // so the Row must be MainAxisSize.min (and the FilledButton pinned).
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 12),
            _busy
                ? FilledButton(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: null,
                    child: const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _submit,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar convite'),
                  ),
          ],
        ),
      ],
    );
  }
}
