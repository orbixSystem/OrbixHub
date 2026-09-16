import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/validators.dart';
import '../../inventory/domain/stock_status.dart';
import '../../inventory/presentation/simple_item_form_dialog.dart';
import '../../inventory/presentation/stock_badge.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Conteúdo (sem moldura) para descrever um item de OS: busca no estoque
/// (`searchInventory`) OU item avulso (nome/preço livres).
///
/// É um PAINEL, não um diálogo, porque tem dois donos: a tela de detalhe abre-o
/// dentro de um [ItemPickerDialog], e o wizard "Nova OS" — que já é um diálogo —
/// embute-o **inline** no passo. Diálogo abrindo diálogo abrindo diálogo é
/// exatamente o que queremos evitar.
class ItemPickerPanel extends ConsumerStatefulWidget {
  const ItemPickerPanel({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  final ValueChanged<OrderItemDraft> onConfirm;
  final VoidCallback onCancel;

  @override
  ConsumerState<ItemPickerPanel> createState() => _ItemPickerPanelState();
}

class _ItemPickerPanelState extends ConsumerState<ItemPickerPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _avulso = false; // false = do estoque, true = item avulso

  // Estoque
  InventoryOption? _picked;
  String _lastInventoryQuery = '';

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

  /// Estado de estoque do item escolhido — mesma regra da lista de estoque e
  /// do caixa.
  StockStatus get _estadoDoPicked => _picked == null || _avulso
      ? StockStatus.semControle
      : stockStatusOf(
          kind: _picked!.kind,
          currentStock: _picked!.currentStock,
          minStock: _picked!.minStock,
        );

  /// Aviso de estoque — `null` quando não se aplica (item avulso, serviço, ou
  /// item de catálogo sem controle de estoque).
  ///
  /// Aqui é AVISO, não bloqueio (ao contrário do caixa): a OS só consome
  /// estoque quando chega no status que consome, e a reconciliação é
  /// best-effort — lançar a peça que ainda vai ser comprada é fluxo normal de
  /// oficina. Bloquear impediria de descrever o serviço antes de ter a peça.
  ///
  /// Antes isto era um diálogo de confirmação POR CIMA do diálogo do item. Como
  /// aviso na própria tela ele aparece ENQUANTO a quantidade é digitada, e não
  /// depois de já ter mandado adicionar — e some uma pilha de diálogos.
  String? get _avisoEstoque {
    if (_avulso || _picked == null || _picked!.kind != 'product') return null;
    final stock = double.tryParse(_picked!.currentStock ?? '');
    if (stock == null) return null;
    final qty = _toDouble(_quantity.text) ?? 1;
    if (stock <= 0) {
      return 'Produto esgotado. Dá para lançar na OS mesmo assim — o estoque '
          'só é baixado quando a OS chega no status que consome.';
    }
    if (qty <= stock) {
      return _estadoDoPicked == StockStatus.baixo
          ? 'Estoque baixo: restam ${_fmtStock(stock.toString())}.'
          : null;
    }
    return 'Estoque insuficiente: disponível ${_fmtStock(stock.toString())}. '
        'Dá para adicionar mesmo assim.';
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? true)) return;
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
            // O nome viaja junto para quem só tem o draft na mão conseguir
            // mostrar o item antes de existir OS (wizard "Nova OS"). No
            // servidor ele é ignorado: com `inventoryItemId`, o nome é
            // refotografado do estoque.
            name: _picked!.name,
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
            discount: _toDouble(_discount.text),
          );
    widget.onConfirm(draft);
  }

  bool get _canConfirm =>
      _avulso ? _name.text.trim().isNotEmpty : _picked != null;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final aviso = _avisoEstoque;
    return Form(
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
                  validator: Validators.positiveNumber(field: 'Quantidade'),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Desconto (opcional)',
              prefixText: 'R\$ ',
              prefixIcon: Icon(Icons.discount_outlined),
            ),
            validator:
                Validators.positiveNumber(optional: true, field: 'Desconto'),
            onChanged: (_) => setState(() {}),
          ),
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final esgotado = _estadoDoPicked == StockStatus.esgotado;
              final cor = esgotado ? neu.danger : neu.warning;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    esgotado
                        ? Icons.block_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: cor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aviso,
                      style: TextStyle(
                        color: cor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: 12),
          _PreviewTotal(
            quantity: _toDouble(_quantity.text),
            unitPrice: _toDouble(_unitPrice.text),
            discount: _toDouble(_discount.text),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              NeuButton(
                label: 'Cancelar',
                kind: NeuButtonKind.secondary,
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: 10),
              NeuButton(
                label: 'Adicionar',
                icon: Icons.check_rounded,
                onPressed: _canConfirm ? _confirm : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _criarProduto() async {
    final item = await SimpleItemFormDialog.show(
      context,
      initialName: _lastInventoryQuery.trim(),
    );
    if (item != null && mounted) {
      _pickInventory(InventoryOption(
        id: item.id,
        name: item.name,
        kind: item.kind,
        salePrice: item.salePrice,
        currentStock: item.currentStock,
        minStock: item.minStock,
      ));
    }
  }

  List<Widget> _inventoryFields() {
    return [
      Autocomplete<InventoryOption>(
        displayStringForOption: (o) => o.name,
        optionsBuilder: (value) async {
          _lastInventoryQuery = value.text;
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
            decoration: InputDecoration(
              labelText: 'Serviço cadastrado ou Produto do estoque',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Criar produto/serviço',
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: _criarProduto,
              ),
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
                    const BoxConstraints(maxHeight: 280, maxWidth: 412),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      Builder(builder: (context) {
                        final estado = stockStatusOf(
                          kind: o.kind,
                          currentStock: o.currentStock,
                          minStock: o.minStock,
                        );
                        final cor = corDoEstoque(context, estado);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            o.kind == 'service'
                                ? Icons.design_services_outlined
                                : Icons.inventory_2_outlined,
                            size: 20,
                            color: cor,
                          ),
                          title: Text(o.name, style: TextStyle(color: cor)),
                          subtitle: Text(
                            o.kind == 'product' && o.currentStock != null
                                ? '${money(o.salePrice)}  ·  '
                                      'estoque: ${_fmtStock(o.currentStock!)}'
                                : money(o.salePrice),
                            style: TextStyle(color: cor),
                          ),
                          // Sem bloqueio, de propósito — ver [_avisoEstoque].
                          trailing: StockBadge(status: estado, compacto: true),
                          onTap: () => onSelected(o),
                        );
                      }),
                    // Criar novo — sempre visível no final da lista
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline_rounded,
                          size: 20),
                      title: Text(
                        _lastInventoryQuery.trim().isNotEmpty
                            ? 'Criar "${_lastInventoryQuery.trim()}"'
                            : 'Criar produto/serviço',
                      ),
                      onTap: () {
                        // Fecha o overlay antes de abrir o form
                        FocusManager.instance.primaryFocus?.unfocus();
                        _criarProduto();
                      },
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
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: Icon(
                  _picked!.kind == 'service'
                      ? Icons.design_services_outlined
                      : Icons.inventory_2_outlined,
                  size: 18,
                  color: corDoEstoque(context, _estadoDoPicked),
                ),
                label: Text(_picked!.name),
              ),
              StockBadge(status: _estadoDoPicked),
            ],
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

/// Moldura de diálogo em volta do [ItemPickerPanel] — usada pela tela de
/// detalhe da OS, onde o painel abre a partir de uma TELA (um nível de diálogo,
/// não uma pilha).
class ItemPickerDialog extends StatelessWidget {
  const ItemPickerDialog({super.key});

  static Future<OrderItemDraft?> show(BuildContext context) {
    return showDialog<OrderItemDraft>(
      context: context,
      builder: (_) => const ItemPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: 'Adicionar item',
      maxWidth: context.isMobile ? 560 : 480,
      child: ItemPickerPanel(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: (draft) => Navigator.of(context).pop(draft),
      ),
    );
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
