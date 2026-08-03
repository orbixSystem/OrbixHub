import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../domain/sale_models.dart';
import 'sale_providers.dart';

/// Abre o fluxo ÚNICO de Venda avulsa (balcão): buscar itens (select do estoque)
/// + cliente opcional → forma de pagamento (receber agora / a receber) →
/// confirmar. Num só fluxo cria a `sale` (baixa de estoque), registra o
/// recebimento no caixa (se pago) e, se marcado, emite a nota. Devolve a [Sale].
Future<Sale?> showSaleCreateDialog(BuildContext context) {
  return showDialog<Sale?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(child: _SaleCreateDialog()),
  );
}

/// Linha em edição (antes de enviar). Item do estoque tem `inventoryItemId` e
/// nome fixo; item avulso tem nome editável. Qtd e preço sempre editáveis.
class _DraftLine {
  _DraftLine({
    this.inventoryItemId,
    required this.name,
    required this.kind,
    this.quantity = 1,
    this.unitPrice = 0,
  });
  final String? inventoryItemId;
  String name;
  String kind; // 'product' | 'service'
  double quantity;
  double unitPrice;

  bool get isFree => inventoryItemId == null;
  double get subtotal => quantity <= 0 ? 0 : quantity * unitPrice;
}

class _SaleCreateDialog extends ConsumerStatefulWidget {
  const _SaleCreateDialog();

  @override
  ConsumerState<_SaleCreateDialog> createState() => _SaleCreateDialogState();
}

class _SaleCreateDialogState extends ConsumerState<_SaleCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_DraftLine> _lines = [];
  bool _submitting = false;

  // cliente opcional
  String? _customerId;
  String? _customerName;

  // pagamento (parte do fluxo único)
  bool _receiveNow = true; // false = deixar "a receber" (faturado)
  String _method = 'dinheiro';
  bool _emitInvoice = false;

  // Descrição livre da venda (MELHORIA): aparece no extrato do caixa.
  final _descCtrl = TextEditingController();
  // Valor recebido em dinheiro (MELHORIA): calcula o troco na hora.
  final _receivedCtrl = TextEditingController();

  double get _total => _lines.fold<double>(0, (acc, l) => acc + l.subtotal);

  // Troco só faz sentido recebendo agora, em dinheiro.
  bool get _showChange => _receiveNow && _method == 'dinheiro';
  double? get _received =>
      double.tryParse(_receivedCtrl.text.trim().replaceAll(',', '.'));
  double get _change => (_received ?? 0) - _total;

  // Recebendo agora em dinheiro, exige apenas que ALGO seja digitado no "Valor
  // recebido" (não trava por diferença — não faz sentido bloquear por centavos).
  // Só vale quando há algo a receber (total > 0); vazio não autoriza a venda.
  bool get _insufficientCash {
    if (!_showChange || _total <= 0) return false;
    return _receivedCtrl.text.trim().isEmpty;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  /// Adiciona um item do estoque à lista. Se já existir (mesmo id), só soma 1 na
  /// quantidade — buscar de novo um produto que já está na lista não duplica.
  void _addFromItem(InventoryItem item) {
    setState(() {
      final existing = _lines.indexWhere((l) => l.inventoryItemId == item.id);
      if (existing >= 0) {
        _lines[existing].quantity += 1;
      } else {
        _lines.add(_DraftLine(
          inventoryItemId: item.id,
          name: item.name,
          kind: item.kind,
          quantity: 1,
          unitPrice: moneyToDouble(item.salePrice),
        ));
      }
    });
  }

  void _addFreeItem() {
    setState(() {
      _lines.add(_DraftLine(name: '', kind: 'service', quantity: 1, unitPrice: 0));
    });
  }

  Future<void> _pickCustomer() async {
    final picked = await showDialog<({String id, String name})?>(
      context: context,
      builder: (_) => const _CustomerPickerDialog(),
    );
    if (picked != null) {
      setState(() {
        _customerId = picked.id;
        _customerName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    final valid =
        _lines.where((l) => l.name.trim().isNotEmpty && l.quantity > 0).toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um item.')),
      );
      return;
    }
    // Valida nome/quantidade/preço de cada linha (positiveNumber etc.).
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (_insufficientCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor recebido.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      // 1) cria a venda (baixa de estoque) — backend `sale`.
      final draft = SaleDraft(
        customerId: _customerId,
        items: [
          for (final l in valid)
            SaleItemDraft(
              inventoryItemId: l.inventoryItemId,
              name: l.isFree ? l.name.trim() : null,
              kind: l.kind,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
            ),
        ],
      );
      final sale = await ref.read(saleRepositoryProvider).createSale(draft);

      // 2) registra o recebimento no caixa (se pago na hora) — backend `cashier`.
      if (_receiveNow && _total > 0) {
        // A descrição livre entra no extrato junto do nº ("VND-0001 · texto").
        // Se recebeu em dinheiro menos que o total, anota o que faltou no extrato.
        final note = _descCtrl.text.trim();
        final parts = <String>[sale.number];
        if (note.isNotEmpty) parts.add(note);
        if (_showChange) {
          final v = _received;
          if (v != null && v < _total) {
            parts.add('Faltou ${formatMoney(_total - v)}');
          }
        }
        final desc = parts.join(' · ');
        await ref.read(cashierRepositoryProvider).createEntry(EntryDraft(
              amount: _total,
              method: _method,
              category: 'venda_avulsa',
              saleKind: 'sale',
              saleId: sale.id,
              description: desc,
            ));
        ref.invalidate(cashierControllerProvider);
      }

      // 3) emite a nota, se marcado — backend `invoice` (Fiscal é dono).
      String? invoiceMsg;
      if (_emitInvoice) {
        try {
          final res = await ref.read(saleRepositoryProvider).emitInvoice(sale.id);
          invoiceMsg = 'Nota: ${res.status}';
        } catch (e) {
          invoiceMsg = 'Nota indisponível ($e)';
        }
      }

      if (mounted) {
        Navigator.of(context).pop(sale);
        final paidMsg = _receiveNow && _total > 0 ? ' · recebida' : ' · a receber';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Venda ${sale.number} (${formatMoney(sale.total)})$paidMsg'
              '${invoiceMsg != null ? ' · $invoiceMsg' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsivo: em telas estreitas (celular) o diálogo ocupa quase a tela toda;
    // em desktop fica num cartão de 560px. Evita campos espremidos/cortados.
    final media = MediaQuery.sizeOf(context);
    final isNarrow = media.width < 620; // celular: empilha os controles
    final maxW = isNarrow ? media.width - 24 : 560.0;
    final maxH = media.height < 780 ? media.height - 40 : 720.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho FIXO (não rola com o corpo).
            Row(
              children: [
                const Icon(Icons.shopping_cart_checkout_outlined,
                    color: AppColors.brandDeep),
                const SizedBox(width: 8),
                Text('Venda avulsa',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Miolo ROLÁVEL: em telas baixas ou com o teclado aberto, só esta
            // parte rola — cabeçalho e rodapé permanecem fixos.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
            // cliente opcional
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppColors.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _customerName ?? 'Sem cliente (balcão)',
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ),
                if (_customerId != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _customerId = null;
                      _customerName = null;
                    }),
                    child: const Text('Remover'),
                  ),
                TextButton.icon(
                  onPressed: _pickCustomer,
                  icon: const Icon(Icons.search, size: 16),
                  label: Text(_customerId == null ? 'Cliente' : 'Trocar'),
                ),
              ],
            ),
            const Divider(height: 24),
            // busca de produto (SELECT flutuante — não empurra o layout).
            _ProductPicker(onPick: _addFromItem),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addFreeItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar item avulso'),
              ),
            ),
            const SizedBox(height: 8),
            // Tabela de itens — SEMPRE visível (adicionar não troca a tela).
            const _ItemsHeader(),
            const SizedBox(height: 4),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Busque um produto do estoque ou adicione um item avulso.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                // O scroll é do corpo (SingleChildScrollView); a lista só empilha.
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lines.length,
                itemBuilder: (_, i) => _LineTile(
                  line: _lines[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _lines.removeAt(i)),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Descrição livre da venda (MELHORIA) — vai para o extrato do caixa.
            TextField(
              controller: _descCtrl,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                labelText: 'Descrição da venda (opcional)',
                hintText: 'Ex.: cliente levou fiado, obs. do balcão…',
              ),
            ),
            const SizedBox(height: 16),
            _PaymentSection(
              isNarrow: isNarrow,
              receiveNow: _receiveNow,
              method: _method,
              emitInvoice: _emitInvoice,
              onReceiveNow: (v) => setState(() => _receiveNow = v),
              onMethod: (v) => setState(() => _method = v),
              onEmitInvoice: (v) => setState(() => _emitInvoice = v),
            ),
            // Troco (MELHORIA) — só ao receber agora em dinheiro.
            if (_showChange) ...[
              const SizedBox(height: 12),
              _CashChangeRow(
                controller: _receivedCtrl,
                change: _change,
                onChanged: () => setState(() {}),
              ),
            ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rodapé FIXO (total + botão de vender).
            _SubmitBar(
              isNarrow: isNarrow,
              total: _total,
              receiveNow: _receiveNow,
              submitting: _submitting,
              onSubmit: _submitting || _insufficientCash ? null : _submit,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Campo de busca de produto/serviço do estoque como SELECT (typeahead): conforme
/// digita, mostra um overlay flutuante com os itens (a API já limita a 20). Ao
/// escolher, o item entra na lista (não troca a tela) e o campo limpa pra próxima
/// busca. Itens repetidos só somam quantidade (tratado pelo chamador).
class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.onPick});
  final void Function(InventoryItem) onPick;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  TextEditingController? _ctrl;
  FocusNode? _watchedNode;

  @override
  void dispose() {
    _watchedNode?.removeListener(_onFocusMaybeOpen);
    super.dispose();
  }

  /// Ao ganhar foco com o campo vazio, "cutuca" o controller para forçar o
  /// Autocomplete a recalcular as opções (ele só recalcula quando o texto muda),
  /// fazendo a lista abrir no clique — não só depois de digitar.
  void _onFocusMaybeOpen() {
    final node = _watchedNode;
    final c = _ctrl;
    if (node == null || c == null) return;
    if (node.hasFocus && c.text.isEmpty) {
      c.value = const TextEditingValue(text: ' ');
      c.value = TextEditingValue.empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<InventoryItem>(
      displayStringForOption: (it) => it.name,
      optionsBuilder: (value) async {
        final q = value.text.trim();
        try {
          final page = await ref.read(inventoryRepositoryProvider).listItems(
                // Vazio → traz os primeiros itens (lista abre no clique).
                q: q.isEmpty ? null : q,
                active: 'true', // ativos (backend: 'true' | 'false' | 'all')
                lowStock: false,
                sort: 'name_asc',
                page: 1,
              );
          return page.items; // backend já limita a 20
        } catch (_) {
          return const Iterable<InventoryItem>.empty();
        }
      },
      onSelected: (it) {
        widget.onPick(it);
        // Limpa o campo p/ a próxima busca (senão fica o nome do item escolhido).
        Future.microtask(() => _ctrl?.clear());
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        _ctrl = controller;
        if (!identical(_watchedNode, focusNode)) {
          _watchedNode?.removeListener(_onFocusMaybeOpen);
          _watchedNode = focusNode;
          focusNode.addListener(_onFocusMaybeOpen);
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Buscar produto/serviço do estoque',
            hintText: 'Toque para ver a lista ou digite o nome',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {},
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) =>
                  Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant),
              itemBuilder: (_, i) {
                final it = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(it.name),
                  subtitle: Text(formatMoney(it.salePrice),
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: () => onSelected(it),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloco de pagamento do fluxo único: receber agora (com forma) ou a receber +
/// opção de emitir nota.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.isNarrow,
    required this.receiveNow,
    required this.method,
    required this.emitInvoice,
    required this.onReceiveNow,
    required this.onMethod,
    required this.onEmitInvoice,
  });
  final bool isNarrow;
  final bool receiveNow;
  final String method;
  final bool emitInvoice;
  final ValueChanged<bool> onReceiveNow;
  final ValueChanged<String> onMethod;
  final ValueChanged<bool> onEmitInvoice;

  @override
  Widget build(BuildContext context) {
    final segmented = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Receber agora')),
        ButtonSegment(value: false, label: Text('A receber')),
      ],
      selected: {receiveNow},
      onSelectionChanged: (s) => onReceiveNow(s.first),
      showSelectedIcon: false,
    );
    final forma = receiveNow
        ? DropdownButtonFormField<String>(
            initialValue: method,
            isExpanded: true,
            decoration:
                const InputDecoration(isDense: true, labelText: 'Forma'),
            items: [
              for (final m in cashierMethods)
                DropdownMenuItem(value: m, child: Text(methodLabel(m))),
            ],
            onChanged: (v) => onMethod(v ?? method),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No mobile empilha: o segmentado ocupa a linha toda (senão os rótulos
        // quebram em 2-3 linhas) e a "Forma" vem abaixo, também full-width.
        if (isNarrow) ...[
          SizedBox(width: double.infinity, child: segmented),
          if (forma != null) ...[
            const SizedBox(height: 10),
            forma,
          ],
        ] else
          Row(
            children: [
              Expanded(child: segmented),
              const SizedBox(width: 10),
              if (forma != null) SizedBox(width: 150, child: forma),
            ],
          ),
        // NF desligada no front (kInvoiceEnabled): sem a opção de emitir nota.
        if (kInvoiceEnabled)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: emitInvoice,
            onChanged: (v) => onEmitInvoice(v ?? false),
            title: const Text('Emitir nota fiscal'),
          ),
      ],
    );
  }
}

/// Rodapé do diálogo: total + botão de vender. No mobile empilha (total em cima,
/// botão full-width embaixo) para o rótulo do botão não quebrar em várias linhas;
/// no desktop mantém total à esquerda e botão à direita.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.isNarrow,
    required this.total,
    required this.receiveNow,
    required this.submitting,
    required this.onSubmit,
  });
  final bool isNarrow;
  final double total;
  final bool receiveNow;
  final bool submitting;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final totalText = Text(
      'Total: ${formatMoney(total)}',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );
    final button = FilledButton.icon(
      onPressed: onSubmit,
      icon: submitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check),
      label: Text(receiveNow ? 'Vender e receber' : 'Vender (a receber)'),
      style: FilledButton.styleFrom(
        minimumSize: isNarrow ? const Size(0, 48) : const Size(190, 44),
      ),
    );
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          totalText,
          const SizedBox(height: 12),
          button,
        ],
      );
    }
    return Row(
      children: [
        totalText,
        const Spacer(),
        button,
      ],
    );
  }
}

/// Linha de troco (só dinheiro): informa o valor recebido e mostra o troco.
/// Troco negativo (recebeu menos que o total) fica em vermelho como aviso.
class _CashChangeRow extends StatelessWidget {
  const _CashChangeRow({
    required this.controller,
    required this.change,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double change;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = controller.text.trim().isNotEmpty;
    final negative = change < 0;
    final changeColor = !hasValue
        ? scheme.onSurfaceVariant
        : negative
            ? AppColors.danger
            : AppColors.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [DecimalInputFormatter()],
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Valor recebido',
              prefixText: 'R\$ ',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Troco',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                hasValue ? formatMoney(negative ? 0 : change) : '—',
                style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
              if (negative && hasValue)
                Text('Faltam ${formatMoney(-change)}',
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 11))
              else if (!hasValue)
                Text('Informe o valor recebido',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho fixo da tabela de itens (alinha com as colunas das linhas).
class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.inkMuted, fontSize: 11, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: const [
          Expanded(flex: 4, child: Text('ITEM', style: style)),
          SizedBox(width: 6),
          SizedBox(width: 48, child: Text('QTD', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 6),
          SizedBox(width: 96, child: Text('PREÇO (R\$)', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });
  final _DraftLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: line.isFree
                ? TextFormField(
                    initialValue: line.name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: 'Descrição do item avulso'),
                    validator: Validators.required('Descrição'),
                    onChanged: (v) {
                      line.name = v;
                      onChanged();
                    },
                  )
                : Text(line.name, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            child: TextFormField(
              initialValue: _fmtNum(line.quantity),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // Quantidade admite fração (0,5 h de mão de obra) — 3 casas.
              inputFormatters: const [DecimalInputFormatter(3)],
              decoration: const InputDecoration(isDense: true),
              validator: Validators.positiveNumber(field: 'Quantidade'),
              onChanged: (v) {
                line.quantity = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 96,
            child: TextFormField(
              initialValue: line.unitPrice.toStringAsFixed(2),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              decoration: const InputDecoration(isDense: true),
              validator: Validators.positiveNumber(field: 'Preço'),
              onChanged: (v) {
                line.unitPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
}

/// Mini-picker de cliente (busca por nome). Devolve (id, name) ou null.
class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final _ctrl = TextEditingController();
  List<({String id, String name})> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final page = await ref.read(customersRepositoryProvider).listCustomers(
            q: q.trim().isEmpty ? null : q.trim(),
            status: 'active',
            sort: 'name_asc',
            page: 1,
          );
      if (mounted) {
        setState(() =>
            _results = page.items.map((c) => (id: c.id, name: c.name)).toList());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar cliente'),
      content: SizedBox(
        width: 380,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Buscar por nome', prefixIcon: Icon(Icons.search)),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('Nenhum cliente.'))
                      : ListView(
                          children: [
                            for (final c in _results)
                              ListTile(
                                dense: true,
                                title: Text(c.name),
                                onTap: () => Navigator.of(context).pop(c),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
      ],
    );
  }
}
