import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/team_models.dart';
import 'change_role_dialog.dart';
import 'invite_dialog.dart';
import 'reauth_dialog.dart';
import 'team_guards.dart';
import 'team_providers.dart';

/// Team management body (Funcionários + Convites pendentes). Body-only content;
/// the shell owns the chrome. Guardrails are reflected in the UI from the loaded
/// data + session `me`, but the backend remains the source of truth.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final me = session.me;
    final scheme = Theme.of(context).colorScheme;
    final employeesAsync = ref.watch(teamEmployeesProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Equipe',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Gerencie funcionários, cargos e convites da sua oficina.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: () {
                ref.invalidate(teamEmployeesProvider);
                ref.invalidate(pendingInvitesProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              // The global filled-button theme uses Size.fromHeight(50) (width =
              // infinity), which is fine in stretch columns but explodes as a
              // non-flex child of a Row (measured with unbounded width). Pin a
              // finite minimum width here.
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => showInviteDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Convidar'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionTitle('Funcionários'),
        const SizedBox(height: 14),
        employeesAsync.when(
          loading: () => const _LoadingBox(),
          error: (e, _) => _ErrorBox(
            message:
                e is AppException ? e.message : 'Erro ao carregar funcionários.',
          ),
          data: (employees) {
            if (employees.isEmpty) {
              return const _EmptyHint('Nenhum funcionário ainda.');
            }
            return Column(
              children: [
                for (final emp in employees)
                  _EmployeeCard(
                    employee: emp,
                    me: me,
                    employees: employees,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        _SectionTitle('Convites pendentes'),
        const SizedBox(height: 14),
        invitesAsync.when(
          loading: () => const _LoadingBox(),
          error: (e, _) => _ErrorBox(
            message:
                e is AppException ? e.message : 'Erro ao carregar convites.',
          ),
          data: (invites) {
            if (invites.isEmpty) {
              return const _EmptyHint('Nenhum convite pendente.');
            }
            return Column(
              children: [
                for (final inv in invites) _InviteCard(invite: inv),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

String _formatDate(DateTime? dt, {String fallback = '—'}) {
  if (dt == null) return fallback;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _EmployeeCard extends ConsumerWidget {
  const _EmployeeCard({
    required this.employee,
    required this.me,
    required this.employees,
  });

  final Employee employee;
  final Me me;
  final List<Employee> employees;

  bool get _isSelf => employee.userId == me.user.id;
  bool get _isActive => employee.status == 'active';
  TeamActions get _actions => teamActions(me, employee, employees);
  bool get _isLastActiveOwner {
    final activeOwners =
        employees.where((e) => e.role == 'owner' && e.status == 'active').length;
    return employee.role == 'owner' && _isActive && activeOwners <= 1;
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    await showChangeRoleDialog(
      context,
      ref,
      employee,
      callerIsOwner: me.role == 'owner',
      isLastActiveOwner: _isLastActiveOwner,
    );
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final password = await showReauthDialog(context);
    if (password == null || !context.mounted) return;
    final repo = ref.read(teamRepositoryProvider);
    try {
      await repo.deactivate(
        membershipId: employee.membershipId,
        currentPassword: password,
      );
      ref.invalidate(teamEmployeesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionário desativado.')),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final password = await showReauthDialog(context);
    if (password == null || !context.mounted) return;
    final repo = ref.read(teamRepositoryProvider);
    try {
      await repo.activate(
        membershipId: employee.membershipId,
        currentPassword: password,
      );
      ref.invalidate(teamEmployeesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionário reativado.')),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build the actions menu honoring the client-side guardrails.
    final scheme = Theme.of(context).colorScheme;
    final actions = _actions;
    final menuEntries = <PopupMenuEntry<String>>[];
    if (_isActive) {
      // No self-role, and last active owner can't be demoted from the menu —
      // the dialog still gates options, but hide the entry only for self.
      if (actions.canChangeRole) {
        menuEntries.add(const PopupMenuItem(
          value: 'role',
          child: Text('Trocar cargo'),
        ));
      }
      // No self-deactivate; never deactivate the last active owner.
      if (actions.canDeactivate) {
        menuEntries.add(const PopupMenuItem(
          value: 'deactivate',
          child: Text('Desativar'),
        ));
      }
    } else {
      menuEntries.add(const PopupMenuItem(
        value: 'activate',
        child: Text('Ativar'),
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _Avatar(name: employee.fullName, dimmed: !_isActive),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (_isSelf) ...[
                      const SizedBox(width: 8),
                      const _Badge(
                        text: 'Você',
                        bg: AppColors.brandTint,
                        fg: AppColors.brandDeep,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Badge(
                      text: employee.role,
                      bg: scheme.surfaceContainerHighest,
                      fg: scheme.onSurface,
                    ),
                    _Badge(
                      text: _isActive ? 'ativo' : 'desativado',
                      bg: _isActive
                          ? AppColors.successTint
                          : scheme.surfaceContainerHighest,
                      fg: _isActive
                          ? AppColors.success
                          : scheme.onSurfaceVariant,
                    ),
                    Text(
                      'último acesso: ${_formatDate(employee.lastAccess)}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (menuEntries.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Ações',
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
              itemBuilder: (_) => menuEntries,
              onSelected: (value) {
                switch (value) {
                  case 'role':
                    _changeRole(context, ref);
                  case 'deactivate':
                    _deactivate(context, ref);
                  case 'activate':
                    _activate(context, ref);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.invite});
  final PendingInvite invite;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _resend() async {
    final expiresIn = await _pickExpiry();
    if (expiresIn == null || !mounted) return;
    final password = await showReauthDialog(context);
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(teamRepositoryProvider);
    try {
      await repo.resendInvite(
        widget.invite.id,
        expiresIn: expiresIn,
        currentPassword: password,
      );
      ref.invalidate(pendingInvitesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite reenviado.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickExpiry() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Nova validade'),
          children: [
            for (final (label, token) in inviteExpiryOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(token),
                child: Text(label),
              ),
          ],
        );
      },
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar convite'),
        content: Text(
          'Cancelar o convite para ${widget.invite.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar convite'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(teamRepositoryProvider);
    try {
      await repo.cancelInvite(widget.invite.id);
      ref.invalidate(pendingInvitesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite cancelado.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final invite = widget.invite;
    final expiry = invite.expiresAt == null
        ? 'sem expiração'
        : 'expira em ${_formatDate(invite.expiresAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Badge(
                      text: invite.role,
                      bg: scheme.surfaceContainerHighest,
                      fg: scheme.onSurface,
                    ),
                    const _Badge(
                      text: 'pendente',
                      bg: AppColors.warningTint,
                      fg: AppColors.warning,
                    ),
                    Text(
                      expiry,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            TextButton(
              onPressed: _resend,
              child: const Text('Reenviar'),
            ),
            TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.dimmed = false});
  final String name;
  final bool dimmed;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            dimmed ? scheme.surfaceContainerHighest : AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: dimmed ? scheme.onSurfaceVariant : AppColors.brandDeep,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: const TextStyle(
            color: AppColors.danger, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}
