import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/os_models.dart';
import '../item_picker_dialog.dart';
import '../os_providers.dart';
import '../os_status.dart';
import '../template_picker_dialog.dart';
import 'os_detail_shared.dart';

/// Aba **Itens**: o que a oficina está cobrando, separado em **Serviços** (mão
/// de obra) e **Peças** (o que saiu do estoque).
///
/// A separação não é enfeite: são duas naturezas de lançamento com origens
/// diferentes — serviço é tempo de alguém, peça é estoque que baixa — e a
/// pergunta "quanto disso é mão de obra?" é constante numa oficina. Numa lista
/// única ela exigia somar de cabeça.
///
/// O antigo card "Resumo financeiro" saiu: o TOTAL foi para o cabeçalho da OS
/// (sempre à vista, sem custar uma seção) e o que sobrava dele — subtotal por
/// grupo e desconto — passou a ser dito no lugar onde importa, junto de cada
/// grupo, em vez de num bloco separado que obrigava a correlacionar.
class OsItemsTab extends ConsumerWidget {
  const OsItemsTab({super.key, required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await ItemPickerDialog.show(context);
    if (draft == null) return;
    try {
      await ref.read(osRepositoryProvider).addItem(order.id, draft);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Aplica um template (pacote de peças e serviços) à OS. O backend expande os
  /// itens re-fotografando o preço corrente do estoque. O mesmo seletor oferece
  /// o caminho inverso — guardar o que ESTA OS tem como um template novo.
  Future<void> _aplicarTemplate(BuildContext context, WidgetRef ref) async {
    final template = await TemplatePickerDialog.show(
      context,
      qtdItensParaSalvar: order.items.length,
      onCriarTemplate: (nome) => _salvarComoTemplate(context, ref, nome),
    );
    if (template == null || !context.mounted) return;
    try {
      await ref.read(osRepositoryProvider).applyTemplate(order.id, template.id);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Guarda as peças e serviços desta OS como um template reaproveitável.
  /// Itens do estoque viram ponteiro (o preço é refotografado ao aplicar);
  /// avulsos guardam nome e preço.
  Future<void> _salvarComoTemplate(
    BuildContext context,
    WidgetRef ref,
    String nome,
  ) async {
    try {
      await ref.read(osRepositoryProvider).createTemplate(
            OsTemplateDraft(
              name: nome,
              items: [
                for (final i in order.items)
                  OsTemplateItemDraft(
                    kind: i.kind,
                    inventoryItemId: i.inventoryItemId,
                    name: i.inventoryItemId == null ? i.name : null,
                    quantity: double.tryParse(i.quantity),
                    unitPrice: double.tryParse(i.unitPrice),
                  ),
              ],
            ),
          );
      ref.invalidate(templateListProvider);
      if (context.mounted) {
        showNeuSuccessSnackBar(context, 'Template "$nome" salvo.');
      }
    } on AppException catch (e) {
      if (context.mounted) showNeuErrorSnackBar(context, e.message);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OrderItem item,
  ) async {
    final ok = await showNeuConfirm(
      context,
      title: 'Remover item?',
      message: 'Remover "${item.name}" desta OS? O total será recalculado.',
      confirmLabel: 'Remover',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(osRepositoryProvider).deleteItem(order.id, item.id);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicos =
        order.items.where((i) => i.kind == 'service').toList(growable: false);
    // Tudo que não é serviço conta como peça — um `kind` novo ou vazio vindo do
    // servidor aparece como peça em vez de sumir da tela sem aviso.
    final pecas =
        order.items.where((i) => i.kind != 'service').toList(growable: false);
    final desconto = double.tryParse(order.discount ?? '0') ?? 0;

    return OsSectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Peças e serviços',
      glyphIndex: 0,
      action: canWrite
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OsHeaderAction(
                  icon: Icons.checklist_rounded,
                  label: 'Template',
                  onTap: () => _aplicarTemplate(context, ref),
                ),
                OsHeaderAction(
                  icon: Icons.add_rounded,
                  label: 'Adicionar',
                  onTap: () => _add(context, ref),
                ),
              ],
            )
          : null,
      child: order.items.isEmpty
          ? OsInlineEmpty(
              icon: Icons.add_shopping_cart_outlined,
              text: 'Nenhum item ainda.',
              hint: 'Adicione peças do estoque ou serviços de mão de obra.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (servicos.isNotEmpty)
                  _Grupo(
                    titulo: 'Serviços',
                    icone: Icons.handyman_outlined,
                    itens: servicos,
                    order: order,
                    canWrite: canWrite,
                    onRemove: (item) => _remove(context, ref, item),
                  ),
                if (servicos.isNotEmpty && pecas.isNotEmpty)
                  const SizedBox(height: 16),
                if (pecas.isNotEmpty)
                  _Grupo(
                    titulo: 'Peças',
                    icone: Icons.inventory_2_outlined,
                    itens: pecas,
                    order: order,
                    canWrite: canWrite,
                    onRemove: (item) => _remove(context, ref, item),
                  ),
                // Desconto só aparece quando existe — era a única informação do
                // "Resumo financeiro" que não cabia no cabeçalho.
                if (desconto > 0) ...[
                  const SizedBox(height: 14),
                  _LinhaDesconto(valor: desconto),
                ],
              ],
            ),
    );
  }
}

/// Um grupo de itens (Serviços ou Peças) com contagem e subtotal no rótulo —
/// "quanto disso é mão de obra?" respondido sem somar de cabeça.
class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.titulo,
    required this.icone,
    required this.itens,
    required this.order,
    required this.canWrite,
    required this.onRemove,
  });

  final String titulo;
  final IconData icone;
  final List<OrderItem> itens;
  final ServiceOrder order;
  final bool canWrite;
  final ValueChanged<OrderItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final subtotal = itens.fold<double>(
      0,
      (acc, it) => acc + (double.tryParse(it.total) ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(icone, size: 15, color: neu.inkMuted),
              const SizedBox(width: 7),
              Text(
                titulo,
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${itens.length}',
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
              const Spacer(),
              Text(
                money(subtotal.toString()),
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < itens.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: neu.base,
                    indent: 14,
                    endIndent: 14,
                  ),
                _ItemRow(
                  order: order,
                  item: itens[i],
                  canWrite: canWrite,
                  onRemove: () => onRemove(itens[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Desconto da OS — abatimento sobre o conjunto, não sobre um grupo.
class _LinhaDesconto extends StatelessWidget {
  const _LinhaDesconto({required this.valor});
  final double valor;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        Icon(Icons.local_offer_outlined, size: 15, color: neu.warning),
        const SizedBox(width: 7),
        Text(
          'Desconto da OS',
          style: TextStyle(color: neu.inkMuted, fontSize: 13),
        ),
        const Spacer(),
        Text(
          '- ${money(valor.toString())}',
          style: TextStyle(
            color: neu.warning,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.order,
    required this.item,
    required this.canWrite,
    required this.onRemove,
  });

  final ServiceOrder order;
  final OrderItem item;
  final bool canWrite;
  final VoidCallback onRemove;

  Future<void> _editQty(
    BuildContext context,
    WidgetRef ref,
    OrderItemPatch patch,
  ) async {
    try {
      await ref.read(osRepositoryProvider).updateItem(order.id, item.id, patch);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final isService = item.kind == 'service';
    final disc = double.tryParse(item.discount) ?? 0;
    final detail = [
      '${item.quantity} × ${money(item.unitPrice)}',
      if (disc > 0) '- ${money(item.discount)}',
    ].join('  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(
            isService
                ? Icons.design_services_outlined
                : Icons.inventory_2_outlined,
            size: 20,
            color: neu.inkMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(color: neu.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: neu.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(item.total),
            style: TextStyle(color: neu.ink, fontWeight: FontWeight.w800),
          ),
          if (canWrite) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Mais ações',
              onSelected: (action) async {
                if (action == 'editar') {
                  final patch = await _ItemEditDialog.show(context, item);
                  if (patch != null && context.mounted) {
                    await _editQty(context, ref, patch);
                  }
                } else if (action == 'remover') {
                  onRemove();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remover',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: Text(
                      'Remover',
                      style: TextStyle(color: AppColors.danger),
                    ),
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

/// Dialog enxuto para editar qtd/preço/desconto de um item.
class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({required this.item});
  final OrderItem item;

  static Future<OrderItemPatch?> show(BuildContext context, OrderItem item) {
    return showDialog<OrderItemPatch>(
      context: context,
      builder: (_) => _ItemEditDialog(item: item),
    );
  }

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _disc;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: _fmt(widget.item.quantity));
    _price = TextEditingController(text: _fmt(widget.item.unitPrice));
    _disc = TextEditingController(text: _fmt(widget.item.discount));
  }

  String _fmt(String s) {
    final v = double.tryParse(s);
    return v == null ? s : v.toString().replaceAll('.', ',');
  }

  double? _toDouble(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _disc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: widget.item.name,
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(
            OrderItemPatch(
              quantity: _toDouble(_qty.text),
              unitPrice: _toDouble(_price.text),
              discount: _toDouble(_disc.text),
            ),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantidade'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço unitário',
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _disc,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Desconto',
              prefixText: 'R\$ ',
            ),
          ),
        ],
      ),
    );
  }
}

