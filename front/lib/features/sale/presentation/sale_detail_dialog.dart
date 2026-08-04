import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../cashier/presentation/entry_edit_dialogs.dart';
import '../../os/presentation/payment_status.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../customers/domain/customers_models.dart';
import '../../customers/presentation/customers_providers.dart';
import '../domain/sale_models.dart';
import 'sale_pdf.dart';
import 'sale_create_dialog.dart';
import 'sale_providers.dart';

/// Detalhe de uma venda de balcão: tudo que foi vendido, o que já foi recebido e
/// as ações possíveis.
///
/// O histórico do caixa mostrava só o lançamento de dinheiro ("Venda avulsa ·
/// R$ 150"), sem dizer o que foi vendido nem permitir agir. Este diálogo é o
/// destino do toque naquela linha.
///
/// EDITAR altera itens, quantidade e desconto: o total é recalculado no servidor
/// e o estoque reconciliado (devolve o que as linhas antigas consumiram, consome
/// o que as novas pedem). Duas coisas a edição não pode fazer, e o servidor
/// recusa: mexer no valor depois de EMITIR A NOTA (a NF passaria a divergir) ou
/// baixar o total abaixo do que o cliente já PAGOU (ficaríamos devendo troco).
/// Nesses casos o caminho é CANCELAR e REFAZER — auditado, estorna o estoque e
/// abre a nova já preenchida. "Excluir" também é cancelar: o projeto não faz hard
/// delete em nenhum módulo.
Future<void> showSaleDetailDialog(
  BuildContext context, {
  required String saleId,
}) {
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: 'Venda',
      maxWidth: 560,
      child: _SaleDetail(saleId: saleId),
    ),
  );
}

/// Venda + resumo de pagamento, buscados juntos.
final _saleDetailProvider =
    FutureProvider.autoDispose.family<({Sale sale, PaymentDetail? payment}), String>(
        (ref, saleId) async {
  final sale = await ref.read(saleRepositoryProvider).getSale(saleId);
  PaymentDetail? payment;
  try {
    // O caixa não conhece o total da venda — quem sabe é a venda (regra
    // "aponta, não invade"), então passamos o total daqui.
    payment = await ref.read(cashierRepositoryProvider).paymentSummary(
          saleKind: 'sale',
          saleId: saleId,
          total: moneyToDouble(sale.total),
        );
  } catch (_) {
    // Sem o resumo (caixa indisponível) o detalhe ainda vale: mostra os itens.
  }
  return (sale: sale, payment: payment);
});

class _SaleDetail extends ConsumerWidget {
  const _SaleDetail({required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(_saleDetailProvider(saleId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: neu.danger, size: 28),
            const SizedBox(height: 10),
            Text('$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              onPressed: () => ref.invalidate(_saleDetailProvider(saleId)),
            ),
          ],
        ),
      ),
      data: (d) => _Corpo(sale: d.sale, payment: d.payment),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.sale, required this.payment});

  final Sale sale;
  final PaymentDetail? payment;

  bool _canWriteSale(WidgetRef ref) {
    final me = ref.read(sessionControllerProvider).meOrNull;
    return me?.hasPermission('sale.write') ?? false;
  }

  /// Corrigir/estornar recebimento é gestão do caixa, não permissão de venda.
  bool _canManageCashier(WidgetRef ref) {
    final me = ref.read(sessionControllerProvider).meOrNull;
    return me?.hasPermission('cashier.manage') ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final cancelada = sale.status == 'canceled';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho: número, data, cliente e situação.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.number.isEmpty ? 'Venda' : 'Venda ${sale.number}',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      ?_fmtData(sale.createdAt),
                      sale.customerName ?? 'Sem cliente',
                    ].join(' · '),
                    style: TextStyle(color: neu.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (cancelada)
              NeuStatusChip(
                label: 'Cancelada',
                color: neu.danger,
                tint: neu.dangerTint,
                icon: Icons.block,
              )
            else
              PaymentTag(status: sale.paymentStatus, dense: true),
          ],
        ),
        const SizedBox(height: 16),

        // O que foi vendido — o "expandir" que faltava no histórico.
        Text(
          'Itens',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (final i in sale.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Icon(
                        i.kind == 'service'
                            ? Icons.handyman_outlined
                            : Icons.inventory_2_outlined,
                        size: 14,
                        color: neu.inkFaint,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          i.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: neu.ink, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        '${_qtd(i.quantity)} × ${formatMoney(i.unitPrice)}',
                        style: TextStyle(color: neu.inkMuted, fontSize: 11.5),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 78,
                        child: Text(
                          formatMoney(i.subtotal),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 14, color: neu.line),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(sale.total),
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Recebimentos: quanto entrou, quando e por qual forma.
        if (payment != null) ...[
          const SizedBox(height: 16),
          _Pagamentos(
            payment: payment!,
            cancelada: cancelada,
            canManage: _canManageCashier(ref),
          ),
        ],

        // Exportar vale SEMPRE: é leitura, e o comprovante de uma venda
        // cancelada também precisa poder ser reimpresso.
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _BotaoExportar(sale: sale, payment: payment),
        ),

        // Ações. Venda cancelada não se cancela de novo.
        if (!cancelada && _canWriteSale(ref)) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              NeuButton(
                label: 'Cancelar venda',
                kind: NeuButtonKind.danger,
                icon: Icons.block,
                onPressed: () => _cancelar(context, ref, refazer: false),
              ),
              // Trocar o cliente é a única edição que NÃO mexe em dinheiro — e
              // é a que resolve o fiado lançado sem identificar quem levou, que
              // de outro modo fica preso em "Sem cliente" e ninguém cobra.
              NeuButton(
                label: sale.customerId == null
                    ? 'Identificar cliente'
                    : 'Trocar cliente',
                kind: NeuButtonKind.secondary,
                icon: Icons.person_outline,
                onPressed: () => _trocarCliente(context, ref),
              ),
              NeuButton(
                label: 'Editar itens',
                icon: Icons.edit_outlined,
                onPressed: () => _editarItens(context, ref),
              ),
              NeuButton(
                label: 'Cancelar e refazer',
                kind: NeuButtonKind.secondary,
                icon: Icons.restart_alt_rounded,
                onPressed: () => _cancelar(context, ref, refazer: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Editar altera itens, quantidade e desconto — o total é recalculado '
            'e o estoque reconciliado. Não é possível editar depois de emitir a '
            'nota, nem baixar o total abaixo do que o cliente já pagou; nesses '
            'casos, cancele e refaça.',
            style: TextStyle(color: neu.inkFaint, fontSize: 11, height: 1.35),
          ),
        ],
      ],
    );
  }

  /// Reatribui a venda a outro cliente. Não mexe em dinheiro — por isso é uma
  /// edição direta, e não cancelar-e-refazer.
  Future<void> _trocarCliente(BuildContext context, WidgetRef ref) async {
    final escolhido = await showCustomerPicker(context);
    if (escolhido == null || !context.mounted) return;
    try {
      await ref
          .read(saleRepositoryProvider)
          .updateSale(sale.id, customerId: escolhido.id);
      // O fiado é agrupado por cliente: sem invalidar, a carteira continuaria
      // mostrando a dívida no balde antigo.
      ref.invalidate(_saleDetailProvider(sale.id));
      ref.invalidate(cashierControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venda atribuída a ${escolhido.name}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Abre a venda para editar os itens (mesma tela da criação, já preenchida).
  /// O servidor recalcula o total, reconcilia o estoque e recusa o que quebraria
  /// nota emitida ou pagamento já feito.
  Future<void> _editarItens(BuildContext context, WidgetRef ref) async {
    final atualizada = await showSaleEditDialog(context, sale);
    if (atualizada == null || !context.mounted) return;
    // O total mudou: o detalhe, o caixa e a carteira de fiado precisam refletir.
    ref.invalidate(_saleDetailProvider(sale.id));
    ref.invalidate(cashierControllerProvider);
  }

  /// Cancela com motivo obrigatório e, quando [refazer], abre a nova venda já
  /// preenchida com os itens desta.
  Future<void> _cancelar(
    BuildContext context,
    WidgetRef ref, {
    required bool refazer,
  }) async {
    final motivo = await _pedirMotivo(context, refazer: refazer);
    if (motivo == null || !context.mounted) return;
    try {
      await ref.read(saleRepositoryProvider).cancelSale(sale.id, reason: motivo);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: context.neu.danger),
        );
      }
      return;
    }
    // O caixa e a carteira de fiado mudaram (estorno do recebimento/saldo).
    ref.invalidate(cashierControllerProvider);
    ref.invalidate(_saleDetailProvider(sale.id));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!refazer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venda ${sale.number} cancelada.'),
          backgroundColor: context.neu.success,
        ),
      );
      return;
    }
    await showSaleCreateDialog(context, refazerDe: sale.items);
  }

  Future<String?> _pedirMotivo(
    BuildContext context, {
    required bool refazer,
  }) async {
    final ctrl = TextEditingController(
      text: refazer ? 'Correção de lançamento' : '',
    );
    final ok = await showNeuDialog<bool>(
      context,
      dialog: NeuDialog(
        title: refazer ? 'Corrigir venda' : 'Cancelar venda',
        maxWidth: 420,
        actions: [
          Builder(
            builder: (ctx) => NeuButton(
              label: 'Voltar',
              kind: NeuButtonKind.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
          Builder(
            builder: (ctx) => NeuButton(
              label: refazer ? 'Cancelar e refazer' : 'Cancelar venda',
              kind: NeuButtonKind.danger,
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
                  refazer
                      ? 'A venda ${sale.number} será cancelada (estoque '
                          'estornado) e uma nova abrirá com os mesmos itens.'
                      : 'A venda ${sale.number} será cancelada e o estoque '
                          'estornado. O registro permanece no histórico.',
                  style: TextStyle(
                      color: neu.inkMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                NeuTextField(
                  label: 'Motivo *',
                  controller: ctrl,
                  hint: 'Por que está cancelando?',
                  maxLength: 200,
                ),
              ],
            );
          },
        ),
      ),
    );
    if (ok != true) return null;
    final motivo = ctrl.text.trim();
    // O backend exige no mínimo 3 caracteres; evita ida perdida ao servidor.
    if (motivo.length < 3) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Descreva o motivo (mínimo 3 letras).'),
            backgroundColor: context.neu.danger,
          ),
        );
      }
      return null;
    }
    return motivo;
  }
}

/// Recebimentos da venda: total, pago, saldo e cada lançamento do caixa —
/// com as ações de cada um.
///
/// As ações vivem AQUI (e não mais nos três pontinhos da linha do extrato)
/// porque é aqui que o recebimento tem contexto: ao lado do total da venda e do
/// que falta. No Caixa do dia a linha da venda abre este diálogo; no Histórico o
/// recebimento é deduplicado no cartão da venda, que também abre aqui.
class _Pagamentos extends StatelessWidget {
  const _Pagamentos({
    required this.payment,
    required this.cancelada,
    this.canManage = false,
  });

  final PaymentDetail payment;
  final bool cancelada;

  /// `cashier.manage` — libera corrigir/estornar o recebimento.
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recebimentos',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  _stat(neu, 'Pago', payment.paid, neu.success),
                  _stat(
                    neu,
                    cancelada ? 'Saldo' : 'A receber',
                    payment.balance,
                    payment.balance > 0 ? neu.warning : neu.inkMuted,
                  ),
                ],
              ),
              if (payment.entries.isNotEmpty) ...[
                Divider(height: 16, color: neu.line),
                for (final e in payment.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              ?_fmtData(e.createdAt),
                              methodLabel(e.method),
                            ].join(' · '),
                            style:
                                TextStyle(color: neu.inkMuted, fontSize: 11.5),
                          ),
                        ),
                        Text(
                          formatMoney(e.amount),
                          style: TextStyle(
                            color: e.reversedAt != null
                                ? neu.inkFaint
                                : neu.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: e.reversedAt != null
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        // Recebeu o valor errado? Corrigir estorna e relança —
                        // sem isto, tirar o menu da linha do extrato deixaria a
                        // correção do recebimento sem porta nenhuma.
                        if (canManage && e.reversedAt == null)
                          EntryActionsMenu(entry: e),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(NeuTokens neu, String label, num value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(
            formatMoney(value),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// "03/08 14:32" (local), ou null quando não há data.
String? _fmtData(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Quantidade sem casas decimais inúteis ("4" em vez de "4,000").
String _qtd(String raw) {
  final v = double.tryParse(raw.replaceAll(',', '.'));
  if (v == null) return raw;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}


/// Botão de exportar o comprovante da venda em PDF.
///
/// Widget próprio porque tem estado (o "gerando…") e porque monta o documento
/// com dados de TRÊS fontes: a venda, a ficha do cliente (CNPJ/endereço, que a
/// venda não guarda) e os recebimentos do caixa (forma de pagamento).
class _BotaoExportar extends ConsumerStatefulWidget {
  const _BotaoExportar({required this.sale, required this.payment});

  final Sale sale;
  final PaymentDetail? payment;

  @override
  ConsumerState<_BotaoExportar> createState() => _BotaoExportarState();
}

class _BotaoExportarState extends ConsumerState<_BotaoExportar> {
  bool _gerando = false;

  Future<void> _exportar() async {
    setState(() => _gerando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sale = widget.sale;
      final company = await ref.read(companyForDocumentsProvider.future);

      // Ficha do cliente: é dela que vêm CNPJ, telefone e endereço do bloco
      // "Dados do cliente". Best-effort — venda sem cliente (consumidor não
      // identificado) é caso normal, e falha aqui não impede o comprovante.
      Customer? cliente;
      final id = sale.customerId;
      if (id != null && id.isNotEmpty) {
        try {
          cliente = await ref.read(customerProvider(id).future);
        } on Object {
          cliente = null;
        }
      }

      // Formas de pagamento = recebimentos do caixa apontando para esta venda.
      // Estornados ficam de fora: não entraram no caixa.
      final entradas = (widget.payment?.entries ?? const <CashEntry>[])
          .where((e) => e.direction == 'in' && e.reversedAt == null);
      final pagamentos = [
        for (final e in entradas)
          (label: methodLabel(e.method), valor: moneyToDouble(e.amount)),
      ];

      final bytes = await buildSalePdf(
        sale,
        PdfPageFormat.a4,
        company: company,
        extras: SaleReceiptExtras(customer: cliente, pagamentos: pagamentos),
      );
      final numero = sale.number.isEmpty
          ? sale.id.substring(0, 8)
          : sale.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
      final nome = 'venda-$numero.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      messenger.showSnackBar(SnackBar(content: Text('PDF exportado: $nome')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      label: 'Exportar PDF',
      icon: Icons.picture_as_pdf_outlined,
      kind: NeuButtonKind.secondary,
      loading: _gerando,
      onPressed: _gerando ? null : _exportar,
    );
  }
}
