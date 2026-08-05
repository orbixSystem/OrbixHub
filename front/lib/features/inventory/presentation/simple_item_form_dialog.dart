import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';

/// Cadastro RÁPIDO de produto: nome, marca, descrição, preço de venda, preço de
/// compra e quantidade em estoque — nada mais.
///
/// Existe porque o cadastro completo (`ItemFormDialog`) tem código de barras,
/// SKU, classificação fiscal e campos da vertical — úteis para quem PRECISA
/// deles, mas ruído para o caso comum ("cadastrar uma peça rápido"). Muitos
/// desses campos, sem uma consulta funcionando (código de barras), ficavam
/// vazios e no caminho. Este diálogo é a PORTA DE ENTRADA; "Cadastro completo"
/// leva para o outro quando a oficina precisar de algo mais.
///
/// Grava pelos MESMOS `ItemDraft`/`InventoryItem` do cadastro completo — nenhum
/// endpoint novo, e por isso já funciona offline: o repositório (via `di.dart`)
/// já é o decorator `LocalFirstInventoryRepository`, que faz o resto.
class SimpleItemFormDialog extends ConsumerStatefulWidget {
  const SimpleItemFormDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const SimpleItemFormDialog(),
    );
  }

  @override
  ConsumerState<SimpleItemFormDialog> createState() =>
      _SimpleItemFormDialogState();
}

class _SimpleItemFormDialogState extends ConsumerState<SimpleItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _description = TextEditingController();
  final _salePrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _currentStock = TextEditingController(text: '1');
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Recalcula a prévia de lucro a cada tecla — é a resposta imediata à
    // pergunta que motivou o campo "preço de compra" existir aqui.
    _salePrice.addListener(() => setState(() {}));
    _costPrice.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _description.dispose();
    _salePrice.dispose();
    _costPrice.dispose();
    _currentStock.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  /// Margem bruta prevista: (venda − compra) / compra. `null` sem os dois
  /// valores — sem custo não há o que comparar, e mostrar "0%" mentiria.
  ({double lucro, double pct})? get _margem {
    final venda = _num(_salePrice);
    final custo = _num(_costPrice);
    if (venda == null || custo == null || custo <= 0) return null;
    return (lucro: venda - custo, pct: (venda - custo) / custo * 100);
  }

  Future<void> _abrirCompleto() async {
    // Diálogo cheio: SKU, código de barras, fiscal, campos da vertical. Fecha
    // o simples SEM salvar — ele não tem nada digno de aproveitar ainda (o
    // completo tem seu próprio fluxo do zero, inclusive código-first).
    Navigator.pop(context);
    final ok = await ItemFormDialog.show(context);
    if (ok == true) ref.invalidate(itemListProvider);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final draft = ItemDraft(
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      salePrice: _num(_salePrice),
      costPrice: _num(_costPrice),
      currentStock: _num(_currentStock) ?? 0,
    );
    try {
      await ref.read(inventoryRepositoryProvider).createItem(draft);
      ref.invalidate(itemListProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
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

    return NeuDialog(
      title: 'Novo produto',
      maxWidth: 460,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
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
            NeuTextField(
              label: 'Nome *',
              controller: _name,
              hint: 'Filtro de óleo, pastilha de freio…',
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Marca',
              controller: _brand,
              hint: 'Opcional',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Descrição',
              controller: _description,
              hint: 'Opcional — detalhe, aplicação, observação…',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
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
              // A resposta à pergunta que o preço de compra existe para
              // responder: quanto sobra nessa venda. Sem isso, o campo
              // "preço de compra" seria só um número guardado sem propósito
              // visível — e é exatamente o que alimenta os relatórios de
              // lucro depois.
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Quantidade em estoque',
              controller: _currentStock,
              hint: '1',
              prefixIcon: Icons.inventory_2_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter(3)],
              helper: 'Quantas unidades você já tem agora.',
            ),
            const SizedBox(height: 16),
            // Porta de saída para quem precisa de mais: código de barras,
            // SKU, classificação fiscal, campos da vertical, ou cadastrar um
            // SERVIÇO (que não tem estoque nem preço de compra — não faz
            // parte deste formulário).
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _salvando ? null : _abrirCompleto,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(
                  'Cadastro completo (código de barras, fiscal, serviço…)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
