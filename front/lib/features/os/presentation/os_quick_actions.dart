import 'package:flutter/material.dart';
import '../../../core/vertical/vertical_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/pdf/document_company.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/cnpj.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../cashier/presentation/entry_edit_dialogs.dart';
import '../../invoice/presentation/invoice_providers.dart';
import '../domain/os_models.dart';
import 'os_pdf.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Lógica de transição/exportação COMPARTILHADA entre o seletor de 3 botões
/// da ficha e as ações rápidas do card da lista — a MESMA regra, um lugar só,
/// pra não divergir (ex.: confirmação de cancelar/entregar, oferta de NF).

/// Se um toque em [destino] resultaria numa ação de verdade (caminho real na
/// FSM) E o usuário tem permissão para ela.
bool osSimpleTransitionEnabled(
  ServiceOrder order,
  OsSimpleStatus destino, {
  required bool canWrite,
  required bool canApprove,
}) {
  if (!canWrite) return false;
  final path = osCaminhoAte(order.status, destino);
  if (path == null || path.isEmpty) return false;
  // Chegar aqui com destino "Em andamento" só acontece a partir de uma OS
  // FECHADA (cancelada ou finalizada) — se já estivesse em andamento, o caminho
  // teria vindo vazio. Ou seja: é sempre uma REABERTURA, e reabrir é
  // privilegiado, como no backend.
  if (destino == OsSimpleStatus.emAndamento) return canApprove;
  return true;
}

/// Executa a transição de [order] para [destino] pelo caminho mais curto da
/// FSM, com confirmação quando o último passo é sensível (cancelar) e, ao
/// chegar em "entregue", avisa o que sobrou a receber (e, se ainda não houver
/// nota, oferece emitir a NF). Invalida `orderProvider` e `orderListProvider`
/// ao final. Retorna sem fazer nada se não houver caminho alcançável (o
/// chamador deve ter verificado [osSimpleTransitionEnabled]).
///
/// Sem confirmação para "entregar": era um passo isolado sem sentido próprio
/// ("Confirmar entrega?" não perguntava nada de real).
///
/// **Finalizar NÃO abre mais o recebimento.** Antes abria, e o diálogo de
/// "Receber" caía na tela com o valor obrigatório em vermelho — quem finaliza
/// uma OS que só será paga depois (órgão público, faturamento a prazo) lia
/// aquilo como "não dá pra concluir sem cobrar" e abandonava a OS. Dinheiro é
/// assunto do **Caixa**: a OS fica com saldo em aberto, aparece no histórico e
/// no fiado, e se recebe por lá.
///
/// [onWillApply], se informado, é chamado só depois que qualquer confirmação
/// foi aceita — ou seja, exatamente quando a mutação de verdade está prestes
/// a começar. É o gancho certo pra ligar um spinner: ligá-lo ANTES disso
/// deixaria um `CircularProgressIndicator` (indeterminado, anima pra sempre)
/// visível enquanto o diálogo de confirmação ainda está na tela.
Future<void> runOsSimpleTransition(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order,
  OsSimpleStatus destino, {
  VoidCallback? onWillApply,
}) async {
  final path = osCaminhoAte(order.status, destino);
  if (path == null || path.isEmpty) return;
  final ultimo = path.last;

  if (ultimo == 'cancelada') {
    final ok = await showNeuConfirm(
      context,
      title: 'Cancelar OS?',
      message:
          'A OS ${order.number} será cancelada e a edição bloqueada. '
          'Você poderá reabri-la depois, mas os dados param aqui.',
      confirmLabel: 'Cancelar OS',
    );
    if (!ok || !context.mounted) return;
  } else if (ultimo == 'em_execucao' &&
      osSimpleStatusOf(order.status) == OsSimpleStatus.finalizada) {
    // Reabrir uma OS já finalizada é o caminho de CORREÇÃO — e mexe em número
    // que talvez já tenha sido conferido. A confirmação diz exatamente o que
    // muda para ninguém reabrir achando que é só "ver de novo".
    final ok = await showNeuConfirm(
      context,
      title: 'Reabrir OS finalizada?',
      message:
          'A OS ${order.number} volta para "Em andamento" e fica editável de '
          'novo. Se você mudar itens ou valores, o faturamento desta OS muda '
          'junto. Finalize-a outra vez ao terminar a correção.',
      confirmLabel: 'Reabrir OS',
      danger: false,
      icon: Icons.lock_open_rounded,
    );
    if (!ok || !context.mounted) return;
  }

  onWillApply?.call();
  try {
    final repo = ref.read(osRepositoryProvider);
    for (final step in path) {
      await repo.changeStatus(order.id, step);
    }
    // O widget que chamou isto (ex.: o card na LISTA) pode ter sido
    // desmontado durante os awaits acima — ele nem sempre é o mesmo que
    // renderiza depois de `invalidate` (a lista pode reordenar/filtrar o
    // item pra fora). Tocar `ref` num widget desmontado lança
    // "Bad state: ... used after ... disposed" — daí o guard ANTES de cada
    // uso de `ref`/`context`, não só no fim da função.
    if (!context.mounted) return;
    ref.invalidate(orderProvider(order.id));
    ref.invalidate(orderListProvider);
    if (ultimo == 'entregue') {
      _avisarSaldoEmAberto(context, order);
      if (context.mounted) await _offerInvoiceIfNeeded(context, ref, order);
    }
  } on AppException catch (e) {
    if (!context.mounted) return;
    ref.invalidate(orderProvider(order.id)); // reflete progresso parcial
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Avisa, ao finalizar, que a OS ficou com saldo em aberto — e diz ONDE se
/// recebe, com o atalho pronto.
///
/// Isto substitui o diálogo de cobrança que abria sozinho aqui. O objetivo é o
/// oposto do anterior: deixar explícito que finalizar sem receber é um caminho
/// normal e completo, não um passo pela metade.
void _avisarSaldoEmAberto(BuildContext context, ServiceOrder order) {
  final saldo = order.payment?.balance ?? 0;
  if (saldo <= 0) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'OS ${order.number} finalizada. Ficaram ${money(saldo.toString())} '
        'em aberto — receba pelo Caixa quando o cliente pagar.',
      ),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Ir ao Caixa',
        onPressed: () => context.go('/m/cashier'),
      ),
    ),
  );
}

/// Se há QUALQUER pagamento lançado para esta OS (mesmo já quitada) E o
/// usuário pode ao menos VER o caixa — usado para decidir se o botão
/// "Pagamentos" (histórico + estorno) aparece.
bool canViewOsPayments(WidgetRef ref, ServiceOrder order) {
  if ((order.payment?.paid ?? 0) <= 0) return false;
  final me = ref.read(sessionControllerProvider).meOrNull;
  return (me?.hasModule('cashier') ?? false) &&
      (me?.hasPermission('cashier.read') ?? false);
}

/// Lista os pagamentos já lançados para a OS, com a opção de ESTORNAR — o
/// "estado de reversão" que uma OS paga também precisa: cliente deu calote,
/// pagamento foi lançado errado, etc. Como o status de pagamento é 100%
/// derivado do caixa (nenhuma coluna própria na OS), estornar aqui já
/// devolve a OS pra "a receber"/"parcial" automaticamente — o status de
/// ANDAMENTO da OS (Finalizada) não muda, só o de pagamento.
Future<void> showOsPaymentsDialog(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order,
) async {
  if (!canViewOsPayments(ref, order)) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _OsPaymentsDialog(order: order),
  );
  if (!context.mounted) return;
  ref.invalidate(orderProvider(order.id));
  ref.invalidate(orderListProvider);
}

class _OsPaymentsDialog extends ConsumerStatefulWidget {
  const _OsPaymentsDialog({required this.order});
  final ServiceOrder order;

  @override
  ConsumerState<_OsPaymentsDialog> createState() => _OsPaymentsDialogState();
}

class _OsPaymentsDialogState extends ConsumerState<_OsPaymentsDialog> {
  PaymentDetail? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _detail = null;
      _error = null;
    });
    try {
      final detail = await ref.read(cashierRepositoryProvider).paymentSummary(
            saleKind: 'os',
            saleId: widget.order.id,
            total: moneyToDouble(widget.order.total),
          );
      if (mounted) setState(() => _detail = detail);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _estornar(CashEntry entry) async {
    final ok = await showReverseEntryDialog(context, ref, entry);
    if (ok && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final canManage =
        ref.read(sessionControllerProvider).meOrNull?.hasPermission('cashier.manage') ??
            false;
    return NeuDialog(
      title: 'Pagamentos — ${widget.order.number}',
      maxWidth: 460,
      child: _error != null
          ? Text(
              'Não foi possível carregar os pagamentos.',
              style: TextStyle(color: neu.danger),
            )
          : _detail == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in _detail!.entries) ...[
                      _PagamentoRow(
                        entry: e,
                        canManage: canManage,
                        onEstornar: () => _estornar(e),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_detail!.entries.isEmpty)
                      Text(
                        'Nenhum pagamento lançado.',
                        style: TextStyle(color: neu.inkMuted),
                      ),
                  ],
                ),
    );
  }
}

class _PagamentoRow extends StatelessWidget {
  const _PagamentoRow({
    required this.entry,
    required this.canManage,
    required this.onEstornar,
  });

  final CashEntry entry;
  final bool canManage;
  final VoidCallback onEstornar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final estornado = entry.reversedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: neu.base,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoney(entry.amount),
                  style: TextStyle(
                    color: estornado ? neu.inkMuted : neu.ink,
                    fontWeight: FontWeight.w800,
                    decoration: estornado ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    ?fmtDataHora(entry.createdAt),
                    methodLabel(entry.method),
                  ].where((t) => t.isNotEmpty).join(' · '),
                  style: TextStyle(color: neu.inkFaint, fontSize: 12),
                ),
              ],
            ),
          ),
          if (estornado)
            Text(
              'Estornado',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (canManage)
            NeuButton(
              label: 'Estornar',
              icon: Icons.undo_rounded,
              kind: NeuButtonKind.danger,
              onPressed: onEstornar,
            ),
        ],
      ),
    );
  }
}

Future<void> _offerInvoiceIfNeeded(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order,
) async {
  if (!kInvoiceEnabled) return;
  final me = ref.read(sessionControllerProvider).meOrNull;
  if (!((me?.hasModule('invoice') ?? false) &&
      (me?.hasPermission('invoice.issue') ?? false))) {
    return;
  }
  try {
    final page = await ref.read(invoiceRepositoryProvider).list(orderId: order.id);
    final hasActive = page.items.any(
      (i) =>
          i.status == 'draft' ||
          i.status == 'processing' ||
          i.status == 'authorized',
    );
    if (hasActive || !context.mounted) return;
  } on AppException {
    return; // falha ao consultar não interrompe o fluxo da OS
  }
  final go = await showNeuConfirm(
    context,
    title: 'Emitir nota fiscal?',
    message:
        'A OS ${order.number} foi finalizada. Deseja emitir a nota fiscal '
        'agora?',
    confirmLabel: 'Emitir nota',
    cancelLabel: 'Agora não',
    danger: false,
    icon: Icons.receipt_long_outlined,
  );
  if (!go || !context.mounted) return;
  try {
    final inv = await ref.read(invoiceRepositoryProvider).issue(orderId: order.id);
    if (!context.mounted) return;
    ref.invalidate(orderInvoicesProvider(order.id));
    context.go('/m/invoice/${inv.id}');
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Empresa para o PDF (Configurações › Empresa, com logo). Falha de leitura
/// cai pro básico do tenant ativo — o documento sai com menos dados no topo
/// em vez de não sair.
Future<DocumentCompany?> _companyForPdf(WidgetRef ref) async {
  try {
    return await ref.read(companyForDocumentsProvider.future);
  } on Object {
    final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
    if (t == null) return null;
    return DocumentCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }
}

/// Exporta a OS [orderId] em PDF direto para arquivo — usado tanto pelo card
/// da lista (que só tem o resumo, sem itens) quanto de qualquer outro lugar
/// que não já tenha a OS completa em mãos: busca o detalhe primeiro, pois o
/// PDF precisa dos itens (peças/serviços), que a listagem não traz.
Future<void> exportOsPdfById(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  try {
    final order = await ref.read(osRepositoryProvider).getOrder(orderId);
    final company = await _companyForPdf(ref);
    final bytes = await buildOsPdf(order, PdfPageFormat.a4,
        company: company, objetoLabel: ref.read(vocabProvider)['objeto.singular'] ?? 'Objeto',);
    final nome =
        'OS-${order.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}.pdf';
    await downloadBytes(bytes, nome, 'application/pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exportado: $nome')));
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    }
  }
}
