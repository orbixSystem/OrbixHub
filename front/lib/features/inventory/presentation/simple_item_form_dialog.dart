import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/vertical/vertical_providers.dart';
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/inventory_models.dart';
import '../domain/stock_status.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';
import 'stock_badge.dart';

/// Cadastro RÁPIDO de produto ou serviço: nome, tipo, marca, modelo (quando o
/// vertical habilita), descrição, preços e estoque — atual e mínimo — (produto)
/// ou sem estoque (serviço).
///
/// Existe porque o cadastro completo (`ItemFormDialog`) tem código de barras,
/// SKU, classificação fiscal e campos da vertical — úteis para quem PRECISA
/// deles, mas ruído para o caso comum. Este diálogo é a PORTA DE ENTRADA;
/// "Cadastro completo" leva para o outro quando for necessário.
///
/// Serve CRIAR e EDITAR com os mesmos campos (`existing`). Antes, criar passava
/// por aqui e editar caía direto no cadastro completo: quem cadastrava um item
/// em quatro campos reencontrava vinte na hora de corrigir o preço. O estoque
/// mínimo, em particular, só existia lá dentro — e é justamente o que faz o
/// aviso de "estoque baixo" funcionar.
class SimpleItemFormDialog extends ConsumerStatefulWidget {
  const SimpleItemFormDialog({super.key, this.initialName, this.existing});

  final String? initialName;

  /// Item sendo editado. Nulo = criação.
  final InventoryItem? existing;

  static Future<InventoryItem?> show(
    BuildContext context, {
    String? initialName,
    InventoryItem? existing,
  }) {
    return showDialog<InventoryItem>(
      context: context,
      builder: (_) =>
          SimpleItemFormDialog(initialName: initialName, existing: existing),
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
  final _minStock = TextEditingController();
  bool _salvando = false;

  bool get _editando => widget.existing != null;

  /// Decimal serializado ("3.000") → texto de campo ("3"). Vazio quando nulo.
  static String _fmt(String? decimal) {
    if (decimal == null || decimal.trim().isEmpty) return '';
    final v = double.tryParse(decimal);
    if (v == null) return decimal;
    return (v == v.truncate() ? v.toInt().toString() : v.toString())
        .replaceAll('.', ',');
  }

  @override
  void initState() {
    super.initState();
    final it = widget.existing;
    if (it != null) {
      _kind = it.kind;
      _name.text = it.name;
      _brand.text = it.brand ?? '';
      _modelo.text = (it.attributes['modelo'] ?? '').toString();
      _description.text = it.description ?? '';
      _salePrice.text = _fmt(it.salePrice);
      _costPrice.text = _fmt(it.costPrice);
      _currentStock.text = _fmt(it.currentStock);
      _minStock.text = _fmt(it.minStock);
    } else {
      _name.text = widget.initialName ?? '';
    }
    _salePrice.addListener(() => setState(() {}));
    _costPrice.addListener(() => setState(() {}));
    _currentStock.addListener(() => setState(() {}));
    _minStock.addListener(() => setState(() {}));
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
    _minStock.dispose();
    super.dispose();
  }

  bool get _isService => _kind == 'service';

  /// Estado que o item VAI ter com o que está digitado — mesma regra da lista,
  /// do caixa e da OS, para o aviso aqui e o selo lá não discordarem.
  StockStatus get _estadoDoEstoque => stockStatusOf(
    kind: _kind,
    currentStock: _currentStock.text.trim().replaceAll(',', '.'),
    minStock: _minStock.text.trim().isEmpty
        ? null
        : _minStock.text.trim().replaceAll(',', '.'),
  );

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
      existing: widget.existing,
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
      minStock: _isService ? null : _num(_minStock),
      attributes: attrs,
    );
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final salvo = _editando
          ? await repo.updateItem(widget.existing!.id, draft)
          : await repo.createItem(draft);
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
      title: _editando
          ? (_isService ? 'Editar serviço' : 'Editar produto')
          : 'Novo produto ou serviço',
      // No celular o diálogo já preenche a tela (o `insetPadding` do NeuDialog
      // é quem limita); 460 era o teto do DESKTOP, e apertava justamente as
      // linhas de dois campos — preço de venda/compra e estoque atual/mínimo —,
      // que ficavam com metade da largura de um campo normal cada.
      maxWidth: context.isMobile ? 560 : 680,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context),
        ),
        NeuButton(
          label: _editando ? 'Salvar alterações' : 'Salvar',
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
              // Trocar produto↔serviço num item que já existe mudaria o que ele
              // significa no histórico (e o backend também não deixa).
              onSelectionChanged: _editando
                  ? null
                  : (sel) => setState(() => _kind = sel.first),
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
            // Atual e mínimo lado a lado: são a mesma decisão ("quanto tenho,
            // a partir de quanto me avise"). O mínimo vivia só no cadastro
            // completo, e por isso quase ninguém preenchia — sem ele o alerta
            // de estoque baixo nunca dispara.
            if (!_isService) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NeuTextField(
                      label: 'Quantidade em estoque',
                      controller: _currentStock,
                      hint: '1',
                      prefixIcon: Icons.inventory_2_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [DecimalInputFormatter(3)],
                      helper: 'Quantas unidades você tem agora.',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeuTextField(
                      label: 'Estoque mínimo',
                      controller: _minStock,
                      hint: 'Opcional',
                      prefixIcon: Icons.warning_amber_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [DecimalInputFormatter(3)],
                      helper: 'Avisa quando chegar aqui.',
                    ),
                  ),
                ],
              ),
              if (_estadoDoEstoque != StockStatus.ok) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    StockBadge(status: _estadoDoEstoque),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _estadoDoEstoque == StockStatus.esgotado
                            ? 'Com saldo zero o produto não entra numa venda.'
                            : 'No mínimo ou abaixo — vai aparecer sinalizado '
                                'na lista e na venda.',
                        style: TextStyle(color: neu.inkMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _salvando ? null : _abrirCompleto,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  _editando
                      ? 'Editar no cadastro completo (código de barras, fiscal…)'
                      : 'Cadastro completo (código de barras, fiscal…)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
