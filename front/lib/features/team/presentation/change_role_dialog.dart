import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
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
  List<RoleOption> roles;
  try {
    roles = await ref.read(teamRolesProvider.future);
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
      showNeuErrorSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      for (final r in widget.roles)
        DropdownMenuItem(
          value: r.key,
          enabled: _enabled(r),
          child: Text(
            r.name,
            style: _enabled(r)
                ? null
                : TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
    ];

    return NeuDialog(
      title: 'Cargo de ${widget.employee.fullName}',
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Cargo *',
              style: TextStyle(
                color: context.neu.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            child: DropdownButtonFormField<String>(
              initialValue: _role,
              isExpanded: true,
              style: TextStyle(color: context.neu.ink, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: items,
              onChanged: _busy ? null : (v) => setState(() => _role = v ?? _role),
            ),
          ),
          if (widget.isLastActiveOwner) ...[
            const SizedBox(height: 12),
            Text(
              'Este é o único proprietário ativo. Promova outro membro a '
              'proprietário antes de alterar este cargo.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
