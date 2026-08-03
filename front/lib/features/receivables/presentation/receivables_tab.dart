import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/presentation/cashier_providers.dart';
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
                    fontSize: 11.5,
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
              style: TextStyle(color: neu.inkMuted, fontSize: 13),
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

/// Um título com os itens do que foi vendido e a ação de receber.
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
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                child: title.origin == 'sale'
                    // Venda tem detalhe próprio (itens, recebimentos, cancelar
                    // e refazer); OS é alcançada pela lista de OS.
                    ? InkWell(
                        onTap: () => showSaleDetailDialog(
                          context,
                          saleId: title.id,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Venda ${title.number}',
                              style: TextStyle(
                                color: neu.navy,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(Icons.open_in_new_rounded,
                                size: 13, color: neu.navy),
                          ],
                        ),
                      )
                    : Text(
                        title.number,
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (parcial)
                NeuStatusChip(
                  label: 'Parcial',
                  color: neu.warning,
                  tint: neu.warningTint,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // O que foi vendido — responde "de quais serviços é a dívida".
          if (title.items.isEmpty)
            Text(
              'Sem detalhamento de itens.',
              style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
            )
          else
            for (final i in title.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.quantity > 1
                            ? '${_qtd(i.quantity)}× ${i.name}'
                            : i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: neu.inkMuted, fontSize: 12),
                      ),
                    ),
                    Text(
                      formatMoney(i.total),
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          Divider(height: 1, color: neu.line),
          const SizedBox(height: 10),
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
                        style: TextStyle(color: neu.inkMuted, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              if (canWrite)
                NeuButton(
                  label: 'Receber',
                  icon: Icons.payments_outlined,
                  onPressed: () => _receber(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Recebimento: lançamento no caixa apontando para a venda/OS. Reusa o mesmo
  /// diálogo do "Receber OS" — aceita parcial e já vem com o saldo preenchido.
  Future<void> _receber(BuildContext context, WidgetRef ref) async {
    final estado = ref.read(cashierControllerProvider).value;
    final config = estado?.config;
    if (config == null) return;
    await showReceiveTitleDialog(
      context,
      ref,
      config: config,
      title: title,
    );
    if (!context.mounted) return;
    // O saldo mudou: recarrega a lista do cliente E a carteira.
    ref.invalidate(debtorTitlesProvider(customerId));
    ref.invalidate(debtorsProvider);
  }
}

/// Quantidade sem casas decimais inúteis (4 em vez de 4,000).
String _qtd(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

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
