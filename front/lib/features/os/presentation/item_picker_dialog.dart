import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/validators.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Dialog para adicionar um item à OS: busca no estoque (`searchInventory`) OU
/// item avulso (nome/preço livres). Retorna um [OrderItemDraft] via Navigator.pop.
class ItemPickerDialog extends ConsumerStatefulWidget {
  const ItemPickerDialog({super.key});

  static Future<OrderItemDraft?> show(BuildContext context) {
    return showDialog<OrderItemDraft>(
      context: context,
      builder: (_) => const ItemPickerDialog(),
    );
  }

  @override
  ConsumerState<ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends ConsumerState<ItemPickerDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _avulso = false; // false = do estoque, true = item avulso

  // Estoque
  InventoryOption? _picked;

  // Item avulso
  final _name = TextEditingController();
  String _kind = 'product';

  // Comum
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  final _discount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discount.dispose();
    super.dispose();
  }

  double? _toDouble(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Formata o estoque para exibição (sem casas se inteiro; vírgula decimal).
  String _fmtStock(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return raw;
    return v == v.truncate()
        ? v.toInt().toString()
        : v.toString().replaceAll('.', ',');
  }

  void _pickInventory(InventoryOption o) {
    setState(() {
      _picked = o;
      _kind = o.kind;
      if (_unitPrice.text.trim().isEmpty && o.salePrice != null) {
        _unitPrice.text =
            (double.tryParse(o.salePrice!) ?? 0).toString().replaceAll('.', ',');
      }
    });
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final qty = _toDouble(_quantity.text) ?? 1;

    // Aviso de estoque: só para produto vinculado ao estoque (serviço não tem
    // estoque; item avulso não aponta para o catálogo).
    if (!_avulso && _picked != null && _picked!.kind == 'product') {
      final stock = double.tryParse(_picked!.currentStock ?? '');
      if (stock != null && qty > stock) {
        final fmtStock = stock == stock.truncate()
            ? stock.toInt().toString()
            : stock.toString().replaceAll('.', ',');
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Estoque insuficiente'),
            content: Text(
              'Estoque insuficiente: disponível $fmtStock. '
              'Deseja adicionar mesmo assim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Adicionar mesmo assim'),
              ),
            ],
          ),
        );
        if (go != true) return;
      }
    }

    final draft = _avulso
        ? OrderItemDraft(
            kind: _kind,
            name: _name.text.trim(),
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
            discount: _toDouble(_discount.text),
          )
        : OrderItemDraft(
            kind: _kind,
            inventoryItemId: _picked!.id,
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
            discount: _toDouble(_discount.text),
          );
    if (mounted) Navigator.of(context).pop(draft);
  }

  bool get _canConfirm => _avulso
      ? _name.text.trim().isNotEmpty
      : _picked != null;

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
          onPressed: _canConfirm ? () => _confirm() : null,
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
                onSelectionChanged: (sel) => setState(() => _avulso = sel.first),
              ),
              const SizedBox(height: 16),
              if (_avulso) ..._avulsoFields() else ..._inventoryFields(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade *',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator:
                          Validators.positiveNumber(field: 'Quantidade'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPrice,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço unit. *',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      validator: Validators.positiveNumber(field: 'Preço'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Desconto (opcional)',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.discount_outlined),
                ),
                validator:
                    Validators.positiveNumber(optional: true, field: 'Desconto'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _PreviewTotal(
                quantity: _toDouble(_quantity.text),
                unitPrice: _toDouble(_unitPrice.text),
                discount: _toDouble(_discount.text),
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
                        subtitle: Text(
                          o.kind == 'product' && o.currentStock != null
                              ? '${money(o.salePrice)}  ·  '
                                  'estoque: ${_fmtStock(o.currentStock!)}'
                              : money(o.salePrice),
                        ),
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

class _PreviewTotal extends StatelessWidget {
  const _PreviewTotal({
    required this.quantity,
    required this.unitPrice,
    required this.discount,
  });

  final double? quantity;
  final double? unitPrice;
  final double? discount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = (quantity ?? 0) * (unitPrice ?? 0) - (discount ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Subtotal',
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          Text(
            money(total.toString()),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
