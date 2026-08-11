import 'package:flutter/material.dart';
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
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../invoice/presentation/invoice_providers.dart';
import '../../receivables/domain/receivables_models.dart';
import '../../receivables/presentation/receive_title_dialog.dart';
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
  // Reabrir uma OS cancelada é privilegiado — espelha o backend.
  if (destino == OsSimpleStatus.emAndamento && order.status == 'cancelada') {
    return canApprove;
  }
  return true;
}

/// Executa a transição de [order] para [destino] pelo caminho mais curto da
/// FSM, com confirmação quando o último passo é sensível (cancelar) e, ao
/// chegar em "entregue", oferece receber o pagamento em aberto (e, se ainda
/// não houver nota, emitir a NF). Invalida `orderProvider` e
/// `orderListProvider` ao final. Retorna sem fazer nada se não houver caminho
/// alcançável (o chamador deve ter verificado [osSimpleTransitionEnabled]).
///
/// Sem confirmação para "entregar": era um passo isolado sem sentido próprio
/// ("Confirmar entrega?" não perguntava nada de real) — o que importa de
/// verdade ao finalizar é o pagamento, e esse SIM tem seu próprio diálogo.
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
  }

  onWillApply?.call();
  try {
    final repo = ref.read(osRepositoryProvider);
    for (final step in path) {
      await repo.changeStatus(order.id, step);
    }
    ref.invalidate(orderProvider(order.id));
    ref.invalidate(orderListProvider);
    if (context.mounted && ultimo == 'entregue') {
      // Pagamento primeiro (o cliente costuma estar ali, na hora) — a NF
      // (quando ligada) vem depois, é secundária nesse momento.
      await offerOsPayment(context, ref, order);
      if (context.mounted) await _offerInvoiceIfNeeded(context, ref, order);
    }
  } on AppException catch (e) {
    ref.invalidate(orderProvider(order.id)); // reflete progresso parcial
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Se a OS tem saldo em aberto E o usuário pode lançar recebimento no caixa —
/// usado tanto para decidir se oferece o diálogo ao finalizar quanto para
/// mostrar (ou não) o botão "Receber pagamento" permanente na ficha.
bool canReceiveOsPayment(WidgetRef ref, ServiceOrder order) {
  final saldo = order.payment?.balance ?? 0;
  if (saldo <= 0) return false;
  final me = ref.read(sessionControllerProvider).meOrNull;
  return (me?.hasModule('cashier') ?? false) &&
      (me?.hasPermission('cashier.write') ?? false);
}

/// Abre o MESMO diálogo de recebimento que a aba Fiado usa — "integrar com o
/// caixa" é isto: nenhuma lógica de pagamento nova, só o mesmo caminho que já
/// existe pra vendas, agora alcançável direto da OS. Aceita parcial (o saldo
/// que sobra volta a aparecer como fiado) ou o total (a OS vira "Paga").
Future<void> offerOsPayment(
  BuildContext context,
  WidgetRef ref,
  ServiceOrder order,
) async {
  if (!canReceiveOsPayment(ref, order)) return;
  final payment = order.payment!;
  CashierConfig config;
  try {
    config = (await ref.read(cashierControllerProvider.future)).config;
  } on Object {
    return; // caixa indisponível não deve travar o fluxo da OS
  }
  if (!context.mounted) return;
  final title = ReceivableTitle(
    id: order.id,
    origin: 'os',
    number: order.number,
    createdAt: order.createdAt,
    total: payment.total,
    paid: payment.paid,
    balance: payment.balance,
    status: payment.status,
  );
  await showReceiveTitleDialog(context, ref, config: config, title: title);
  ref.invalidate(orderProvider(order.id));
  ref.invalidate(orderListProvider);
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
    ref.invalidate(orderInvoicesProvider(order.id));
    if (context.mounted) context.go('/m/invoice/${inv.id}');
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
    final bytes = await buildOsPdf(order, PdfPageFormat.a4, company: company);
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
