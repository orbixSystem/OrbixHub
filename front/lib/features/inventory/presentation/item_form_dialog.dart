import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../domain/inventory_models.dart';
import 'barcode_scanner_dialog.dart';
import 'inventory_providers.dart';

/// Converte "12,34" / "12.34" em double. Null quando vazio/ inválido.
double? _toDouble(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Converte texto em int (duração em minutos). Null quando vazio/inválido.
int? _toInt(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

/// Dialog de cadastro/edição de item (produto ou serviço).
///
/// Topo: aba Produto | Serviço (travada na edição — `kind` não muda). Produto
/// traz o bloco **código-first** (só na criação), os campos do núcleo
/// (manufacturerCode/barcode) e os campos dinâmicos da vertical (`itemFields`).
/// Serviço é um item sem estoque (sem código-first/códigos/estoque) com Duração.
/// Na edição, barcode e cód. do fabricante ficam travados (identificam o item).
/// UI fala só com o repository (via providers).
class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({super.key, this.existing, this.initialName});

  final InventoryItem? existing;

  /// Nome já digitado antes de abrir (a busca da venda não achou o produto).
  /// Ignorado na edição — lá o nome vem do cadastro.
  final String? initialName;

  /// Devolve o item **salvo**, ou `null` se desistiu — assim quem abriu (a
  /// venda) já sai com o produto novo em mãos, sem uma segunda busca.
  static Future<InventoryItem?> show(
    BuildContext context, {
    InventoryItem? existing,
    String? initialName,
  }) {
    return showDialog<InventoryItem>(
      context: context,
      builder: (_) => ItemFormDialog(existing: existing, initialName: initialName),
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
  late final TextEditingController _salePrice;
  late final TextEditingController _costPrice;
  late final TextEditingController _marginPct;
  late final TextEditingController _minStock;
  late final TextEditingController _currentStock;
  late final TextEditingController _durationMinutes;

  /// Fiscal — produto (NCM/CFOP/origem/GTIN).
  late final TextEditingController _ncm;
  late final TextEditingController _cfop;
  late final TextEditingController _origem;
  late final TextEditingController _gtin;

  /// Fiscal — serviço (código LC116/alíquota ISS).
  late final TextEditingController _codigoServico;
  late final TextEditingController _aliquotaIss;

  /// Bloco código-first.
  final _lookupCode = TextEditingController();

  /// Controllers dos campos da vertical, por chave.
  final Map<String, TextEditingController> _dynamic = {};

  /// Chaves dos campos preenchidos pelo catálogo/item — destacados na UI.
  /// Limpa a chave assim que o usuário edita o campo correspondente.
  final Set<String> _autoFilled = {};

  late String _kind;
  bool _saving = false;
  bool _lookingUp = false;
  bool _suggestingSku = false;
  bool _calculatingPrice = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final it = widget.existing;
    _kind = it?.kind ?? 'product';
    _durationMinutes =
        TextEditingController(text: it?.durationMinutes?.toString() ?? '');
    _manufacturerCode = TextEditingController(text: it?.manufacturerCode ?? '');
    _barcode = TextEditingController(text: it?.barcode ?? '');
    _name = TextEditingController(text: it?.name ?? widget.initialName ?? '');
    _sku = TextEditingController(text: it?.sku ?? '');
    _category = TextEditingController(text: it?.category ?? '');
    _brand = TextEditingController(text: it?.brand ?? '');
    _salePrice = TextEditingController(text: _fmt(it?.salePrice));
    _costPrice = TextEditingController(text: _fmt(it?.costPrice));
    _marginPct = TextEditingController(text: _fmt(it?.marginPct));
    _minStock = TextEditingController(text: _fmt(it?.minStock));
    _currentStock = TextEditingController(text: _fmt(it?.currentStock));
    _ncm = TextEditingController(text: it?.ncm ?? '');
    _cfop = TextEditingController(text: it?.cfop ?? '');
    _origem = TextEditingController(text: it?.origem ?? '');
    _gtin = TextEditingController(text: it?.gtin ?? '');
    _codigoServico = TextEditingController(text: it?.codigoServico ?? '');
    _aliquotaIss = TextEditingController(text: _fmt(it?.aliquotaIss));

    _salePrice.addListener(_onPriceChanged);
    _costPrice.addListener(_onPriceChanged);
    _marginPct.addListener(_onMarginChanged);
  }

  /// Recalcula margem quando preço de venda ou custo mudam.
  void _onPriceChanged() {
    if (_calculatingPrice) return;
    final sale = _toDouble(_salePrice.text);
    final cost = _toDouble(_costPrice.text);
    if (sale == null || cost == null || cost == 0) return;
    final margin = ((sale - cost) / cost) * 100;
    _calculatingPrice = true;
    _marginPct.text = margin.toStringAsFixed(2).replaceAll('.', ',');
    _calculatingPrice = false;
  }

  /// Recalcula preço de venda quando margem + custo estão preenchidos.
  void _onMarginChanged() {
    if (_calculatingPrice) return;
    final cost = _toDouble(_costPrice.text);
    final margin = _toDouble(_marginPct.text);
    if (cost == null || margin == null) return;
    final sale = cost * (1 + margin / 100);
    _calculatingPrice = true;
    _salePrice.text = sale.toStringAsFixed(2).replaceAll('.', ',');
    _calculatingPrice = false;
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
    _salePrice.removeListener(_onPriceChanged);
    _costPrice.removeListener(_onPriceChanged);
    _marginPct.removeListener(_onMarginChanged);
    for (final c in [
      _manufacturerCode,
      _barcode,
      _name,
      _sku,
      _category,
      _brand,
      _salePrice,
      _costPrice,
      _marginPct,
      _minStock,
      _currentStock,
      _durationMinutes,
      _ncm,
      _cfop,
      _origem,
      _gtin,
      _codigoServico,
      _aliquotaIss,
      _lookupCode,
      ..._dynamic.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    showNeuErrorSnackBar(context, msg);
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
            await _autoSuggestSku();
            _snack('Já existe um item com este código: ${item.name}');
          }
        case 'catalog':
          final s = res.suggestion;
          if (s != null) {
            _name.text = s.name;
            _autoFilled.add('name');
            if (s.brand != null) {
              _brand.text = s.brand!;
              _autoFilled.add('brand');
            }
            if (s.category != null) {
              _category.text = s.category!;
              _autoFilled.add('category');
            }
            _placeCode(code);
            await _autoSuggestSku();
            _snack('Campos preenchidos pelo catálogo (revise antes de salvar)');
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

  /// Abre a câmera, detecta o código e dispara o lookup automaticamente.
  Future<void> _scan() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const BarcodeScannerDialog(),
    );
    if (code == null || code.isEmpty) return;
    _lookupCode.text = code;
    await _lookup();
  }

  /// Botão "Sugerir": pede um SKU ao repository a partir do nome. Ação do
  /// usuário — NÃO marca como auto-preenchido (sem destaque tangerina).
  Future<void> _suggestSku() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Informe o nome antes de sugerir um SKU');
      return;
    }
    setState(() => _suggestingSku = true);
    try {
      final sku = await ref.read(inventoryRepositoryProvider).suggestSku(name);
      _sku.text = sku;
      _onEdit('sku');
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _suggestingSku = false);
    }
  }

  /// Após o código-first preencher o nome, sugere o SKU se ainda estiver vazio.
  /// Resiliente: falha silenciosa (não quebra o fluxo de lookup).
  Future<void> _autoSuggestSku() async {
    final name = _name.text.trim();
    if (name.isEmpty || _sku.text.trim().isNotEmpty) return;
    try {
      final sku = await ref.read(inventoryRepositoryProvider).suggestSku(name);
      if (_sku.text.trim().isEmpty) {
        _sku.text = sku;
        _autoFilled.add('sku');
      }
    } on AppException {
      // segue sem sugestão
    }
  }

  /// Coloca o código digitado em `barcode` (8..14 dígitos) ou `manufacturerCode`.
  void _placeCode(String code) {
    final isEan = RegExp(r'^\d{8,14}$').hasMatch(code);
    if (isEan) {
      _barcode.text = code;
      _autoFilled.add('barcode');
    } else {
      _manufacturerCode.text = code;
      _autoFilled.add('manufacturerCode');
    }
  }

  void _prefillFromItem(InventoryItem it) {
    _manufacturerCode.text = it.manufacturerCode ?? '';
    _barcode.text = it.barcode ?? '';
    _name.text = it.name;
    _sku.text = it.sku ?? '';
    _category.text = it.category ?? '';
    _brand.text = it.brand ?? '';
    _autoFilled.addAll(const ['name', 'brand', 'category', 'barcode',
        'manufacturerCode']);
    _salePrice.text = _fmt(it.salePrice);
    _costPrice.text = _fmt(it.costPrice);
    _marginPct.text = _fmt(it.marginPct);
    _minStock.text = _fmt(it.minStock);
    _currentStock.text = _fmt(it.currentStock);
    _ncm.text = it.ncm ?? '';
    _cfop.text = it.cfop ?? '';
    _origem.text = it.origem ?? '';
    _gtin.text = it.gtin ?? '';
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
    final isService = _kind == 'service';
    final draft = ItemDraft(
      name: _name.text.trim(),
      kind: _kind,
      durationMinutes: isService ? _toInt(_durationMinutes.text) : null,
      sku: _opt(_sku.text),
      // Para serviço não enviamos códigos/estoque (item sem estoque).
      manufacturerCode: isService ? null : _opt(_manufacturerCode.text),
      barcode: isService ? null : _opt(_barcode.text),
      category: _opt(_category.text),
      brand: _opt(_brand.text),
      salePrice: _toDouble(_salePrice.text),
      costPrice: _toDouble(_costPrice.text),
      marginPct: _toDouble(_marginPct.text),
      minStock: isService ? null : _toDouble(_minStock.text),
      currentStock: isService ? null : _toDouble(_currentStock.text),
      attributes: attributes.isEmpty ? null : attributes,
      ncm: isService ? null : _opt(_ncm.text),
      cfop: isService ? null : _opt(_cfop.text),
      origem: isService ? null : _opt(_origem.text),
      gtin: isService ? null : _opt(_gtin.text),
      codigoServico: isService ? _opt(_codigoServico.text) : null,
      aliquotaIss: isService ? _toDouble(_aliquotaIss.text) : null,
    );
    try {
      final salvo = widget.existing == null
          ? await repo.createItem(draft)
          : await repo.updateItem(widget.existing!.id, draft);
      ref.invalidate(itemListProvider);
      if (mounted) Navigator.of(context).pop(salvo);
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

    return NeuDialog(
      title: editing ? 'Editar item' : 'Novo item',
      maxWidth: context.isMobile ? 560 : 480,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : () => _save(fields),
        ),
      ],
      child: Form(
        key: _formKey,
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
                  ..._serviceForm(fields, editing)
                else
                  ..._productForm(fields, editing,
                      offline: ref.watch(isOfflineProvider)),
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
    );
  }

  List<Widget> _productForm(
    List<ItemFieldConfig> fields,
    bool editing, {
    bool offline = false,
  }) {
    return [
      // Código-first é um helper de criação — escondido na edição. Offline, a
      // consulta ao catálogo externo (EAN) não existe: botão desabilitado.
      if (!editing) ...[
        _CodeFirstCard(
          controller: _lookupCode,
          loading: _lookingUp,
          offline: offline,
          onSubmit: (_lookingUp || offline) ? null : _lookup,
          onScan: (_lookingUp || offline) ? null : _scan,
        ),
        const SizedBox(height: 16),
      ],
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _manufacturerCode,
              label: 'Cód. do fabricante (opcional)',
              fieldKey: 'manufacturerCode',
              prefixIcon: Icons.precision_manufacturing_outlined,
              locked: editing,
              maxLength: 60,
              onChanged: editing ? null : (_) => _onEdit('manufacturerCode'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _barcode,
              label: 'Código de barras (opcional)',
              fieldKey: 'barcode',
              prefixIcon: Icons.qr_code_2,
              locked: editing,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(14)],
              onChanged: editing ? null : (_) => _onEdit('barcode'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        controller: _name,
        label: 'Nome *',
        fieldKey: 'name',
        prefixIcon: Icons.label_outline,
        maxLength: 120,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _onEdit('name'),
        validator: Validators.required('Nome'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _category,
              label: 'Categoria (opcional)',
              fieldKey: 'category',
              prefixIcon: Icons.category_outlined,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _onEdit('category'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _brand,
              label: 'Marca (opcional)',
              fieldKey: 'brand',
              prefixIcon: Icons.business_outlined,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _onEdit('brand'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        controller: _sku,
        label: 'SKU (opcional)',
        fieldKey: 'sku',
        prefixIcon: Icons.tag,
        maxLength: 40,
        onChanged: (_) => _onEdit('sku'),
        suffix: IconButton(
          tooltip: 'Sugerir SKU',
          icon: _suggestingSku
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high),
          onPressed: _suggestingSku ? null : _suggestSku,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_salePrice, 'Preço de venda (opcional)', 'R\$ ',
              Icons.sell_outlined,
              validator: Validators.positiveNumber(
                  field: 'Preço de venda', optional: true))),
          const SizedBox(width: 12),
          Expanded(child: _numField(_costPrice, 'Preço de custo (opcional)', 'R\$ ',
              Icons.payments_outlined,
              validator: Validators.positiveNumber(
                  field: 'Preço de custo', optional: true))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_marginPct, 'Margem % (opcional)', null,
              Icons.percent)),
          const SizedBox(width: 12),
          Expanded(child: _numField(_minStock, 'Estoque mínimo (opcional)', null,
              Icons.warning_amber_outlined)),
        ],
      ),
      const SizedBox(height: 12),
      _numField(_currentStock, 'Estoque atual (opcional)', null,
          Icons.inventory_outlined),
      const SizedBox(height: 20),
      _SectionHeader(icon: Icons.receipt_long_outlined, text: 'Fiscal'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _ncm,
              label: 'NCM (opcional)',
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(8)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _cfop,
              label: 'CFOP (opcional)',
              prefixIcon: Icons.swap_horiz,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(4)],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _origem,
              label: 'Origem (opcional)',
              prefixIcon: Icons.public,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(1)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _gtin,
              label: 'GTIN (opcional)',
              prefixIcon: Icons.qr_code,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(14)],
            ),
          ),
        ],
      ),
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

  /// Formulário de Serviço: item sem estoque (sem código-first, códigos,
  /// estoque atual/mínimo). Foca em nome, preços, duração e classificação.
  List<Widget> _serviceForm(List<ItemFieldConfig> fields, bool editing) {
    return [
      _field(
        controller: _name,
        label: 'Nome *',
        fieldKey: 'name',
        prefixIcon: Icons.label_outline,
        maxLength: 120,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => _onEdit('name'),
        validator: Validators.required('Nome'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_salePrice, 'Preço de venda (opcional)', 'R\$ ',
              Icons.sell_outlined,
              validator: Validators.positiveNumber(
                  field: 'Preço de venda', optional: true))),
          const SizedBox(width: 12),
          Expanded(child: _numField(_costPrice, 'Preço de custo (opcional)', 'R\$ ',
              Icons.payments_outlined,
              validator: Validators.positiveNumber(
                  field: 'Preço de custo', optional: true))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _numField(_marginPct, 'Margem % (opcional)', null,
              Icons.percent)),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _durationMinutes,
              label: 'Duração (min) (opcional)',
              prefixIcon: Icons.schedule_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(4)],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _category,
              label: 'Categoria (opcional)',
              fieldKey: 'category',
              prefixIcon: Icons.category_outlined,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _onEdit('category'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              controller: _brand,
              label: 'Marca (opcional)',
              fieldKey: 'brand',
              prefixIcon: Icons.business_outlined,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _onEdit('brand'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        controller: _sku,
        label: 'SKU (opcional)',
        fieldKey: 'sku',
        prefixIcon: Icons.tag,
        maxLength: 40,
        onChanged: (_) => _onEdit('sku'),
        suffix: IconButton(
          tooltip: 'Sugerir SKU',
          icon: _suggestingSku
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high),
          onPressed: _suggestingSku ? null : _suggestSku,
        ),
      ),
      const SizedBox(height: 20),
      _SectionHeader(icon: Icons.receipt_long_outlined, text: 'Fiscal'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _field(
              controller: _codigoServico,
              label: 'Código do serviço (LC116) (opcional)',
              prefixIcon: Icons.assignment_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _numField(_aliquotaIss, 'Alíquota ISS % (opcional)', null,
              Icons.percent)),
        ],
      ),
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

  /// Campo de texto do design system (rótulo SEMPRE acima), aplicando o
  /// destaque de autofill quando [fieldKey] estiver em [_autoFilled] e a trava
  /// visual quando [locked] (campo que identifica o item, não editável).
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? fieldKey,
    IconData? prefixIcon,
    Widget? suffix,
    String? hint,
    String? helper,
    bool locked = false,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    // Campo travado na edição (identifica o item): desabilitado + cadeado.
    if (locked) {
      return NeuTextField(
        label: label,
        controller: controller,
        prefixIcon: prefixIcon,
        enabled: false,
        suffix: const Icon(Icons.lock_outline, size: 18),
        helper: 'Não editável',
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      );
    }
    final highlighted = fieldKey != null && _autoFilled.contains(fieldKey);
    return NeuTextField(
      label: label,
      controller: controller,
      hint: hint,
      // Destaque do catálogo: ícone + helper sinalizam (o campo já é inset).
      helper: highlighted ? 'Preenchido pelo catálogo' : helper,
      suffix: highlighted ? null : suffix,
      prefixIcon: prefixIcon,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
    );
  }

  /// Limpa o destaque de [key] quando o usuário edita o campo.
  void _onEdit(String key) {
    if (_autoFilled.contains(key)) {
      setState(() => _autoFilled.remove(key));
    }
  }

  Widget _numField(
    TextEditingController c,
    String label,
    String? prefixText,
    IconData icon, {
    String? Function(String?)? validator,
  }) {
    return NeuTextField(
      label: label,
      controller: c,
      // O NeuTextField não tem prefixText; o "R$" vira dica dentro do campo.
      hint: prefixText != null ? 'R\$ 0,00' : null,
      prefixIcon: icon,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      validator: validator,
    );
  }

  /// Rótulo acima do campo, no mesmo estilo do [NeuTextField] — para envolver
  /// widgets que não são NeuTextField (ex.: dropdowns) sem truncar o rótulo.
  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: context.neu.inkMuted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _dynamicField(ItemFieldConfig f) {
    final label = '${f.label}${f.isRequired ? ' *' : ' (opcional)'}';
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
        // Rótulo acima (nunca trunca) + dropdown numa cavidade do tema.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(label),
            NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              child: DropdownButtonFormField<String>(
                key: Key('itemField-${f.key}'),
                initialValue: current,
                isExpanded: true,
                style: TextStyle(color: context.neu.ink, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: [
                  for (final o in options)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (v) => controller.text = v ?? '',
                validator: (v) => requiredValidator(v),
              ),
            ),
          ],
        );
      case 'tags':
        return NeuTextField(
          key: Key('itemField-${f.key}'),
          label: label,
          controller: _dynamic[f.key],
          helper: 'Separe por vírgula',
          validator: requiredValidator,
        );
      case 'number':
        return NeuTextField(
          key: Key('itemField-${f.key}'),
          label: label,
          controller: _dynamic[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validator: requiredValidator,
        );
      default:
        return NeuTextField(
          key: Key('itemField-${f.key}'),
          label: label,
          controller: _dynamic[f.key],
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
    this.onScan,
    this.offline = false,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback? onSubmit;

  /// Abre a câmera para escanear um código de barras.
  final VoidCallback? onScan;

  /// Sem internet: a consulta automática por código de barras (catálogo
  /// externo) não responde — o usuário preenche à mão.
  final bool offline;

  /// Só embrulha em [Tooltip] quando HÁ mensagem — um Tooltip de mensagem vazia
  /// mostra um balão em branco no hover/toque longo.
  Widget _maybeTooltip(Widget child) {
    if (!offline) return child;
    return Tooltip(message: kRequiresConnectionTooltip, child: child);
  }

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
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            enabled: !offline,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Código de barras ou do fabricante',
              prefixIcon: const Icon(Icons.qr_code_scanner),
              suffixIcon: _maybeTooltip(
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Escanear com câmera',
                  onPressed: onScan,
                ),
              ),
            ),
            onSubmitted: (_) => onSubmit?.call(),
          ),
          if (offline) ...[
            const SizedBox(height: 8),
            const OfflinePendingNoticeBody(
              dense: true,
              message: 'Você está offline — a consulta automática por código '
                  'de barras não está disponível. Preencha os dados '
                  'manualmente.',
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _maybeTooltip(
              FilledButton.icon(
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
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
