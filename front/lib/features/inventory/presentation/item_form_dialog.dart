import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';

/// Converte "12,34" / "12.34" em double. Null quando vazio/ inválido.
double? _toDouble(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Dialog de cadastro/edição de produto.
///
/// Topo: aba Produto | Serviço. Serviço é placeholder ("módulo 3 — em breve") e
/// desabilita o salvar. Produto traz o bloco **código-first** em destaque, os
/// campos do núcleo (manufacturerCode/barcode primeiro) e os campos dinâmicos
/// da vertical (`itemFields`). UI fala só com o repository (via providers).
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
  late final TextEditingController _manufacturerCode;
  late final TextEditingController _barcode;
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _category;
  late final TextEditingController _brand;
  late final TextEditingController _unit;
  late final TextEditingController _salePrice;
  late final TextEditingController _costPrice;
  late final TextEditingController _marginPct;
  late final TextEditingController _minStock;
  late final TextEditingController _currentStock;

  /// Bloco código-first.
  final _lookupCode = TextEditingController();

  /// Controllers dos campos da vertical, por chave.
  final Map<String, TextEditingController> _dynamic = {};

  String _kind = 'product';
  bool _saving = false;
  bool _lookingUp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final it = widget.existing;
    _manufacturerCode = TextEditingController(text: it?.manufacturerCode ?? '');
    _barcode = TextEditingController(text: it?.barcode ?? '');
    _name = TextEditingController(text: it?.name ?? '');
    _sku = TextEditingController(text: it?.sku ?? '');
    _category = TextEditingController(text: it?.category ?? '');
    _brand = TextEditingController(text: it?.brand ?? '');
    _unit = TextEditingController(text: it?.unit ?? '');
    _salePrice = TextEditingController(text: _fmt(it?.salePrice));
    _costPrice = TextEditingController(text: _fmt(it?.costPrice));
    _marginPct = TextEditingController(text: _fmt(it?.marginPct));
    _minStock = TextEditingController(text: _fmt(it?.minStock));
    _currentStock = TextEditingController(text: _fmt(it?.currentStock));
  }

  String _fmt(String? decimal) {
    if (decimal == null || decimal.isEmpty) return '';
    final v = double.tryParse(decimal);
    if (v == null) return decimal;
    return v.toString().replaceAll('.', ',');
  }

  void _ensureDynamicControllers(List<ItemFieldConfig> fields) {
    final attrs = widget.existing?.attributes ?? const <String, dynamic>{};
    for (final f in fields) {
      _dynamic.putIfAbsent(f.key, () {
        final v = attrs[f.key];
        if (v is List) {
          return TextEditingController(text: v.join(', '));
        }
        return TextEditingController(text: v?.toString() ?? '');
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _manufacturerCode,
      _barcode,
      _name,
      _sku,
      _category,
      _brand,
      _unit,
      _salePrice,
      _costPrice,
      _marginPct,
      _minStock,
      _currentStock,
      _lookupCode,
      ..._dynamic.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _lookup() async {
    final code = _lookupCode.text.trim();
    if (code.isEmpty) return;
    setState(() => _lookingUp = true);
    try {
      final res = await ref.read(inventoryRepositoryProvider).lookup(code);
      switch (res.source) {
        case 'internal':
          final item = res.item;
          if (item != null) {
            _prefillFromItem(item);
            _snack('Já existe um item com este código: ${item.name}');
          }
        case 'catalog':
          final s = res.suggestion;
          if (s != null) {
            _name.text = s.name;
            if (s.brand != null) _brand.text = s.brand!;
            if (s.category != null) _category.text = s.category!;
            _placeCode(code);
            _snack('Sugestão aplicada do catálogo');
          }
        default:
          _placeCode(code);
          _snack('Nada encontrado — preencha manualmente');
      }
      setState(() {});
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  /// Coloca o código digitado em `barcode` (8..14 dígitos) ou `manufacturerCode`.
  void _placeCode(String code) {
    final isEan = RegExp(r'^\d{8,14}$').hasMatch(code);
    if (isEan) {
      _barcode.text = code;
    } else {
      _manufacturerCode.text = code;
    }
  }

  void _prefillFromItem(InventoryItem it) {
    _manufacturerCode.text = it.manufacturerCode ?? '';
    _barcode.text = it.barcode ?? '';
    _name.text = it.name;
    _sku.text = it.sku ?? '';
    _category.text = it.category ?? '';
    _brand.text = it.brand ?? '';
    _unit.text = it.unit ?? '';
    _salePrice.text = _fmt(it.salePrice);
    _costPrice.text = _fmt(it.costPrice);
    _marginPct.text = _fmt(it.marginPct);
    _minStock.text = _fmt(it.minStock);
    _currentStock.text = _fmt(it.currentStock);
    for (final entry in _dynamic.entries) {
      final v = it.attributes[entry.key];
      entry.value.text = v is List ? v.join(', ') : (v?.toString() ?? '');
    }
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  /// Monta `attributes` a partir dos campos dinâmicos (só não-vazios).
  Map<String, dynamic> _collectAttributes(List<ItemFieldConfig> fields) {
    final out = <String, dynamic>{};
    for (final f in fields) {
      final raw = _dynamic[f.key]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      switch (f.type) {
        case 'number':
          out[f.key] = num.tryParse(raw.replaceAll(',', '.')) ?? raw;
        case 'tags':
          out[f.key] = raw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        default:
          out[f.key] = raw;
      }
    }
    return out;
  }

  Future<void> _save(List<ItemFieldConfig> fields) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(inventoryRepositoryProvider);
    final attributes = _collectAttributes(fields);
    final draft = ItemDraft(
      name: _name.text.trim(),
      sku: _opt(_sku.text),
      manufacturerCode: _opt(_manufacturerCode.text),
      barcode: _opt(_barcode.text),
      category: _opt(_category.text),
      brand: _opt(_brand.text),
      unit: _opt(_unit.text),
      salePrice: _toDouble(_salePrice.text),
      costPrice: _toDouble(_costPrice.text),
      marginPct: _toDouble(_marginPct.text),
      minStock: _toDouble(_minStock.text),
      currentStock: _toDouble(_currentStock.text),
      attributes: attributes.isEmpty ? null : attributes,
    );
    try {
      if (widget.existing == null) {
        await repo.createItem(draft);
      } else {
        await repo.updateItem(widget.existing!.id, draft);
      }
      ref.invalidate(itemListProvider);
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
    final fields = ref.watch(inventoryConfigProvider).value?.itemFields ??
        const <ItemFieldConfig>[];
    _ensureDynamicControllers(fields);

    return AlertDialog(
      title: Text(editing ? 'Editar item' : 'Novo item'),
      content: SizedBox(
        width: 480,
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
                if (isService)
                  _ServicePlaceholder()
                else
                  ..._productForm(fields),
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
          onPressed: (_saving || isService) ? null : () => _save(fields),
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

  List<Widget> _productForm(List<ItemFieldConfig> fields) {
    return [
      _CodeFirstCard(
        controller: _lookupCode,
        loading: _lookingUp,
        onSubmit: _lookingUp ? null : _lookup,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _manufacturerCode,
              decoration: const InputDecoration(
                labelText: 'Cód. do fabricante',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'Código de barras',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
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
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(Icons.category_outlined),
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
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unidade',
                hintText: 'un',
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _sku,
              decoration: const InputDecoration(
                labelText: 'SKU',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_salePrice, 'Preço de venda', 'R\$ ',
              Icons.sell_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _numField(_costPrice, 'Preço de custo', 'R\$ ',
              Icons.payments_outlined)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_marginPct, 'Margem %', null,
              Icons.percent)),
          const SizedBox(width: 12),
          Expanded(child: _numField(_minStock, 'Estoque mínimo', null,
              Icons.warning_amber_outlined)),
        ],
      ),
      const SizedBox(height: 12),
      _numField(_currentStock, 'Estoque atual', null,
          Icons.inventory_outlined),
      if (fields.isNotEmpty) ...[
        const SizedBox(height: 20),
        _SectionHeader(icon: Icons.tune, text: 'Detalhes do item'),
        const SizedBox(height: 8),
        for (final f in fields) ...[
          _dynamicField(f),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  Widget _numField(
    TextEditingController c,
    String label,
    String? prefixText,
    IconData icon,
  ) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _dynamicField(ItemFieldConfig f) {
    final label = '${f.label}${f.isRequired ? ' *' : ''}';
    String? requiredValidator(String? v) {
      if (f.isRequired && (v == null || v.trim().isEmpty)) {
        return '${f.label} é obrigatório';
      }
      return null;
    }

    switch (f.type) {
      case 'select':
        final options = f.options ?? const <String>[];
        final controller = _dynamic[f.key]!;
        final current =
            options.contains(controller.text) ? controller.text : null;
        return DropdownButtonFormField<String>(
          key: Key('itemField-${f.key}'),
          initialValue: current,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => controller.text = v ?? '',
          validator: (v) => requiredValidator(v),
        );
      case 'tags':
        return TextFormField(
          key: Key('itemField-${f.key}'),
          controller: _dynamic[f.key],
          decoration: InputDecoration(
            labelText: label,
            helperText: 'Separe por vírgula',
          ),
          validator: requiredValidator,
        );
      case 'number':
        return TextFormField(
          key: Key('itemField-${f.key}'),
          controller: _dynamic[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: requiredValidator,
        );
      default:
        return TextFormField(
          key: Key('itemField-${f.key}'),
          controller: _dynamic[f.key],
          decoration: InputDecoration(labelText: label),
          validator: requiredValidator,
        );
    }
  }
}

/// Bloco código-first em destaque (Card) no topo do formulário de produto.
class _CodeFirstCard extends StatelessWidget {
  const _CodeFirstCard({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: AppColors.brandDeep),
              const SizedBox(width: 8),
              Text(
                'Começar pelo código',
                style: TextStyle(
                  color: AppColors.brandDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Código de barras ou do fabricante',
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
            onSubmitted: (_) => onSubmit?.call(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: const Text('Buscar e preencher'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder da aba Serviço (módulo 3 — Catálogo de serviços, ainda não existe).
class _ServicePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(Icons.design_services_outlined,
              size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Catálogo de Serviços (módulo 3) — em breve',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
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
