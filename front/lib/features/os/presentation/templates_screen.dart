import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';
import 'template_form_dialog.dart';

const _maxContentWidth = 940.0;

/// Gestão de templates de OS: lista (nome + nº de itens + descrição), criar,
/// editar e excluir. Cada template é um conjunto de itens reaproveitável que
/// pode ser aplicado a uma OS. Corpo apenas — a moldura é do shell.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  bool _canWrite(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('os.write') ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(templateListProvider);
    final canWrite = _canWrite(ref);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/m/os'),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar'),
                  ),
                  const Spacer(),
                  if (canWrite)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Novo template'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Templates de serviço',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Conjuntos de itens reaproveitáveis para aplicar a uma OS.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: listAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e is AppException
                              ? e.message
                              : 'Erro ao carregar os templates.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40)),
                          onPressed: () =>
                              ref.invalidate(templateListProvider),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  ),
                  data: (templates) {
                    if (templates.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dashboard_customize_outlined,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(height: 12),
                            const Text('Nenhum template ainda.'),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: templates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _TemplateCard(
                        template: templates[i],
                        canWrite: canWrite,
                        onEdit: () => _edit(context, ref, templates[i]),
                        onDelete: () => _delete(context, ref, templates[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await TemplateFormDialog.show(context, ref);
    if (draft == null) return;
    try {
      await ref.read(osRepositoryProvider).createTemplate(draft);
      ref.invalidate(templateListProvider);
      if (context.mounted) {
        showNeuSuccessSnackBar(context, 'Template criado.');
      }
    } on AppException catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, e.message);
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    OsTemplate template,
  ) async {
    final draft = await TemplateFormDialog.show(context, ref, template: template);
    if (draft == null) return;
    try {
      await ref.read(osRepositoryProvider).updateTemplate(template.id, draft);
      ref.invalidate(templateListProvider);
      if (context.mounted) {
        showNeuSuccessSnackBar(context, 'Template atualizado.');
      }
    } on AppException catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, e.message);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OsTemplate template,
  ) async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Excluir template?',
      message: 'Excluir "${template.name}"? Não é possível desfazer.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(osRepositoryProvider).deleteTemplate(template.id);
      ref.invalidate(templateListProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, e.message);
      }
    }
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
  });

  final OsTemplate template;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = template.items.length;
    return Container(
      padding: const EdgeInsets.all(16),
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.dashboard_customize_outlined,
                color: AppColors.brandDeep, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'item' : 'itens'}'
                  '${template.description != null && template.description!.isNotEmpty ? ' · ${template.description}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money(template.total),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                'Total',
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          if (canWrite) ...[
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              color: scheme.error,
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

