import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev_inbox.dart';
import 'dev_role.dart';

/// Content of the dev-inbox bottom sheet. Theme-aware (light + dark) and shows
/// the latest invite link / verification & reset tokens with copy buttons.
class DevInboxModal extends ConsumerWidget {
  const DevInboxModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final async = ref.watch(devInboxProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Warning banner.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: colors.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ferramenta de desenvolvimento — não aparece em produção.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _RolePreview(),
            const SizedBox(height: 12),
            // Title row.
            Row(
              children: [
                Icon(Icons.inbox_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dev inbox',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(devInboxProvider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Body.
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Errors (incl. 404 in prod) are treated as "nothing generated".
                error: (_, _) => const _EmptyState(),
                data: (entries) {
                  if (entries.isEmpty) return const _EmptyState();
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _EntryCard(entry: entries[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pré-visualizar a UI como outro cargo (dev). Cliente-only: muda só o que a tela
/// mostra (menu/botões/permissões); o backend usa o cargo real do JWT.
class _RolePreview extends ConsumerWidget {
  const _RolePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final override = ref.watch(devRoleOverrideProvider);
    void setRole(String? r) =>
        ref.read(devRoleOverrideProvider.notifier).set(r);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text('Pré-visualizar como cargo',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Real'),
                selected: override == null,
                onSelected: (_) => setRole(null),
              ),
              for (final r in devPreviewRoles)
                ChoiceChip(
                  label: Text(r.$2),
                  selected: override == r.$1,
                  onSelected: (_) => setRole(r.$1),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Muda só a visão no app (cliente). O servidor continua usando seu '
            'cargo real — ações podem dar 403 se o cargo real não permitir.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_unread_outlined,
              size: 40, color: colors.outline),
          const SizedBox(height: 12),
          Text(
            'Nada gerado ainda.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final DevInboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ago = _relativeTime(entry.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.label,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SelectableText(
              entry.value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (ago != null)
                Expanded(
                  child: Text(
                    'gerado $ago',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: entry.value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copiado!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tiny relative formatter: "há X segundos/minutos/horas/dias". Returns null
/// when [time] is null so the caller can omit the timestamp entirely.
String? _relativeTime(DateTime? time) {
  if (time == null) return null;
  final diff = DateTime.now().difference(time);
  if (diff.isNegative) return 'há instantes';
  if (diff.inSeconds < 60) return 'há ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'há $h ${h == 1 ? 'hora' : 'horas'}';
  }
  final d = diff.inDays;
  return 'há $d ${d == 1 ? 'dia' : 'dias'}';
}
