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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Template criado.')));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template atualizado.')));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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

/// Mutável: linha de item em edição no formulário de template.
class _DraftRow {
  _DraftRow({
    required this.kind,
    this.inventoryItemId,
    required this.name,
    required this.quantity,
    this.unitPrice,
  });

  String kind;
  String? inventoryItemId;
  String name;
  double quantity;
  double? unitPrice;

  OsTemplateItemDraft toDraft() => OsTemplateItemDraft(
        kind: kind,
        inventoryItemId: inventoryItemId,
        name: inventoryItemId == null ? name : null,
        quantity: quantity,
        unitPrice: unitPrice,
      );
}

/// Formulário (dialog) de criação/edição de template: nome, descrição e o
/// editor de itens (do estoque via picker OU avulso). Devolve um
/// [OsTemplateDraft] via Navigator.pop, ou null em Cancelar.
class TemplateFormDialog extends ConsumerStatefulWidget {
  const TemplateFormDialog({super.key, this.template});

  final OsTemplate? template;

  static Future<OsTemplateDraft?> show(
    BuildContext context,
    WidgetRef ref, {
    OsTemplate? template,
  }) {
    return showDialog<OsTemplateDraft>(
      context: context,
      builder: (_) => TemplateFormDialog(template: template),
    );
  }

  @override
  ConsumerState<TemplateFormDialog> createState() =>
      _TemplateFormDialogState();
}

class _TemplateFormDialogState extends ConsumerState<TemplateFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final List<_DraftRow> _items;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.name ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _items = [
      for (final i in t?.items ?? const <OsTemplateItem>[])
        _DraftRow(
          kind: i.kind,
          inventoryItemId: i.inventoryItemId,
          name: i.name,
          quantity: double.tryParse(i.quantity) ?? 1,
          unitPrice:
              i.unitPrice == null ? null : double.tryParse(i.unitPrice!),
        ),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final draft = await _TemplateItemDialog.show(context);
    if (draft == null) return;
    setState(() {
      _items.add(_DraftRow(
        kind: draft.kind,
        inventoryItemId: draft.inventoryItemId,
        name: draft.name ?? '',
        quantity: draft.quantity ?? 1,
        unitPrice: draft.unitPrice,
      ));
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final desc = _description.text.trim();
    Navigator.of(context).pop(
      OsTemplateDraft(
        name: name,
        description: desc.isEmpty ? null : desc,
        items: _items.map((r) => r.toDraft()).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.template != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar template' : 'Novo template'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Itens',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36)),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Nenhum item.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      _ItemTile(
                        row: _items[i],
                        onRemove: () => setState(() => _items.removeAt(i)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(isEdit ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.row, required this.onRemove});

  final _DraftRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isService = row.kind == 'service';
    final qty = row.quantity == row.quantity.roundToDouble()
        ? row.quantity.toInt().toString()
        : row.quantity.toString();
    final detail = [
      qty,
      if (row.unitPrice != null) '× ${money(row.unitPrice!.toString())}',
    ].join(' ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        isService
            ? Icons.design_services_outlined
            : Icons.inventory_2_outlined,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      title: Text(row.name),
      subtitle: Text(detail,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        color: AppColors.danger,
        tooltip: 'Remover',
        onPressed: onRemove,
      ),
    );
  }
}

/// Dialog para adicionar um item ao template: busca no estoque
/// (`searchInventory`) OU item avulso (nome/preço livres). Espelha o picker da
/// OS. Devolve um [OsTemplateItemDraft] via Navigator.pop.
class _TemplateItemDialog extends ConsumerStatefulWidget {
  const _TemplateItemDialog();

  static Future<OsTemplateItemDraft?> show(BuildContext context) {
    return showDialog<OsTemplateItemDraft>(
      context: context,
      builder: (_) => const _TemplateItemDialog(),
    );
  }

  @override
  ConsumerState<_TemplateItemDialog> createState() =>
      _TemplateItemDialogState();
}

class _TemplateItemDialogState extends ConsumerState<_TemplateItemDialog> {
  bool _avulso = false;
  InventoryOption? _picked;
  final _name = TextEditingController();
  String _kind = 'product';
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  double? _toDouble(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _pickInventory(InventoryOption o) {
    setState(() {
      _picked = o;
      _kind = o.kind;
      if (_unitPrice.text.trim().isEmpty && o.salePrice != null) {
        _unitPrice.text = (double.tryParse(o.salePrice!) ?? 0)
            .toString()
            .replaceAll('.', ',');
      }
    });
  }

  void _confirm() {
    final draft = _avulso
        ? OsTemplateItemDraft(
            kind: _kind,
            name: _name.text.trim(),
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
          )
        : OsTemplateItemDraft(
            kind: _kind,
            inventoryItemId: _picked!.id,
            name: _picked!.name,
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
          );
    Navigator.of(context).pop(draft);
  }

  bool get _canConfirm =>
      _avulso ? _name.text.trim().isNotEmpty : _picked != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar item'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Do estoque'),
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Avulso'),
                    icon: Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
                selected: {_avulso},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    setState(() => _avulso = sel.first),
              ),
              const SizedBox(height: 16),
              if (_avulso) ..._avulsoFields() else ..._inventoryFields(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço unit.',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }

  List<Widget> _inventoryFields() {
    return [
      Autocomplete<InventoryOption>(
        displayStringForOption: (o) => o.name,
        optionsBuilder: (value) async {
          try {
            return await ref
                .read(osRepositoryProvider)
                .searchInventory(value.text);
          } on AppException {
            return const <InventoryOption>[];
          }
        },
        onSelected: _pickInventory,
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: 'Produto ou serviço do estoque',
              prefixIcon: Icon(Icons.search),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 240, maxWidth: 412),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          o.kind == 'service'
                              ? Icons.design_services_outlined
                              : Icons.inventory_2_outlined,
                          size: 20,
                        ),
                        title: Text(o.name),
                        subtitle: Text(money(o.salePrice)),
                        onTap: () => onSelected(o),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      if (_picked != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(
              _picked!.kind == 'service'
                  ? Icons.design_services_outlined
                  : Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text(_picked!.name),
          ),
        ),
      ],
    ];
  }

  List<Widget> _avulsoFields() {
    return [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'product', label: Text('Produto')),
          ButtonSegment(value: 'service', label: Text('Serviço')),
        ],
        selected: {_kind},
        showSelectedIcon: false,
        onSelectionChanged: (sel) => setState(() => _kind = sel.first),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Descrição *',
          prefixIcon: Icon(Icons.label_outline),
        ),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }
}
