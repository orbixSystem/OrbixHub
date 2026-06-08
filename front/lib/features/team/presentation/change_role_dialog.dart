import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../domain/team_models.dart';
import 'reauth_dialog.dart';
import 'team_providers.dart';

/// Opens the change-role form for [employee]. Owner option is only offered when
/// the caller is an owner; if [employee] is the last active owner, demoting them
/// to a non-owner role is blocked client-side (the backend still enforces it).
Future<void> showChangeRoleDialog(
  BuildContext context,
  WidgetRef ref,
  Employee employee, {
  required bool callerIsOwner,
  required bool isLastActiveOwner,
}) async {
  final roles = ref.read(teamRolesProvider).asData?.value ?? const <RoleOption>[];
  if (roles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível carregar os cargos.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => _ChangeRoleDialog(
      ref: ref,
      employee: employee,
      roles: roles,
      callerIsOwner: callerIsOwner,
      isLastActiveOwner: isLastActiveOwner,
    ),
  );
}

class _ChangeRoleDialog extends StatefulWidget {
  const _ChangeRoleDialog({
    required this.ref,
    required this.employee,
    required this.roles,
    required this.callerIsOwner,
    required this.isLastActiveOwner,
  });

  final WidgetRef ref;
  final Employee employee;
  final List<RoleOption> roles;
  final bool callerIsOwner;
  final bool isLastActiveOwner;

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  late String _role = widget.employee.role;
  bool _busy = false;

  /// Roles the caller is allowed to assign: 'owner' only when the caller is an
  /// owner; non-owner roles disabled when this is the last active owner.
  bool _enabled(RoleOption r) {
    if (r.key == 'owner') return widget.callerIsOwner;
    if (widget.isLastActiveOwner) return false;
    return true;
  }

  Future<void> _submit() async {
    if (_role == widget.employee.role) {
      Navigator.of(context).pop();
      return;
    }
    final password = await showReauthDialog(context);
    if (password == null) return;
    if (!mounted) return;

    setState(() => _busy = true);
    final repo = widget.ref.read(teamRepositoryProvider);
    try {
      await repo.changeRole(
        membershipId: widget.employee.membershipId,
        role: _role,
        currentPassword: password,
      );
      widget.ref.invalidate(teamEmployeesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargo atualizado.')),
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
    final items = [
      for (final r in widget.roles)
        DropdownMenuItem(
          value: r.key,
          enabled: _enabled(r),
          child: Text(
            r.name,
            style: _enabled(r)
                ? null
                : const TextStyle(color: AppColors.inkFaint),
          ),
        ),
    ];

    return AlertDialog(
      title: Text('Cargo de ${widget.employee.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Cargo'),
            items: items,
            onChanged: _busy ? null : (v) => setState(() => _role = v ?? _role),
          ),
          if (widget.isLastActiveOwner) ...[
            const SizedBox(height: 12),
            const Text(
              'Este é o único proprietário ativo. Promova outro membro a '
              'proprietário antes de alterar este cargo.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
            ),
          ],
        ],
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
