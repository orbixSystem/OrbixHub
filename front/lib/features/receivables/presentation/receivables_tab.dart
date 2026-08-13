import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../os/presentation/os_detail_dialog.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import '../domain/receivables_models.dart';
import 'receive_title_dialog.dart';
import 'receivables_providers.dart';

/// Aba "Fiado" do Caixa — controle de contas a receber.
///
/// Responde três perguntas, nesta ordem: quanto a oficina tem na rua, quem deve,
/// e o que exatamente cada um deve. O drill-down abre os títulos separados (cada
/// OS/venda com seus itens), porque "o João me deve R$ 680" só é acionável
/// quando se sabe de quais serviços.
///
/// RECEBER não é uma operação própria: é um lançamento no caixa apontando para a
/// venda/OS, que já aceita valor parcial — a mesma porta usada pelo "Receber OS".
class ReceivablesTab extends ConsumerWidget {
  const ReceivablesTab({super.key, required this.canWrite});

  /// `cashier.write` — sem isso a aba é só leitura (não oferece receber).
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline a carteira é DERIVADA do espelho local (OS + venda + recebimentos)
    // pelo `LocalFirstReceivablesRepository` — quem observa a conexão para
    // recarregar na virada é o próprio `debtorsProvider`.
    final async = ref.watch(debtorsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Erro(
        message: '$e',
        onRetry: () => ref.invalidate(debtorsProvider),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const NeuEmptyState(
            icon: Icons.handshake_outlined,
            title: 'Nenhum fiado em aberto',
            message: 'Vendas e OS com saldo a receber aparecem aqui, '
                'agrupadas por cliente.',
          );
        }
        return ListView(
          children: [
            _TotalNaRua(total: page.totalDue, devedores: page.items.length),
            if (page.truncated) ...[
              const SizedBox(height: 12),
              const _AvisoTruncado(),
            ],
            const SizedBox(height: 20),
            Text('Quem deve', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final d in page.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DebtorTile(debtor: d, canWrite: canWrite),
              ),
          ],
        );
      },
    );
  }
}

/// Quanto a oficina tem "na rua" — o número que o dono quer ver primeiro.
class _TotalNaRua extends StatelessWidget {
  const _TotalNaRua({required this.total, required this.devedores});

  final num total;
  final int devedores;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: neu.warningTint,
              borderRadius: BorderRadius.circular(NeuTokens.rField),
            ),
            child: Icon(Icons.handshake_outlined, color: neu.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A receber',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(total),
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  devedores == 1
                      ? 'de 1 cliente'
                      : 'de $devedores clientes',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A varredura do servidor bateu no teto: existe dívida fora desta lista. Dizer
/// isso é obrigatório — deixar o usuário achar que viu tudo seria pior.
class _AvisoTruncado extends StatelessWidget {
  const _AvisoTruncado();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: neu.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A carteira é grande e esta lista está parcial — há fiados '
              'não exibidos. Receba os títulos listados para revelar os '
              'demais.',
              style: TextStyle(color: neu.inkMuted, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Um devedor: nome, quanto deve, quantos títulos e desde quando. Toque abre os
/// títulos separados.
class _DebtorTile extends ConsumerWidget {
  const _DebtorTile({required this.debtor, required this.canWrite});

  final Debtor debtor;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final dias = _diasDesde(debtor.oldestAt);
    return NeuCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: () => showDebtorTitlesDialog(
          context,
          customerId: debtor.customerId,
          customerName: debtor.customerName,
          canWrite: canWrite,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        debtor.titleCount == 1
                            ? '1 título'
                            : '${debtor.titleCount} títulos',
                        ?dias,
                      ].join(' · '),
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(debtor.totalDue),
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: neu.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// "há N dias" a partir do título mais antigo. Sem vencimento no modelo, esta é
/// a única noção de tempo honesta — não é atraso, é idade da dívida.
String? _diasDesde(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final dias = DateTime.now().difference(d).inDays;
  if (dias <= 0) return 'de hoje';
  if (dias == 1) return 'há 1 dia';
  return 'há $dias dias';
}

/// Títulos em aberto de um cliente — cada OS/venda com seus itens e o botão de
/// receber. É onde se responde "de quais serviços é essa dívida".
Future<void> showDebtorTitlesDialog(
  BuildContext context, {
  required String? customerId,
  required String customerName,
  required bool canWrite,
}) {
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: customerName,
      maxWidth: 560,
      child: _DebtorTitles(
        customerId: customerId,
        canWrite: canWrite,
      ),
    ),
  );
}

class _DebtorTitles extends ConsumerWidget {
  const _DebtorTitles({required this.customerId, required this.canWrite});

  final String? customerId;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(debtorTitlesProvider(customerId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Erro(
        message: '$e',
        onRetry: () => ref.invalidate(debtorTitlesProvider(customerId)),
      ),
      data: (detail) {
        if (detail.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nada em aberto para este cliente.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Total em aberto',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
                const Spacer(),
                Text(
                  formatMoney(detail.totalDue),
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Mais antigo primeiro: é a ordem em que se cobra.
            for (final t in detail.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TitleCard(
                  title: t,
                  canWrite: canWrite,
                  customerId: customerId,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Um título em aberto: quanto deve, o caminho para o detalhe e UMA ação —
/// receber. Parcelar não é um segundo botão concorrendo aqui: é uma opção
/// dentro do recebimento (recebeu parte, programa o resto). Quando já existe
/// plano, o cronograma vira INFORMAÇÃO e o botão passa a quitar a próxima
/// parcela — um alvo só, sempre no mesmo lugar.
class _TitleCard extends ConsumerWidget {
  const _TitleCard({
    required this.title,
    required this.canWrite,
    required this.customerId,
  });

  final ReceivableTitle title;
  final bool canWrite;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final parcial = title.status == 'parcial';
    final rotulo = title.origin == 'os' ? title.number : 'Venda ${title.number}';
    // Plano de parcelas do título (vazio = não parcelado).
    final parcelas = ref
            .watch(installmentsProvider(
                (saleKind: title.origin, saleId: title.id)))
            .value ??
        const <Installment>[];
    // Cobra-se da mais antiga para a mais nova — não faz sentido quitar a 3ª
    // deixando a 1ª vencida para trás.
    final pendentes = parcelas.where((p) => p.paidAt == null).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final proxima = pendentes.isEmpty ? null : pendentes.first;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho INTEIRO clicável — abre o detalhe de verdade (a tela da
          // OS, com PDF, ou o diálogo da venda, com itens e recebimentos).
          // Antes só a venda tinha esse caminho; a OS parava aqui, obrigando a
          // sair do Fiado e procurar na lista de OS por conta própria. Os itens
          // saíram do card por isso: quem quer o detalhamento agora abre o
          // detalhe de verdade, em vez de uma cópia resumida dele aqui.
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NeuTokens.rField),
            ),
            onTap: () => _abrirDetalhe(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    title.origin == 'os'
                        ? Icons.build_outlined
                        : Icons.shopping_cart_outlined,
                    size: 16,
                    color: neu.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (parcial) ...[
                    NeuStatusChip(
                      label: 'Parcial',
                      color: neu.warning,
                      tint: neu.warningTint,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Ver detalhes',
                    style: TextStyle(
                      color: neu.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: neu.navy),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: neu.line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deve ${formatMoney(title.balance)}',
                            style: TextStyle(
                              color: neu.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (parcial)
                            Text(
                              'de ${formatMoney(title.total)} · já pagou '
                              '${formatMoney(title.paid)}',
                              style: TextStyle(
                                  color: neu.inkMuted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (canWrite && title.balance > 0)
                      NeuButton(
                        label: proxima == null ? 'Receber' : 'Receber parcela',
                        icon: Icons.payments_outlined,
                        onPressed: () => _receber(context, ref, proxima),
                      ),
                  ],
                ),
                // Cronograma como INFORMAÇÃO (o que vence e quando). Receber é
                // sempre pelo botão acima — uma fileira de botões, um por
                // parcela, era o que fazia esta tela parecer cheia de cliques.
                if (parcelas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ScheduleList(parcelas: parcelas),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abre o detalhe de VERDADE do título, sem tirar o operador do Fiado: os
  /// dois origins abrem em MODAL (a OS ganhou o seu, espelhando o da venda) —
  /// navegar para a tela da OS fazia perder a lista de cobrança.
  void _abrirDetalhe(BuildContext context) {
    if (title.origin == 'os') {
      showOsDetailDialog(context, orderId: title.id);
    } else {
      showSaleDetailDialog(context, saleId: title.id);
    }
  }

  /// Recebimento: lançamento no caixa apontando para a venda/OS. Reusa o mesmo
  /// diálogo do "Receber OS" — aceita parcial, oferece parcelar o que sobrar e,
  /// quando há plano, quita a parcela [proxima].
  Future<void> _receber(
    BuildContext context,
    WidgetRef ref,
    Installment? proxima,
  ) async {
    // ESPERA a config do caixa em vez de ler o valor corrente.
    //
    // `cashierControllerProvider` é `autoDispose`: aberto de dentro do diálogo
    // de títulos, ninguém o observa, então `ref.read(...).value` vem `null`
    // enquanto ele carrega — e o código antigo desistia calado ali. Para o
    // operador o botão "Receber" simplesmente não fazia nada, sem erro nem
    // spinner. Falhar em silêncio é pior que falhar: ninguém sabe o que
    // tentar em seguida.
    final CashierConfig config;
    try {
      config = (await ref.read(cashierControllerProvider.future)).config;
    } on Object catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, 'Não foi possível abrir o caixa: $e');
      }
      return;
    }
    if (!context.mounted) return;
    await showReceiveTitleDialog(
      context,
      ref,
      config: config,
      title: title,
      parcela: proxima,
    );
    if (!context.mounted) return;
    _refresh(ref);
  }

  /// O saldo/plano mudou: recarrega o cronograma, os títulos do cliente e a
  /// carteira — as três lentes derivam do mesmo espelho de lançamentos.
  void _refresh(WidgetRef ref) {
    ref.invalidate(installmentsProvider((saleKind: title.origin, saleId: title.id)));
    ref.invalidate(debtorTitlesProvider(customerId));
    ref.invalidate(debtorsProvider);
  }
}

/// Cronograma das parcelas: o que vence, quando e o que já foi pago.
/// INFORMATIVO — receber é sempre pelo botão único do card, que já mira a
/// próxima parcela pendente. Um botão por linha aqui multiplicava os alvos
/// para uma decisão que, na prática, é sempre "receber a mais antiga".
class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.parcelas});

  final List<Installment> parcelas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ordenadas = [...parcelas]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final pagas = ordenadas.where((p) => p.paidAt != null).length;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 15, color: neu.inkMuted),
              const SizedBox(width: 7),
              Text(
                'Parcelado em ${ordenadas.length}x',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$pagas de ${ordenadas.length} pagas',
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < ordenadas.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  _StatusDot(status: ordenadas[i].status),
                  const SizedBox(width: 8),
                  Text(
                    '${i + 1}ª',
                    style: TextStyle(color: neu.inkFaint, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rotuloVencimento(ordenadas[i]),
                      style: TextStyle(
                        color: ordenadas[i].status == InstallmentStatus.vencida
                            ? neu.danger
                            : neu.inkMuted,
                        fontSize: 12.5,
                        fontWeight:
                            ordenadas[i].status == InstallmentStatus.vencida
                                ? FontWeight.w700
                                : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(ordenadas[i].valor),
                    style: TextStyle(
                      color: ordenadas[i].paidAt != null
                          ? neu.inkFaint
                          : neu.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      decoration: ordenadas[i].paidAt != null
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "Vencida", "Vence hoje", "Paga" ou a data — o estado vem antes do número,
  /// porque é ele que decide se alguém precisa agir.
  String _rotuloVencimento(Installment p) {
    if (p.paidAt != null) return 'Paga';
    final d = DateTime.tryParse(p.dueDate);
    final data = d == null
        ? p.dueDate
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (p.status == InstallmentStatus.vencida) return 'Vencida · $data';
    if (p.venceHoje) return 'Vence hoje';
    return data;
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final InstallmentStatus status;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = switch (status) {
      InstallmentStatus.paga => neu.success,
      InstallmentStatus.vencida => neu.danger,
      InstallmentStatus.pendente => neu.warning,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: neu.danger, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
