import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/validators.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

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
///
/// Mora em arquivo próprio porque tem DOIS donos: a tela de gestão de templates
/// e o seletor "Aplicar template" (que oferece criar um na hora, como o picker
/// de cliente e o de produto já fazem).
class TemplateFormDialog extends ConsumerStatefulWidget {
  const TemplateFormDialog({super.key, this.template, this.initialName});

  final OsTemplate? template;

  /// Nome já digitado em quem chamou (a busca do seletor) — evita redigitar.
  final String? initialName;

  static Future<OsTemplateDraft?> show(
    BuildContext context,
    WidgetRef ref, {
    OsTemplate? template,
    String? initialName,
  }) {
    return showDialog<OsTemplateDraft>(
      context: context,
      builder: (_) => TemplateFormDialog(
        template: template,
        initialName: initialName,
      ),
    );
  }

  @override
  ConsumerState<TemplateFormDialog> createState() =>
      _TemplateFormDialogState();
}

class _TemplateFormDialogState extends ConsumerState<TemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final List<_DraftRow> _items;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(text: t?.name ?? widget.initialName ?? '');
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
    if (!_formKey.currentState!.validate()) return;
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
    return NeuDialog(
      title: isEdit ? 'Editar template' : 'Novo template',
      maxWidth: context.isMobile ? 560 : 480,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: isEdit ? 'Salvar' : 'Criar',
          icon: Icons.check_rounded,
          onPressed: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  prefixIcon: Icon(Icons.label_outline),
                  counterText: '',
                ),
                validator: Validators.required('Nome'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  counterText: '',
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
  final _formKey = GlobalKey<FormState>();
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
    if (!(_formKey.currentState?.validate() ?? true)) return;
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
    return NeuDialog(
      title: 'Adicionar item',
      maxWidth: context.isMobile ? 560 : 480,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Adicionar',
          icon: Icons.check_rounded,
          onPressed: _canConfirm ? _confirm : null,
        ),
      ],
      child: Form(
        key: _formKey,
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
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade *',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator:
                          Validators.positiveNumber(field: 'Quantidade'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço unit. *',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      validator: Validators.positiveNumber(field: 'Preço'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
      TextFormField(
        controller: _name,
        maxLength: 120,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Descrição *',
          prefixIcon: Icon(Icons.label_outline),
          counterText: '',
        ),
        validator: Validators.required('Descrição'),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }
}
