import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/payment_status.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// Parse de valor digitado (aceita vírgula) → double >= 0, ou null se inválido.
double? _parseAmount(String raw) {
  final v = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (v == null || v < 0) return null;
  return v;
}

void _snack(BuildContext context, String msg, {bool error = false}) {
  final neu = context.neu;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? neu.danger : neu.success,
    ),
  );
}

/// Rótulo em cima + cavidade (inset) do design system — casca padrão para
/// campos que não são [NeuTextField] (dropdowns, valores fixos, autocomplete).
/// Mesmo desenho do `_fieldShell` do order_form_dialog.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.child,
    this.padding,
    this.helper,
  });

  final String label;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: padding,
          child: child,
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              helper!,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

/// Abrir o caixa (valor inicial em gaveta).
Future<void> showOpenSessionDialog(BuildContext context, WidgetRef ref) async {
  final amountCtrl = TextEditingController(text: '0');
  final notesCtrl = TextEditingController();
  final ok = await showNeuDialog<bool>(
    context,
    dialog: NeuDialog(
      title: 'Abrir caixa',
      maxWidth: 420,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Cancelar',
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Abrir',
            icon: Icons.lock_open_outlined,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeuTextField(
            label: 'Valor inicial (gaveta)',
            controller: amountCtrl,
            hint: '0,00',
            prefixIcon: Icons.attach_money_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          NeuTextField(
            label: 'Observação (opcional)',
            controller: notesCtrl,
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final amount = _parseAmount(amountCtrl.text) ?? 0;
  try {
    await ref.read(cashierControllerProvider.notifier).open(
          openingAmount: amount,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (context.mounted) _snack(context, 'Caixa aberto.');
  } catch (e) {
    if (context.mounted) _snack(context, '$e', error: true);
  }
}

/// Fechar o caixa: informa contado → mostra esperado e diferença.
Future<void> showCloseSessionDialog(BuildContext context, WidgetRef ref) async {
  final countedCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final ok = await showNeuDialog<bool>(
    context,
    dialog: NeuDialog(
      title: 'Fechar caixa',
      maxWidth: 420,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Cancelar',
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Fechar caixa',
            icon: Icons.lock_outline,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
      child: Builder(
        builder: (ctx) {
          final neu = ctx.neu;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Conte o dinheiro em gaveta e informe o valor. '
                'Calculamos o esperado e a diferença.',
                style: TextStyle(
                    color: neu.inkMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              NeuTextField(
                label: 'Valor contado',
                controller: countedCtrl,
                hint: '0,00',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              NeuTextField(
                label: 'Observação (opcional)',
                controller: notesCtrl,
              ),
            ],
          );
        },
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final counted = _parseAmount(countedCtrl.text);
  if (counted == null) {
    _snack(context, 'Informe um valor válido.', error: true);
    return;
  }
  try {
    final closed = await ref.read(cashierControllerProvider.notifier).close(
          countedAmount: counted,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (!context.mounted) return;
    final diff = moneyToDouble(closed.difference);
    final label = diff == 0
        ? 'Caixa fechado certinho (sem diferença).'
        : diff > 0
            ? 'Caixa fechado com SOBRA de ${formatMoney(diff)}.'
            : 'Caixa fechado com FALTA de ${formatMoney(diff.abs())}.';
    _snack(context, label, error: diff != 0);
  } catch (e) {
    if (context.mounted) _snack(context, '$e', error: true);
  }
}

/// Novo lançamento (avulso/despesa/sangria/suprimento) ou recebimento de OS.
class EntryDialog extends ConsumerStatefulWidget {
  const EntryDialog({
    super.key,
    required this.config,
    this.presetCategory,
    this.presetSaleId,
  });

  final CashierConfig config;
  final String? presetCategory;
  final String? presetSaleId;

  @override
  ConsumerState<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<EntryDialog> {
  late String _category =
      widget.presetCategory ?? (widget.presetSaleId != null ? 'os_payment' : 'suprimento');
  late String _method = widget.config.paymentMethods.first;
  final _amountCtrl = TextEditingController();
  // OS escolhida no picker (recebimento de OS aponta pra ela).
  ServiceOrder? _selectedOs;
  // Resumo de pagamento da OS escolhida (total/pago/a receber) — para pré-preencher
  // o valor com o SALDO (suporta recebimento parcial) e mostrar o contexto.
  PaymentDetail? _osPayment;
  bool _loadingBalance = false;
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Suprimento/sangria mexem na GAVETA física → sempre em dinheiro.
    if (_cashOnly) _method = 'dinheiro';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Gestão do caixa (despesa/sangria/suprimento) é só dono/gerente; o atendente
  /// (cashier.write) só registra recebimento de OS.
  bool get _canManage {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('cashier.manage');
  }

  // Venda avulsa NÃO entra aqui (é o fluxo próprio do botão "Venda avulsa", que
  // cria a `sale` com itens). Atendente só vê "Recebimento OS"; gestão vê tudo.
  List<String> get _categories => _canManage
      ? const ['os_payment', 'suprimento', 'despesa', 'sangria']
      : const ['os_payment'];

  /// Suprimento (botar dinheiro na gaveta) e sangria (tirar dinheiro da gaveta)
  /// são movimentos da gaveta física → a forma é SEMPRE dinheiro.
  bool get _cashOnly => _category == 'suprimento' || _category == 'sangria';

  /// Ao escolher a OS: busca o resumo de pagamento e pré-preenche o valor com o
  /// SALDO a receber (parcial-aware), editável. Sem OS, limpa o contexto.
  Future<void> _onOsSelected(ServiceOrder? os) async {
    setState(() {
      _selectedOs = os;
      _osPayment = null;
    });
    if (os == null) return;
    setState(() => _loadingBalance = true);
    try {
      final detail = await ref.read(cashierRepositoryProvider).paymentSummary(
            saleKind: 'os',
            saleId: os.id,
            total: moneyToDouble(os.total),
          );
      if (!mounted) return;
      setState(() {
        _osPayment = detail;
        // Saldo a receber (>= 0); editável. Se já quitada, cai em 0.
        _amountCtrl.text = detail.balance.toStringAsFixed(2);
      });
    } catch (_) {
      // best-effort: sem o resumo, prefill no total como fallback.
      if (!mounted) return;
      setState(() => _amountCtrl.text = moneyToDouble(os.total).toStringAsFixed(2));
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _submit() async {
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack(context, 'Informe um valor maior que zero.', error: true);
      return;
    }
    final isOsPayment = _category == 'os_payment';
    final saleId = _selectedOs?.id;
    if (isOsPayment && (saleId == null || saleId.isEmpty)) {
      _snack(context, 'Selecione a OS do recebimento.', error: true);
      return;
    }
    // Guarda o nº da OS na descrição → o extrato mostra "OS-0001" (não só "OS").
    final note = _descCtrl.text.trim();
    final description = isOsPayment && _selectedOs != null
        ? (note.isEmpty ? _selectedOs!.number : '${_selectedOs!.number} · $note')
        : note;
    setState(() => _saving = true);
    try {
      await ref.read(cashierControllerProvider.notifier).addEntry(
            EntryDraft(
              amount: amount,
              method: _method,
              category: _category,
              saleKind: isOsPayment ? 'os' : null,
              saleId: isOsPayment ? saleId : null,
              description: description,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      _snack(context, 'Lançamento registrado.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, '$e', error: true);
      }
    }
  }

  /// Dropdown padrão do design system: cavidade + DropdownButtonFormField sem
  /// borda (mesmo padrão do order_form_dialog).
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required String Function(String) optionLabel,
    required ValueChanged<String?>? onChanged,
  }) {
    final neu = context.neu;
    return _FieldShell(
      label: label,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        dropdownColor: neu.surface,
        icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
        style: TextStyle(color: neu.ink, fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(optionLabel(o))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isOsPayment = _category == 'os_payment';
    return NeuDialog(
      title: 'Novo lançamento',
      maxWidth: 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        NeuButton(
          label: 'Registrar',
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) Tipo
          _dropdown(
            label: 'Tipo',
            value: _category,
            options: _categories,
            optionLabel: categoryLabel,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                      _category = v ?? _category;
                      // Ao virar suprimento/sangria, trava a forma em dinheiro.
                      if (_cashOnly) _method = 'dinheiro';
                    }),
          ),
          // 2) OS (logo após o Tipo, quando for recebimento de OS)
          if (isOsPayment) ...[
            const SizedBox(height: 14),
            _OsPicker(selected: _selectedOs, onChanged: _onOsSelected),
            if (_loadingBalance)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_osPayment != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _OsBalanceLine(payment: _osPayment!),
              ),
          ],
          const SizedBox(height: 14),
          // 3) Valor (pré-preenchido com o saldo da OS; editável → permite parcial)
          NeuTextField(
            label: 'Valor',
            controller: _amountCtrl,
            hint: '0,00',
            prefixIcon: Icons.attach_money_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            helper: isOsPayment && _osPayment != null
                ? 'Pode receber parcial — edite o valor à vontade.'
                : null,
          ),
          const SizedBox(height: 14),
          // 4) Forma — suprimento/sangria é sempre dinheiro (gaveta); demais, escolhe.
          if (_cashOnly)
            _FieldShell(
              label: 'Forma',
              helper: 'Suprimento/sangria é sempre em dinheiro (gaveta).',
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 18, color: neu.inkMuted),
                  const SizedBox(width: 8),
                  Text('Dinheiro',
                      style: TextStyle(color: neu.ink, fontSize: 15)),
                ],
              ),
            )
          else
            _dropdown(
              label: 'Forma',
              value: _method,
              options: widget.config.paymentMethods,
              optionLabel: methodLabel,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _method = v ?? _method),
            ),
          const SizedBox(height: 14),
          // 5) Descrição
          NeuTextField(
            label: 'Descrição (opcional)',
            controller: _descCtrl,
          ),
        ],
      ),
    );
  }
}

Future<void> showEntryDialog(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config, {
  String? presetCategory,
  String? presetSaleId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => EntryDialog(
      config: config,
      presetCategory: presetCategory,
      presetSaleId: presetSaleId,
    ),
  );
}

/// Contexto de pagamento da OS escolhida: Total · Pago · A receber. Deixa claro
/// pro caixa quanto falta (e que dá pra receber parcial).
class _OsBalanceLine extends StatelessWidget {
  const _OsBalanceLine({required this.payment});
  final PaymentDetail payment;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    Widget stat(String label, num value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: neu.inkMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(formatMoney(value),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ],
          ),
        );
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rChip,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          stat('Total', payment.total, neu.ink),
          stat('Pago', payment.paid, neu.success),
          stat('A receber', payment.balance, neu.navy),
        ],
      ),
    );
  }
}

/// Picker de OS pro recebimento: busca conforme digita (nº, cliente ou
/// responsável) e mostra um SELECT flutuante "OS-NNNN — Responsável" + cliente,
/// valor e tag de pagamento. Traz só os 20 primeiros (a API já pagina em 20).
/// Pensado pra vida do caixa: achar a OS sem decorar id.
class _OsPicker extends ConsumerStatefulWidget {
  const _OsPicker({required this.selected, required this.onChanged});

  final ServiceOrder? selected;
  final ValueChanged<ServiceOrder?> onChanged;

  @override
  ConsumerState<_OsPicker> createState() => _OsPickerState();
}

class _OsPickerState extends ConsumerState<_OsPicker> {
  Map<String, String> _members = const {};
  TextEditingController? _ctrl;
  FocusNode? _watchedNode;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _watchedNode?.removeListener(_onFocusMaybeOpen);
    super.dispose();
  }

  /// Ao ganhar foco com o campo vazio (nenhuma OS escolhida), cutuca o controller
  /// para o Autocomplete recalcular as opções e a lista abrir no clique.
  void _onFocusMaybeOpen() {
    final node = _watchedNode;
    final c = _ctrl;
    if (node == null || c == null) return;
    if (node.hasFocus && c.text.isEmpty && widget.selected == null) {
      c.value = const TextEditingValue(text: ' ');
      c.value = TextEditingValue.empty;
    }
  }

  Future<void> _loadMembers() async {
    try {
      final list = await ref.read(osRepositoryProvider).listMembers();
      if (mounted) {
        setState(() => _members = {for (final m in list) m.id: m.name});
      }
    } catch (_) {
      // best-effort: sem nomes, cai em "—" no rótulo.
    }
  }

  String _resp(ServiceOrder o) {
    final id = o.assignedTo;
    if (id == null || id.isEmpty) return 'Sem responsável';
    return _members[id] ?? '—';
  }

  String _label(ServiceOrder o) => '${o.number} — ${_resp(o)}';

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ServiceOrder>(
      displayStringForOption: _label,
      optionsBuilder: (value) async {
        final q = value.text.trim();
        // Se já há uma OS escolhida e o texto é o rótulo dela, não reabre a lista.
        if (widget.selected != null && q == _label(widget.selected!)) {
          return const Iterable<ServiceOrder>.empty();
        }
        try {
          final page = await ref.read(osRepositoryProvider).listOrders(
                q: q.isEmpty ? null : q,
                sort: 'recent',
                page: 1,
              );
          return page.items; // backend já limita a 20
        } catch (_) {
          return const Iterable<ServiceOrder>.empty();
        }
      },
      onSelected: (o) {
        FocusManager.instance.primaryFocus?.unfocus();
        widget.onChanged(o);
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        _ctrl = controller;
        if (!identical(_watchedNode, focusNode)) {
          _watchedNode?.removeListener(_onFocusMaybeOpen);
          _watchedNode = focusNode;
          focusNode.addListener(_onFocusMaybeOpen);
        }
        final neu = context.neu;
        return _FieldShell(
          label: 'OS — busque por nº, cliente ou responsável',
          helper: 'Recebimento aponta para a OS',
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Digite para buscar',
              hintStyle: TextStyle(color: neu.inkFaint),
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 20, color: neu.inkMuted),
              suffixIcon: widget.selected != null
                  ? IconButton(
                      tooltip: 'Trocar OS',
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: neu.inkMuted),
                      onPressed: () {
                        controller.clear();
                        widget.onChanged(null);
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              // Digitar de novo invalida a seleção anterior até escolher outra.
              if (widget.selected != null && v != _label(widget.selected!)) {
                widget.onChanged(null);
              }
            },
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final neu = context.neu;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: neu.surface,
            elevation: 6,
            shadowColor: neu.shadowDark,
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 360),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: neu.line),
                itemBuilder: (_, i) {
                  final o = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(
                      _label(o),
                      style: TextStyle(
                          color: neu.ink, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${o.customerName ?? '—'} · ${formatMoney(o.total)}',
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                    trailing: PaymentTag(status: o.paymentStatus, dense: true),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
