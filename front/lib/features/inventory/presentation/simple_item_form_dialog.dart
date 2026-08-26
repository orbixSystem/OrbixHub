import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/vertical/vertical_providers.dart';
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';

/// Cadastro RÁPIDO de produto ou serviço: nome, tipo, marca, modelo (quando o
/// vertical habilita), descrição, preços e estoque (produto) ou sem estoque
/// (serviço).
///
/// Existe porque o cadastro completo (`ItemFormDialog`) tem código de barras,
/// SKU, classificação fiscal e campos da vertical — úteis para quem PRECISA
/// deles, mas ruído para o caso comum. Este diálogo é a PORTA DE ENTRADA;
/// "Cadastro completo" leva para o outro quando for necessário.
class SimpleItemFormDialog extends ConsumerStatefulWidget {
  const SimpleItemFormDialog({super.key, this.initialName});

  final String? initialName;

  static Future<InventoryItem?> show(BuildContext context, {String? initialName}) {
    return showDialog<InventoryItem>(
      context: context,
      builder: (_) => SimpleItemFormDialog(initialName: initialName),
    );
  }

  @override
  ConsumerState<SimpleItemFormDialog> createState() =>
      _SimpleItemFormDialogState();
}

class _SimpleItemFormDialogState extends ConsumerState<SimpleItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _kind = 'product';
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _modelo = TextEditingController();
  final _description = TextEditingController();
  final _salePrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _currentStock = TextEditingController(text: '1');
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _salePrice.addListener(() => setState(() {}));
    _costPrice.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _modelo.dispose();
    _description.dispose();
    _salePrice.dispose();
    _costPrice.dispose();
    _currentStock.dispose();
    super.dispose();
  }

  bool get _isService => _kind == 'service';

  double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  ({double lucro, double pct})? get _margem {
    final venda = _num(_salePrice);
    final custo = _num(_costPrice);
    if (venda == null || custo == null || custo <= 0) return null;
    return (lucro: venda - custo, pct: (venda - custo) / custo * 100);
  }

  Future<void> _abrirCompleto() async {
    final salvo = await ItemFormDialog.show(
      context,
      initialName: _name.text.trim().isEmpty ? null : _name.text.trim(),
    );
    if (!mounted || salvo == null) return;
    ref.invalidate(itemListProvider);
    Navigator.pop(context, salvo);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final modeloVal = _modelo.text.trim();
    final attrs = modeloVal.isNotEmpty ? {'modelo': modeloVal} : null;

    final draft = ItemDraft(
      name: _name.text.trim(),
      kind: _kind,
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      salePrice: _num(_salePrice),
      costPrice: _num(_costPrice),
      currentStock: _isService ? null : (_num(_currentStock) ?? 0),
      attributes: attrs,
    );
    try {
      final salvo = await ref.read(inventoryRepositoryProvider).createItem(draft);
      ref.invalidate(itemListProvider);
      if (!mounted) return;
      Navigator.pop(context, salvo);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      showNeuErrorSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final margem = _margem;
    final vocab = ref.watch(vocabProvider);
    final showModelo = vocab['inventory.campos.modelo'] != null;

    return NeuDialog(
      title: 'Novo produto ou serviço',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context),
        ),
        NeuButton(
          label: 'Salvar',
          loading: _salvando,
          onPressed: _salvando ? null : _salvar,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tipo: Produto / Serviço ──────────────────────────────────
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
              onSelectionChanged: (sel) => setState(() => _kind = sel.first),
            ),
            const SizedBox(height: 14),

            // ── Nome ─────────────────────────────────────────────────────
            NeuTextField(
              label: 'Nome *',
              controller: _name,
              hint: vocab['inventory.hint.nome_produto'],
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 14),

            // ── Marca ─────────────────────────────────────────────────────
            NeuTextField(
              label: 'Marca',
              controller: _brand,
              hint: 'Opcional',
              textCapitalization: TextCapitalization.words,
            ),

            // ── Modelo (somente quando o vertical habilita) ──────────────
            if (showModelo) ...[
              const SizedBox(height: 14),
              NeuTextField(
                label: 'Modelo',
                controller: _modelo,
                hint: 'Opcional',
                textCapitalization: TextCapitalization.words,
              ),
            ],

            const SizedBox(height: 14),
            NeuTextField(
              label: 'Descrição',
              controller: _description,
              hint: 'Opcional — detalhe, aplicação, observação…',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),

            // ── Preços ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NeuTextField(
                    label: 'Preço de venda *',
                    controller: _salePrice,
                    hint: '0,00',
                    prefixIcon: Icons.sell_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [DecimalInputFormatter()],
                    validator: (v) {
                      final n = _num(_salePrice);
                      if (n == null || n <= 0) return 'Informe o preço.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeuTextField(
                    label: 'Preço de compra',
                    controller: _costPrice,
                    hint: 'Opcional',
                    prefixIcon: Icons.shopping_cart_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [DecimalInputFormatter()],
                  ),
                ),
              ],
            ),
            if (margem != null) ...[
              const SizedBox(height: 10),
              NeuSurface(
                elevation: NeuElevation.inset,
                radius: NeuTokens.rField,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      margem.lucro >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: margem.lucro >= 0 ? neu.success : neu.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lucro de ${formatMoney(margem.lucro)} por unidade '
                        '(${margem.pct.toStringAsFixed(1).replaceAll('.', ',')}%)',
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Estoque (só produto) ─────────────────────────────────────
            if (!_isService) ...[
              const SizedBox(height: 14),
              NeuTextField(
                label: 'Quantidade em estoque',
                controller: _currentStock,
                hint: '1',
                prefixIcon: Icons.inventory_2_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [DecimalInputFormatter(3)],
                helper: 'Quantas unidades você já tem agora.',
              ),
            ],

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _salvando ? null : _abrirCompleto,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(
                  'Cadastro completo (código de barras, fiscal…)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
