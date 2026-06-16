import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';

/// Converte "R$ 12,34" / "12.34" / "12,34" em centavos. Null quando vazio.
int? _reaisToCents(String raw) {
  final t = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  final normalized = t.replaceAll('.', '').replaceAll(',', '.');
  final v = double.tryParse(t.contains(',') ? normalized : t);
  if (v == null) return null;
  return (v * 100).round();
}

String _centsToReais(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

double? _toDouble(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Dialog de criar/editar item. Tipo (produto/serviço) é imutável na edição.
/// Produto mostra estoque/custo/margem/código de barras; serviço mostra duração.
/// UI fala só com o repository (via providers).
class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({super.key, this.existing});

  final InventoryItem? existing;

  static Future<bool?> show(BuildContext context, {InventoryItem? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ItemFormDialog(existing: existing),
    );
  }

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _category;
  late final TextEditingController _unit;
  late final TextEditingController _salePrice;
  late final TextEditingController _barcode;
  late final TextEditingController _costPrice;
  late final TextEditingController _margin;
  late final TextEditingController _minQty;
  late final TextEditingController _brand;
  late final TextEditingController _duration;

  String _kind = 'product';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final it = widget.existing;
    _kind = it?.kind ?? 'product';
    _name = TextEditingController(text: it?.name ?? '');
    _code = TextEditingController(text: it?.code ?? '');
    _category = TextEditingController(text: it?.category ?? '');
    _unit = TextEditingController(text: it?.unit ?? '');
    _salePrice = TextEditingController(
        text: it != null ? _centsToReais(it.salePriceCents) : '');
    _barcode = TextEditingController(text: it?.barcode ?? '');
    _costPrice = TextEditingController(
        text: it?.costPriceCents != null
            ? _centsToReais(it!.costPriceCents!)
            : '');
    _margin = TextEditingController(text: it?.marginPercent ?? '');
    _minQty = TextEditingController(text: it?.minQty ?? '');
    _brand = TextEditingController(text: it?.brand ?? '');
    _duration = TextEditingController(
        text: it?.durationMinutes != null ? '${it!.durationMinutes}' : '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _category,
      _unit,
      _salePrice,
      _barcode,
      _costPrice,
      _margin,
      _minQty,
      _brand,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sugere o preço de venda a partir de custo + margem (só se ambos válidos).
  void _suggestSalePrice() {
    final cost = _reaisToCents(_costPrice.text);
    final margin = _toDouble(_margin.text);
    if (cost == null || margin == null) return;
    final suggested = (cost * (1 + margin / 100)).round();
    _salePrice.text = _centsToReais(suggested);
    setState(() {});
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final isService = _kind == 'service';
    final repo = ref.read(inventoryRepositoryProvider);
    final unit = _unit.text.trim().isEmpty
        ? (ref.read(inventoryConfigProvider).value?.defaultUnit ?? 'un')
        : _unit.text.trim();
    final draft = ItemDraft(
      kind: _kind,
      name: _name.text.trim(),
      unit: unit,
      code: _opt(_code.text),
      category: _opt(_category.text),
      salePriceCents: _reaisToCents(_salePrice.text),
      barcode: isService ? null : _opt(_barcode.text),
      costPriceCents: isService ? null : _reaisToCents(_costPrice.text),
      marginPercent: isService ? null : _toDouble(_margin.text),
      minQty: isService ? null : _toDouble(_minQty.text),
      brand: isService ? null : _opt(_brand.text),
      durationMinutes:
          isService ? int.tryParse(_duration.text.trim()) : null,
    );
    try {
      if (widget.existing == null) {
        await repo.createItem(draft);
      } else {
        await repo.updateItem(widget.existing!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final isService = _kind == 'service';
    final config = ref.watch(inventoryConfigProvider).value;
    final unitHint = config?.defaultUnit ?? 'un';

    return AlertDialog(
      title: Text(editing ? 'Editar item' : 'Novo item'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'product',
                      label: Text('Produto'),
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 'service',
                      label: Text('Serviço'),
                      icon: Icon(Icons.design_services_outlined, size: 18),
                    ),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: editing
                      ? null
                      : (sel) => setState(() => _kind = sel.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: InputDecoration(
                          labelText: 'Unidade',
                          hintText: unitHint,
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salePrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Preço de venda',
                          prefixText: 'R\$ ',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isService) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: Icons.inventory_2_outlined,
                    text: 'Produto',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _barcode,
                    decoration: const InputDecoration(
                      labelText: 'Código de barras',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Preço de custo',
                            prefixText: 'R\$ ',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) => _suggestSalePrice(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _margin,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Margem %',
                            prefixIcon: Icon(Icons.percent),
                          ),
                          onChanged: (_) => _suggestSalePrice(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minQty,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Estoque mínimo',
                            prefixIcon: Icon(Icons.warning_amber_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _brand,
                          decoration: const InputDecoration(
                            labelText: 'Marca',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isService) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: Icons.design_services_outlined,
                    text: 'Serviço',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duração (minutos)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
