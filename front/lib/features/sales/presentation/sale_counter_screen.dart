import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../customers/domain/customers_models.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../os/presentation/os_status.dart' show money;
import '../domain/sale_models.dart';
import 'sale_providers.dart';
import 'sale_status.dart';

/// Balcão de venda (`/m/sales/nova`) — a tela mais importante do módulo, feita
/// para ser rápida e simples: busca grande de produto → carrinho com botões
/// grandes → cliente (ou consumidor final) → pagamento → "Finalizar venda".
/// Corpo apenas — a moldura é do shell.
class SaleCounterScreen extends ConsumerStatefulWidget {
  const SaleCounterScreen({super.key});

  @override
  ConsumerState<SaleCounterScreen> createState() => _SaleCounterScreenState();
}

class _SaleCounterScreenState extends ConsumerState<SaleCounterScreen> {
  // Carrinho (transitório na tela).
  final List<SaleItemDraft> _cart = [];

  // Cliente (só id + nome de exibição — "aponta, não invade").
  String? _customerId;
  String? _customerName;

  // Pagamento e desconto.
  PaymentMethod? _payment;
  final _discount = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  num get _subtotal => _cart.fold<num>(0, (sum, i) => sum + i.lineTotal);

  num get _discountValue {
    final raw = _discount.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw) ?? 0;
    return v < 0 ? 0 : v;
  }

  num get _total {
    final t = _subtotal - _discountValue;
    return t < 0 ? 0 : t;
  }

  bool get _canFinish =>
      _cart.isNotEmpty && _payment != null && !_submitting;

  // ---- Carrinho ----

  void _addInventory(InventoryItem item) {
    setState(() {
      final idx = _cart.indexWhere(
        (c) => c.inventoryItemId != null && c.inventoryItemId == item.id,
      );
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + 1);
      } else {
        _cart.add(SaleItemDraft(
          inventoryItemId: item.id,
          name: item.name,
          kind: item.kind,
          quantity: 1,
          unitPrice: double.tryParse(item.salePrice ?? '') ?? 0,
          currentStock: item.kind == 'product'
              ? double.tryParse(item.currentStock)
              : null,
        ));
      }
    });
  }

  void _addLoose(SaleItemDraft draft) => setState(() => _cart.add(draft));

  void _setQty(int index, num qty) {
    if (qty < 1) return;
    setState(() => _cart[index] = _cart[index].copyWith(quantity: qty));
  }

  void _removeAt(int index) => setState(() => _cart.removeAt(index));

  // ---- Ações ----

  Future<void> _pickCustomer() async {
    final picked = await _CustomerPickerDialog.show(context);
    if (picked == null) return; // fechou sem escolher
    setState(() {
      // Sentinela: id vazio = "Consumidor final".
      _customerId = picked.id.isEmpty ? null : picked.id;
      _customerName = picked.id.isEmpty ? null : picked.name;
    });
  }

  Future<void> _addLooseItem() async {
    final draft = await _LooseItemDialog.show(context);
    if (draft != null) _addLoose(draft);
  }

  Future<void> _finish() async {
    if (!_canFinish) return;
    setState(() => _submitting = true);
    final draft = SaleDraft(
      customerId: _customerId,
      items: _cart,
      discount: _discountValue > 0 ? _discountValue : null,
      paymentMethod: _payment!.key,
    );
    try {
      final sale = await ref.read(saleRepositoryProvider).checkout(draft);
      ref.invalidate(saleListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda finalizada com sucesso!')),
      );
      context.go('/m/sales/${sale.id}');
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível finalizar a venda.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final pad = isDesktop ? 28.0 : 16.0;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductSearch(onPick: _addInventory, onAddLoose: _addLooseItem),
        const SizedBox(height: 16),
        _CartSection(
          cart: _cart,
          onInc: (i) => _setQty(i, _cart[i].quantity + 1),
          onDec: (i) => _setQty(i, _cart[i].quantity - 1),
          onRemove: _removeAt,
        ),
      ],
    );

    final right = _CheckoutPanel(
      customerName: _customerName,
      onPickCustomer: _pickCustomer,
      discountController: _discount,
      onDiscountChanged: () => setState(() {}),
      payment: _payment,
      onPayment: (m) => setState(() => _payment = m),
      subtotal: _subtotal,
      discount: _discountValue,
      total: _total,
      canFinish: _canFinish,
      submitting: _submitting,
      onFinish: _finish,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
              child: Row(
                children: [
                  NeuIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Voltar',
                    size: 44,
                    onPressed: () => context.go('/m/sales'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nova venda',
                    style: TextStyle(
                      color: context.neu.ink,
                      fontSize: isDesktop ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isDesktop
                  ? Padding(
                      padding: EdgeInsets.all(pad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(child: left),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(child: right),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          left,
                          const SizedBox(height: 16),
                          right,
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Busca de produto =====================

/// Busca grande de produto no estoque (reusa o repo de inventory). Tocar num
/// resultado adiciona ao carrinho. Botão "Item avulso" para o que não está no
/// estoque.
class _ProductSearch extends ConsumerStatefulWidget {
  const _ProductSearch({required this.onPick, required this.onAddLoose});

  final ValueChanged<InventoryItem> onPick;
  final VoidCallback onAddLoose;

  @override
  ConsumerState<_ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<_ProductSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<InventoryItem> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    setState(() => _query = q);
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .listItems(q: q, active: 'true', sort: 'name_asc', page: 1);
      if (!mounted || _query != q) return;
      setState(() {
        _results = page.items;
        _loading = false;
      });
    } on AppException {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _pick(InventoryItem item) {
    widget.onPick(item);
    _controller.clear();
    setState(() {
      _query = '';
      _results = const [];
    });
  }

  String _fmtStock(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return raw;
    return v == v.truncate()
        ? v.toInt().toString()
        : v.toString().replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Adicionar produto',
            style: TextStyle(
              color: neu.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          NeuSearchBar(
            controller: _controller,
            hint: 'Buscar produto ou serviço por nome ou código',
            onChanged: _onChanged,
            onSubmitted: _search,
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (_query.isNotEmpty && _results.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Nada encontrado para "$_query". Use "Item avulso" para vender '
              'algo que não está no estoque.',
              style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.4),
            ),
          ] else if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < _results.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: neu.base,
                          indent: 14,
                          endIndent: 14),
                    _ResultRow(
                      item: _results[i],
                      stockLabel: _fmtStock,
                      onTap: () => _pick(_results[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: NeuButton(
              label: 'Item avulso',
              icon: Icons.add_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: widget.onAddLoose,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.stockLabel,
    required this.onTap,
  });

  final InventoryItem item;
  final String Function(String) stockLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isService = item.kind == 'service';
    final priceText = money(item.salePrice);
    final sub = isService
        ? priceText
        : '$priceText  ·  estoque: ${stockLabel(item.currentStock)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isService
                  ? Icons.design_services_outlined
                  : Icons.inventory_2_outlined,
              size: 22,
              color: neu.inkMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: neu.ink, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(color: neu.inkMuted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.add_circle_outline_rounded, color: neu.navy, size: 26),
          ],
        ),
      ),
    );
  }
}

// ===================== Carrinho =====================

class _CartSection extends StatelessWidget {
  const _CartSection({
    required this.cart,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  final List<SaleItemDraft> cart;
  final ValueChanged<int> onInc;
  final ValueChanged<int> onDec;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Carrinho',
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                Text(
                  '${cart.length} ${cart.length == 1 ? 'item' : 'itens'}',
                  style: TextStyle(color: neu.inkMuted, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (cart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 40, color: neu.inkFaint),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum item ainda.\nBusque um produto acima para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: neu.inkMuted, fontSize: 13.5, height: 1.4),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < cart.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _CartRow(
                item: cart[i],
                onInc: () => onInc(i),
                onDec: () => onDec(i),
                onRemove: () => onRemove(i),
              ),
            ],
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  final SaleItemDraft item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  String _fmtQty(num q) =>
      q == q.truncate() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isService = item.kind == 'service';
    // Aviso suave de estoque para produto do catálogo.
    final overStock = item.currentStock != null &&
        !isService &&
        item.quantity > item.currentStock!;
    return NeuCard(
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isService
                    ? Icons.design_services_outlined
                    : Icons.inventory_2_outlined,
                size: 20,
                color: neu.inkMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: neu.ink, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money(item.unitPrice.toStringAsFixed(2)),
                      style: TextStyle(color: neu.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              NeuIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remover item',
                size: 42,
                color: neu.danger,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Botões grandes − e +.
              _StepButton(icon: Icons.remove_rounded, onTap: onDec),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  _fmtQty(item.quantity),
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: onInc),
              const Spacer(),
              Text(
                money(item.lineTotal.toStringAsFixed(2)),
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (overStock) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 15, color: neu.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quantidade acima do estoque disponível.',
                    style: TextStyle(color: neu.warning, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botão grande de passo (− / +) — alvo de 48px.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuIconButton(
      icon: icon,
      tooltip: icon == Icons.add_rounded ? 'Aumentar' : 'Diminuir',
      size: 48,
      color: neu.navy,
      onPressed: onTap,
    );
  }
}

// ===================== Painel de checkout =====================

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.customerName,
    required this.onPickCustomer,
    required this.discountController,
    required this.onDiscountChanged,
    required this.payment,
    required this.onPayment,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.canFinish,
    required this.submitting,
    required this.onFinish,
  });

  final String? customerName;
  final VoidCallback onPickCustomer;
  final TextEditingController discountController;
  final VoidCallback onDiscountChanged;
  final PaymentMethod? payment;
  final ValueChanged<PaymentMethod> onPayment;
  final num subtotal;
  final num discount;
  final num total;
  final bool canFinish;
  final bool submitting;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hasCustomer = (customerName ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cliente
        NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cliente',
                  style: TextStyle(
                      color: neu.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              InkWell(
                onTap: onPickCustomer,
                borderRadius: BorderRadius.circular(NeuTokens.rField),
                child: NeuSurface(
                  elevation: NeuElevation.inset,
                  radius: NeuTokens.rField,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        hasCustomer
                            ? Icons.person_rounded
                            : Icons.storefront_outlined,
                        color: neu.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasCustomer ? customerName! : 'Consumidor final',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.unfold_more_rounded,
                          color: neu.inkFaint, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque para escolher um cliente ou deixe como consumidor final.',
                style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Pagamento
        NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Forma de pagamento',
                  style: TextStyle(
                      color: neu.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  // 2 colunas de botões grandes.
                  const gap = 10.0;
                  final w = (c.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final m in PaymentMethod.values)
                        SizedBox(
                          width: w,
                          child: _PaymentButton(
                            method: m,
                            selected: payment == m,
                            onTap: () => onPayment(m),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Desconto + totais
        NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuTextField(
                controller: discountController,
                label: 'Desconto (opcional)',
                hint: '0,00',
                prefixIcon: Icons.discount_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => onDiscountChanged(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal',
                      style: TextStyle(color: neu.inkMuted, fontSize: 14)),
                  Text(money(subtotal.toStringAsFixed(2)),
                      style: TextStyle(
                          color: neu.ink, fontWeight: FontWeight.w700)),
                ],
              ),
              if (discount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Desconto',
                        style: TextStyle(color: neu.inkMuted, fontSize: 14)),
                    Text('- ${money(discount.toStringAsFixed(2))}',
                        style: TextStyle(
                            color: neu.ink, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: neu.navy.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(NeuTokens.rField),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            color: neu.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    Text(
                      money(total.toStringAsFixed(2)),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        color: neu.navy,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Finalizar
        NeuButton(
          label: 'Finalizar venda',
          icon: Icons.check_circle_outline_rounded,
          expanded: true,
          loading: submitting,
          onPressed: canFinish ? onFinish : null,
        ),
        if (!canFinish && !submitting) ...[
          const SizedBox(height: 8),
          Text(
            'Adicione ao menos um item e escolha a forma de pagamento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          boxShadow: selected ? null : neu.raised(),
        ),
        child: Row(
          children: [
            Icon(
              method.icon,
              color: selected ? neu.onNavy : neu.inkMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                method.label,
                style: TextStyle(
                  color: selected ? neu.onNavy : neu.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: neu.onNavy, size: 20),
          ],
        ),
      ),
    );
  }
}

// ===================== Dialog: item avulso =====================

/// Item avulso (fora do estoque): nome + tipo + preço. Retorna um
/// [SaleItemDraft] ou null.
class _LooseItemDialog extends StatefulWidget {
  const _LooseItemDialog();

  static Future<SaleItemDraft?> show(BuildContext context) {
    return showNeuDialog<SaleItemDraft>(
      context,
      dialog: const NeuDialog(
        title: 'Item avulso',
        maxWidth: 460,
        child: _LooseItemDialog(),
      ),
    );
  }

  @override
  State<_LooseItemDialog> createState() => _LooseItemDialogState();
}

class _LooseItemDialogState extends State<_LooseItemDialog> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  String _kind = 'product';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final price =
        double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Informe a descrição do item.');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Informe um preço maior que zero.');
      return;
    }
    Navigator.of(context).pop(SaleItemDraft(
      name: name,
      kind: _kind,
      quantity: 1,
      unitPrice: price,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Produto / Serviço
        Row(
          children: [
            Expanded(
              child: _KindChip(
                label: 'Produto',
                icon: Icons.inventory_2_outlined,
                selected: _kind == 'product',
                onTap: () => setState(() => _kind = 'product'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KindChip(
                label: 'Serviço',
                icon: Icons.design_services_outlined,
                selected: _kind == 'service',
                onTap: () => setState(() => _kind = 'service'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NeuTextField(
          controller: _name,
          label: 'Descrição',
          hint: 'Ex.: troca de lâmpada',
          prefixIcon: Icons.label_outline,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 14),
        NeuTextField(
          controller: _price,
          label: 'Preço',
          hint: '0,00',
          prefixIcon: Icons.sell_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NeuButton(
              label: 'Voltar',
              kind: NeuButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            NeuButton(
              label: 'Adicionar',
              icon: Icons.add_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          boxShadow: selected ? null : neu.raised(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? neu.onNavy : neu.inkMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? neu.onNavy : neu.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Dialog: escolher cliente =====================

/// Escolha simples de cliente (reusa o repo de customers). Retorna um
/// [_PickedCustomer]: id vazio = "Consumidor final"; null = fechou sem escolher.
class _PickedCustomer {
  const _PickedCustomer(this.id, this.name);
  final String id; // '' = consumidor final
  final String name;
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  static Future<_PickedCustomer?> show(BuildContext context) {
    return showNeuDialog<_PickedCustomer>(
      context,
      dialog: const NeuDialog(
        title: 'Escolher cliente',
        maxWidth: 480,
        child: _CustomerPickerDialog(),
      ),
    );
  }

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Customer> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    setState(() => _query = q);
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final page = await ref.read(customersRepositoryProvider).listCustomers(
            q: q,
            status: 'active',
            sort: 'name_asc',
            page: 1,
          );
      if (!mounted || _query != q) return;
      setState(() {
        _results = page.items;
        _loading = false;
      });
    } on AppException {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Consumidor final — sempre visível no topo (default e mais comum).
        InkWell(
          onTap: () =>
              Navigator.of(context).pop(const _PickedCustomer('', '')),
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          child: NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: neu.inkMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Consumidor final (sem cadastro)',
                    style: TextStyle(
                        color: neu.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        NeuSearchBar(
          controller: _controller,
          hint: 'Buscar cliente por nome',
          onChanged: _onChanged,
          onSubmitted: _search,
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_query.isNotEmpty && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum cliente encontrado.',
              style: TextStyle(color: neu.inkMuted, fontSize: 13.5),
            ),
          )
        else if (_results.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _results[i];
                return NeuListTile(
                  onTap: () => Navigator.of(context)
                      .pop(_PickedCustomer(c.id, c.name)),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: neu.navy.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_rounded,
                        size: 20, color: neu.navy),
                  ),
                  title: Text(c.name),
                  subtitle: (c.phone ?? c.document) != null
                      ? Text(c.phone ?? c.document ?? '')
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}
