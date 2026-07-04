import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/team_models.dart';
import 'change_role_dialog.dart';
import 'invite_dialog.dart';
import 'reauth_dialog.dart';
import 'team_guards.dart';
import 'team_providers.dart';

/// How often the Team screen silently refreshes itself while open.
const _pollInterval = Duration(seconds: 30);

/// Team management body (Funcionários ativos + Convites pendentes +
/// Funcionários desativados, each collapsible). Body-only content; the shell
/// owns the chrome. While the screen is mounted it polls the backend every
/// [_pollInterval]; the timer is canceled on dispose. Guardrails are reflected
/// in the UI from the loaded data + session `me`, but the backend remains the
/// source of truth.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  Timer? _poll;

  /// Aba ativa: 0 = Funcionários, 1 = Convites.
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Background refresh while the screen is open. Stopped in dispose() so the
    // polling never outlives the route.
    _poll = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      ref.invalidate(teamEmployeesProvider);
      ref.invalidate(pendingInvitesProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final me = session.me;
    final neu = context.neu;
    final isMobile = context.isMobile;
    final employeesAsync = ref.watch(teamEmployeesProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);

    final inviteCount = invitesAsync.asData?.value.length ?? 0;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      children: [
        // Cabeçalho: título + botão Convidar.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: TextStyle(color: neu.inkMuted, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            NeuButton(
              label: 'Convidar',
              icon: Icons.person_add_alt_1,
              onPressed: () => showInviteDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Abas: Funcionários · Convites (N).
        Align(
          alignment: Alignment.centerLeft,
          child: NeuSegmented<int>(
            segments: {
              0: 'Funcionários',
              1: inviteCount > 0 ? 'Convites ($inviteCount)' : 'Convites',
            },
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        const SizedBox(height: 20),

        // Conteúdo da aba (troca com fade suave).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tab == 0
              ? _EmployeesTab(
                  key: const ValueKey('funcionarios'),
                  employeesAsync: employeesAsync,
                  me: me,
                )
              : _InvitesTab(
                  key: const ValueKey('convites'),
                  invitesAsync: invitesAsync,
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Aba "Funcionários": ativos + (se houver) desativados num collapsible.
class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab({
    super.key,
    required this.employeesAsync,
    required this.me,
  });

  final AsyncValue<List<Employee>> employeesAsync;
  final Me me;

  @override
  Widget build(BuildContext context) {
    return employeesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _LoadingBox(),
      error: (e, _) => _ErrorBox(
        message:
            e is AppException ? e.message : 'Erro ao carregar funcionários.',
      ),
      data: (employees) {
        final active = employees.where((e) => e.status == 'active').toList();
        final disabled =
            employees.where((e) => e.status != 'active').toList();
        return Column(
          children: [
            if (active.isEmpty)
              const NeuEmptyState(
                icon: Icons.groups_outlined,
                title: 'Nenhum funcionário ativo',
                message:
                    'Convide sua equipe para que cada um acesse o sistema com o próprio cargo.',
              )
            else
              for (final emp in active)
                _EmployeeCard(employee: emp, me: me, employees: employees),
            if (disabled.isNotEmpty) ...[
              const SizedBox(height: 20),
              _CollapsibleSection(
                title: 'Desativados',
                count: disabled.length,
                initiallyExpanded: false,
                child: Column(
                  children: [
                    for (final emp in disabled)
                      _EmployeeCard(
                          employee: emp, me: me, employees: employees),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Aba "Convites": convites pendentes.
class _InvitesTab extends StatelessWidget {
  const _InvitesTab({super.key, required this.invitesAsync});

  final AsyncValue<List<PendingInvite>> invitesAsync;

  @override
  Widget build(BuildContext context) {
    return invitesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _LoadingBox(),
      error: (e, _) => _ErrorBox(
        message: e is AppException ? e.message : 'Erro ao carregar convites.',
      ),
      data: (invites) => invites.isEmpty
          ? const NeuEmptyState(
              icon: Icons.mark_email_unread_outlined,
              title: 'Nenhum convite pendente',
              message:
                  'Convites que você enviar aparecem aqui até serem aceitos.',
            )
          : Column(
              children: [
                for (final inv in invites) _InviteCard(invite: inv),
              ],
            ),
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

String _formatDay(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
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
                    _AccessExpiry(expiresAt: employee.accessExpiresAt),
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

/// Inline "acesso expira/expirado em …" indicator. Renders nothing when the
/// member has no access expiry set. Turns warning (≤7 dias) / danger (vencido).
class _AccessExpiry extends StatelessWidget {
  const _AccessExpiry({required this.expiresAt});
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final at = expiresAt;
    if (at == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final expired = !at.isAfter(now);
    final soon = !expired && at.difference(now) <= const Duration(days: 7);
    final color = expired
        ? AppColors.danger
        : soon
            ? AppColors.warning
            : scheme.onSurfaceVariant;
    final label = expired
        ? 'acesso expirado em ${_formatDay(at)}'
        : 'acesso expira em ${_formatDay(at)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(expired ? Icons.lock_clock_outlined : Icons.schedule,
            size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: (expired || soon) ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
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

/// A section header (title + count) that toggles its body open/closed.
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final int count;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                Text(widget.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 10),
                _Badge(
                  text: '${widget.count}',
                  bg: scheme.surfaceContainerHighest,
                  fg: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
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

