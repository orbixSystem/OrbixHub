import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../domain/sale_models.dart';
import '../domain/sale_payment_split.dart';
import 'sale_providers.dart';

/// Abre o fluxo ÚNICO de Venda avulsa (balcão): buscar itens (select do estoque)
/// + cliente opcional → forma de pagamento (receber agora / a receber) →
/// confirmar. Num só fluxo cria a `sale` (baixa de estoque), registra o
/// recebimento no caixa (se pago) e, se marcado, emite a nota. Devolve a [Sale].
/// [refazerDe] pré-preenche as linhas a partir dos itens de uma venda anterior
/// — é o "refazer" do cancelar-e-refazer: como uma venda registrada não se edita
/// (o dinheiro já passou pelo caixa), corrigir é cancelar a errada e lançar a
/// nova sem redigitar tudo.
Future<Sale?> showSaleCreateDialog(
  BuildContext context, {
  List<SaleItem>? refazerDe,
}) {
  return showDialog<Sale?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(child: _SaleCreateDialog(refazerDe: refazerDe)),
  );
}

/// Abre o mini-picker de cliente (busca por nome). Devolve `(id, name)` ou
/// `null` se o usuário desistiu. Público porque o detalhe da venda também precisa
/// dele, para reatribuir a venda a um cliente.
Future<({String id, String name})?> showCustomerPicker(BuildContext context) {
  return showDialog<({String id, String name})?>(
    context: context,
    builder: (_) => const _CustomerPickerDialog(),
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
  const _SaleCreateDialog({this.refazerDe});

  /// Itens de uma venda cancelada, para relançar sem redigitar.
  final List<SaleItem>? refazerDe;

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
  String _method = 'dinheiro';
  bool _emitInvoice = false;

  // Descrição livre da venda (MELHORIA): aparece no extrato do caixa.
  final _descCtrl = TextEditingController();
  /// Valor recebido — é ele que decide se a venda é paga, parcial ou fiado.
  /// Não existe mais um "Receber agora? sim/não": o número já diz tudo, e um
  /// controle a menos é um jeito a menos de a tela discordar de si mesma.
  final _receivedCtrl = TextEditingController();

  /// Enquanto o operador não mexer no valor recebido, ele ACOMPANHA o total (o
  /// caso comum é receber tudo). Ao primeiro toque, para de acompanhar — senão
  /// adicionar um item apagaria o valor que ele acabou de digitar.
  bool _receivedTouched = false;
  // Desconto em valor sobre o total da venda.
  final _descontoCtrl = TextEditingController();

  /// Soma dos itens, antes do desconto.
  double get _bruto => _lines.fold<double>(0, (acc, l) => acc + l.subtotal);

  /// Desconto digitado, clampado ao bruto (espelha `applySaleDiscount` do
  /// backend — total negativo seria dinheiro saindo do caixa numa venda).
  double get _desconto {
    final v = double.tryParse(_descontoCtrl.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return 0;
    return v > _bruto ? _bruto : v;
  }

  /// Valor A PAGAR: é o que o caixa recebe e o Fiscal emite.
  double get _total => _bruto - _desconto;

  /// Quanto o cliente entregou. Vazio = zero (venda inteiramente fiada), o que é
  /// uma escolha legítima e confirmada no modal — não um erro a bloquear.
  double get _recebido {
    if (!_receivedTouched) return _total;
    final v = double.tryParse(_receivedCtrl.text.trim().replaceAll(',', '.'));
    return v == null || v < 0 ? 0 : v;
  }

  /// A divisão do dinheiro (caixa / troco / fiado) — regra no domínio, testada
  /// por fora da UI: errar aqui não aparece na tela, aparece no fechamento.
  SalePaymentSplit get _split => SalePaymentSplit.of(
        total: _total,
        recebido: _recebido,
        dinheiro: _method == 'dinheiro',
      );

  double get _falta => _split.falta;
  double get _troco => _split.troco;
  double get _aLancarNoCaixa => _split.aLancarNoCaixa;
  bool get _ehFiado => _split.ehFiado;

  @override
  void initState() {
    super.initState();
    // Refazer: copia os itens da venda cancelada. Preço e quantidade seguem
    // editáveis — normalmente é justamente um deles que estava errado.
    final origem = widget.refazerDe;
    if (origem != null) {
      for (final i in origem) {
        _lines.add(_DraftLine(
          inventoryItemId: i.inventoryItemId,
          name: i.name,
          kind: i.kind,
          quantity: double.tryParse(i.quantity.replaceAll(',', '.')) ?? 1,
          unitPrice: double.tryParse(i.unitPrice.replaceAll(',', '.')) ?? 0,
        ));
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _receivedCtrl.dispose();
    _descontoCtrl.dispose();
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
    final picked = await showCustomerPicker(context);
    if (picked != null) {
      setState(() {
        _customerId = picked.id;
        _customerName = picked.name;
      });
    }
  }

  /// "Essa venda será registrada como fiado." Confirma antes de criar, dizendo
  /// quanto falta e de quem — e alertando quando não há cliente identificado,
  /// caso em que a dívida cai no balde "sem cliente" e é quase incobrável.
  Future<bool> _confirmarFiado() async {
    final semCliente = _customerId == null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => NeuDialog(
        title: 'Registrar como fiado?',
        maxWidth: 420,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar fiado'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LinhaResumo(rotulo: 'Total da venda', valor: _total),
            _LinhaResumo(rotulo: 'Recebido agora', valor: _aLancarNoCaixa),
            const Divider(height: 18),
            _LinhaResumo(rotulo: 'Fica a receber', valor: _falta, destaque: true),
            const SizedBox(height: 14),
            Text(
              semCliente
                  ? 'Sem cliente identificado, esta dívida vai para "Sem '
                      'cliente" no Fiado — e fica difícil cobrar. Considere '
                      'voltar e escolher o cliente.'
                  : 'A dívida de ${_customerName ?? 'cliente'} aparecerá em '
                      'Caixa › Fiado, onde você pode receber depois.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: semCliente
                    ? Theme.of(ctx).colorScheme.error
                    : Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
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
    // Recebeu menos que o total ⇒ o resto é fiado. Confirmar explicitamente,
    // porque a consequência (dívida de um cliente) não é óbvia ao digitar um
    // número menor — e sem cliente identificado a cobrança fica difícil.
    if (_ehFiado) {
      final confirmado = await _confirmarFiado();
      if (!confirmado || !mounted) return;
    }
    setState(() => _submitting = true);
    try {
      // 1) cria a venda (baixa de estoque) — backend `sale`.
      final draft = SaleDraft(
        customerId: _customerId,
        discount: _desconto > 0 ? _desconto : null,
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

      // 2) registra no caixa APENAS o que entrou de fato — backend `cashier`.
      //
      // Antes esta chamada lançava o TOTAL mesmo num pagamento parcial e só
      // escrevia "Faltou X" na descrição: a gaveta acusava dinheiro que não
      // entrou, a venda ficava `pago` e a dívida sumia da carteira de fiado.
      // Agora o valor lançado é o recebido; o que falta permanece a receber e
      // aparece no Fiado, que é o único jeito de alguém cobrar aquilo depois.
      final aLancar = _aLancarNoCaixa;
      if (aLancar > 0.005) {
        // A descrição livre entra no extrato junto do nº ("VND-0001 · texto").
        final note = _descCtrl.text.trim();
        final desc = [sale.number, if (note.isNotEmpty) note].join(' · ');
        await ref.read(cashierRepositoryProvider).createEntry(EntryDraft(
              amount: aLancar,
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
        // O aviso diz o que de fato aconteceu com o dinheiro, incluindo o
        // parcial — que antes era indistinguível de uma venda paga.
        final paidMsg = _falta > 0
            ? (aLancar > 0.005
                ? ' · parcial, falta ${formatMoney(_falta)}'
                : ' · fiado')
            : ' · recebida';
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
    // O campo de valor recebido ESPELHA o total enquanto ninguém o editou — é o
    // caso comum (receber tudo) e evita o operador redigitar um número que já
    // está na tela. Escrever aqui é seguro porque, intocado, o campo não tem
    // foco: nenhum cursor para atropelar.
    if (!_receivedTouched) {
      final doTotal = formatAmountForInput(_total);
      if (_receivedCtrl.text != doTotal) _receivedCtrl.text = doTotal;
    }
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
            _DescontoRow(
              controller: _descontoCtrl,
              bruto: _bruto,
              desconto: _desconto,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            _PaymentSection(
              isNarrow: isNarrow,
              method: _method,
              emitInvoice: _emitInvoice,
              total: _total,
              recebido: _recebido,
              falta: _falta,
              troco: _troco,
              controller: _receivedCtrl,
              onMethod: (v) => setState(() => _method = v),
              onEmitInvoice: (v) => setState(() => _emitInvoice = v),
              onRecebidoChanged: () => setState(() => _receivedTouched = true),
              onValorExato: () => setState(() {
                _receivedTouched = true;
                _receivedCtrl.text = formatAmountForInput(_total);
              }),
            ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rodapé FIXO (total + botão de vender).
            _SubmitBar(
              isNarrow: isNarrow,
              total: _total,
              falta: _falta,
              submitting: _submitting,
              onSubmit: _submitting ? null : _submit,
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
/// Recebimento da venda: forma + **valor recebido**, e é o valor que decide se a
/// venda sai paga, parcial ou fiada.
///
/// Não há mais um "Receber agora? sim/não": ele era redundante com o próprio
/// campo de valor e permitia estados contraditórios (marcado "receber agora"
/// com valor menor que o total, que o app registrava como pago — o bug que
/// escondia fiado). O campo vem preenchido com o total, que é o caso comum.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.isNarrow,
    required this.method,
    required this.emitInvoice,
    required this.total,
    required this.recebido,
    required this.falta,
    required this.troco,
    required this.controller,
    required this.onMethod,
    required this.onEmitInvoice,
    required this.onRecebidoChanged,
    required this.onValorExato,
  });
  final bool isNarrow;
  final String method;
  final bool emitInvoice;
  final double total;
  final double recebido;
  final double falta;
  final double troco;
  final TextEditingController controller;
  final ValueChanged<String> onMethod;
  final ValueChanged<bool> onEmitInvoice;
  final VoidCallback onRecebidoChanged;
  final VoidCallback onValorExato;

  @override
  Widget build(BuildContext context) {
    final forma = DropdownButtonFormField<String>(
      initialValue: method,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, labelText: 'Forma'),
      items: [
        for (final m in cashierMethods)
          DropdownMenuItem(value: m, child: Text(methodLabel(m))),
      ],
      onChanged: (v) => onMethod(v ?? method),
    );
    final valor = TextFormField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [DecimalInputFormatter()],
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Valor recebido',
        prefixText: 'R\$ ',
      ),
      onChanged: (_) => onRecebidoChanged(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNarrow) ...[
          forma,
          const SizedBox(height: 10),
          valor,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: NeuExactAmountButton(onTap: onValorExato),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 150, child: forma),
              const SizedBox(width: 10),
              Expanded(child: valor),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: NeuExactAmountButton(onTap: onValorExato),
              ),
            ],
          ),
        // O efeito do valor digitado, dito na hora — o operador não deveria
        // descobrir que criou um fiado só no modal de confirmação.
        if (total > 0 && (falta > 0 || troco > 0)) ...[
          const SizedBox(height: 10),
          _EfeitoDoValor(falta: falta, troco: troco),
        ],
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

/// Faixa que traduz o valor recebido: troco a devolver ou fiado a receber.
class _EfeitoDoValor extends StatelessWidget {
  const _EfeitoDoValor({required this.falta, required this.troco});

  final double falta;
  final double troco;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final fiado = falta > 0;
    final cor = fiado ? neu.warning : neu.navy;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            fiado ? Icons.handshake_outlined : Icons.savings_outlined,
            size: 16,
            color: cor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fiado
                  ? 'Fiado: ficam ${formatMoney(falta)} a receber'
                  : 'Troco: ${formatMoney(troco)}',
              style: TextStyle(
                color: cor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha "rótulo … valor" do resumo de confirmação do fiado.
class _LinhaResumo extends StatelessWidget {
  const _LinhaResumo({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  final String rotulo;
  final double valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 13,
                color: destaque ? neu.ink : neu.inkMuted,
                fontWeight: destaque ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatMoney(valor),
            style: TextStyle(
              fontSize: destaque ? 16 : 13,
              fontWeight: FontWeight.w700,
              color: destaque ? neu.warning : neu.ink,
            ),
          ),
        ],
      ),
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
    required this.falta,
    required this.submitting,
    required this.onSubmit,
  });
  final bool isNarrow;
  final double total;

  /// O que fica a receber — muda o rótulo do botão, para o operador saber o que
  /// vai acontecer ANTES de tocar.
  final double falta;
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
      label: Text(falta > 0 ? 'Vender (fiado)' : 'Vender e receber'),
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
    // `Expanded` no texto (não `Spacer`) para a barra nunca estourar: com
    // `Spacer` a largura mínima do botão somava à do texto e transbordava 14px
    // no diálogo de 560px — bug antigo, que só apareceu quando este fluxo
    // ganhou teste.
    return Row(
      children: [
        Expanded(child: totalText),
        const SizedBox(width: 12),
        button,
      ],
    );
  }
}

/// Linha de troco (só dinheiro): informa o valor recebido e mostra o troco.
/// Desconto em valor sobre a venda.
///
/// Só aparece quando há itens — desconto sobre nada não faz sentido. Mostra
/// bruto → desconto → a pagar, para o operador ver o efeito antes de fechar, e
/// avisa quando o desconto zera a venda (brinde) ou foi limitado ao bruto.
class _DescontoRow extends StatelessWidget {
  const _DescontoRow({
    required this.controller,
    required this.bruto,
    required this.desconto,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double bruto;
  final double desconto;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (bruto <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // Digitou mais do que a venda: o backend clampa, então avisamos aqui.
    final digitado =
        double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    final limitado = digitado > bruto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [DecimalInputFormatter()],
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Desconto',
                  prefixText: r'R$ ',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (desconto > 0)
              IconButton(
                tooltip: 'Remover desconto',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
          ],
        ),
        if (desconto > 0) ...[
          const SizedBox(height: 4),
          Text(
            limitado
                ? 'Desconto limitado ao valor da venda '
                    '(${formatMoney(bruto)}).'
                : '${formatMoney(bruto)} − ${formatMoney(desconto)} = '
                    '${formatMoney(bruto - desconto)}'
                    '${bruto - desconto <= 0 ? ' · venda como brinde' : ''}',
            style: TextStyle(
              color: limitado ? AppColors.warning : scheme.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
        ],
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
      // Mesmas proporções do `_LineTile` (5/3/3 + 36) — colunas em flex, não em
      // largura fixa: com os steppers, largura fixa estourava a linha no
      // diálogo de 560px.
      child: Row(
        children: const [
          Expanded(flex: 5, child: Text('ITEM', style: style)),
          SizedBox(width: 6),
          Expanded(flex: 3, child: Text('QTD', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 6),
          Expanded(flex: 3, child: Text('PREÇO (R\$)', style: style, textAlign: TextAlign.right)),
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
    // Os steppers ocupam ~290px fixos: numa linha só, no celular, não sobraria
    // espaço para o nome do item. Abaixo de 520px o item empilha — nome em cima,
    // quantidade × preço embaixo.
    final empilhar = MediaQuery.sizeOf(context).width < 520;
    final nome = line.isFree
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
        : Text(line.name, overflow: TextOverflow.ellipsis);

    // Quantidade: passo 1 no toque, mas o campo aceita fração (0,5 h de mão de
    // obra) — por isso 3 casas na digitação.
    final quantidade = NeuStepperField(
      value: line.quantity,
      decimals: 3,
      semanticLabel: 'Quantidade',
      validator: Validators.positiveNumber(field: 'Quantidade'),
      onChanged: (v) {
        line.quantity = v;
        onChanged();
      },
    );
    final preco = NeuStepperField(
      value: line.unitPrice,
      decimals: 2,
      textAlign: TextAlign.right,
      semanticLabel: 'Preço unitário',
      validator: Validators.positiveNumber(field: 'Preço'),
      onChanged: (v) {
        line.unitPrice = v;
        onChanged();
      },
    );
    final remover = IconButton(
      padding: EdgeInsets.zero,
      tooltip: 'Remover',
      icon: const Icon(Icons.delete_outline, size: 18),
      onPressed: onRemove,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: empilhar ? 8 : 4),
      child: empilhar
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: nome),
                    SizedBox(width: 36, child: remover),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: quantidade),
                    const SizedBox(width: 6),
                    Expanded(child: preco),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: nome),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: quantidade),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: preco),
                SizedBox(width: 36, child: remover),
              ],
            ),
    );
  }
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
