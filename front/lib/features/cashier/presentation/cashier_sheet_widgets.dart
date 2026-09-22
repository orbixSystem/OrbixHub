/// Widgets compartilhados entre os sheets do caixa (Receber, Fiado, etc.).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/payment_status.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';

/// Rótulo em cima + cavidade (inset).
class CashierFieldShell extends StatelessWidget {
  const CashierFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.padding,
  });

  final String label;
  final Widget child;
  final EdgeInsetsGeometry? padding;

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
      ],
    );
  }
}

/// Linha de saldo da OS (Total · Pago · A receber).
class CashierBalanceLine extends StatelessWidget {
  const CashierBalanceLine({super.key, required this.payment});
  final PaymentDetail payment;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    Widget stat(String label, num value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                formatMoney(value),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
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

/// Picker de OS (busca por número / cliente / responsável).
class CashierOsPickerField extends ConsumerStatefulWidget {
  const CashierOsPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.ref,
  });

  final ServiceOrder? selected;
  final ValueChanged<ServiceOrder?> onChanged;
  final WidgetRef ref;

  @override
  ConsumerState<CashierOsPickerField> createState() =>
      _CashierOsPickerFieldState();
}

class _CashierOsPickerFieldState extends ConsumerState<CashierOsPickerField> {
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
      final list = await widget.ref.read(osRepositoryProvider).listMembers();
      if (mounted) {
        setState(() => _members = {for (final m in list) m.id: m.name});
      }
    } catch (_) {}
  }

  String _memberName(ServiceOrder o) {
    final id = o.assignedTo;
    if (id == null || id.isEmpty) return 'Sem responsável';
    return _members[id] ?? '—';
  }

  String _label(ServiceOrder o) => '${o.number} — ${_memberName(o)}';

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ServiceOrder>(
      displayStringForOption: _label,
      optionsBuilder: (value) async {
        final q = value.text.trim();
        if (widget.selected != null && q == _label(widget.selected!)) {
          return const Iterable<ServiceOrder>.empty();
        }
        try {
          final page = await widget.ref.read(osRepositoryProvider).listOrders(
                q: q.isEmpty ? null : q,
                sort: 'recent',
                page: 1,
              );
          return page.items;
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
        return _OsSearchField(
          controller: controller,
          focusNode: focusNode,
          selected: widget.selected,
          onClear: () {
            controller.clear();
            widget.onChanged(null);
          },
          onChanged: (v) {
            if (widget.selected != null && v != _label(widget.selected!)) {
              widget.onChanged(null);
            }
          },
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
              constraints:
                  const BoxConstraints(maxHeight: 260, maxWidth: 360),
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
                    trailing:
                        PaymentTag(status: o.paymentStatus, dense: true),
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

/// Um "N x" com −/+ que NÃO se estica (sem `Expanded`) — cabe num [Wrap], que
/// quebra linha sozinho em telas estreitas. Os sheets antigos usavam duas
/// colunas fixas lado a lado (`Row` de dois `Expanded`) para parcelas/vencimento
/// e isso é o que estourava/espremia no celular; aqui cada stepper mede só o
/// que precisa e o `Wrap` do chamador decide se cabem lado a lado ou empilham.
class CashierStepperField extends StatelessWidget {
  const CashierStepperField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rChip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: onDecrement,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    color: neu.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OsSearchField extends StatelessWidget {
  const _OsSearchField({
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ServiceOrder? selected;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

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
            'OS — busque por nº, cliente ou responsável',
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
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(color: neu.ink, fontSize: 15),
            onChanged: onChanged,
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
              suffixIcon: selected != null
                  ? IconButton(
                      tooltip: 'Trocar OS',
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: neu.inkMuted),
                      onPressed: onClear,
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Text(
            'Aponta para a OS selecionada',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
