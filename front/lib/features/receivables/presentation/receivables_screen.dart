import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../cashier/domain/cashier_format.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_query.dart';
import 'credit_sale_dialog.dart';
import 'receivables_filters_bar.dart';
import 'receivables_providers.dart';
import 'widgets/debtor_tile.dart';
import 'widgets/pending_settlement.dart';

/// "A receber" — controle de quem está devendo: vendas a prazo, parcelas, OS
/// entregues e não acertadas. Responde, nesta ordem: quanto tenho na rua (e
/// quanto está vencido), quem deve, de quê.
class ReceivablesScreen extends ConsumerStatefulWidget {
  const ReceivablesScreen({super.key});
  @override
  ConsumerState<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends ConsumerState<ReceivablesScreen> {
  final _scroll = ScrollController();

  bool _has(String p) =>
      ref.read(sessionControllerProvider).meOrNull?.hasPermission(p) ?? false;

  /// Igual ao caixa (`CashierScreen._canSale`): módulo E permissão — sem isto
  /// um tenant sem o módulo `sale` veria o botão e cairia num 403 ao tocar.
  bool _canSale() {
    final me = ref.read(sessionControllerProvider).meOrNull;
    return me != null && me.hasModule('sale') && me.hasPermission('sale.write');
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final canWrite = _has('cashier.write');
    final canSale = _canSale();
    final pagina = ref.watch(debtorsProvider);
    final query = ref.watch(debtorsQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isMobile && canSale)
          ? FloatingActionButton.extended(
              onPressed: () => showCreditSaleDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Venda a prazo'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OfflineScreenNotice(
              message:
                  'Você está offline. A carteira mostrada é a deste aparelho; '
                  'recebimentos ficam guardados e sobem quando a conexão voltar.',
            ),
            Row(children: [
              Expanded(
                child: Text('A receber',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (!isMobile && canSale)
                NeuButton(
                  label: 'Venda a prazo',
                  icon: Icons.add,
                  onPressed: () => showCreditSaleDialog(context),
                ),
            ]),
            const SizedBox(height: 12),
            CoachTarget('areceber.resumo', child: _Resumo(pagina: pagina)),
            const SizedBox(height: 12),
            const CoachTarget(
                'areceber.filtros', child: ReceivablesFiltersBar()),
            const SizedBox(height: 12),
            Expanded(
              child: CoachTarget(
                'areceber.lista',
                child: pagina.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Não foi possível carregar: $e'),
                      const SizedBox(height: 12),
                      NeuButton(
                        label: 'Tentar de novo',
                        kind: NeuButtonKind.secondary,
                        icon: Icons.refresh,
                        onPressed: () => ref.invalidate(debtorsProvider),
                      ),
                    ]),
                  ),
                  data: (p) => _lista(context, p, query, canWrite, isMobile),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, DebtorsPage p, DebtorsQuery query,
      bool canWrite, bool isMobile) {
    if (p.items.isEmpty) {
      // Sem devedor nenhum a lista fica vazia — mas o aviso de "entregue e não
      // acertado" TEM de aparecer mesmo assim, senão a oficina que esqueceu de
      // passar uma OS pelo caixa não vê nada em lugar nenhum.
      final aviso = p.pendingSettlement.count > 0
          ? AvisoPendenteAcerto(pendentes: p.pendingSettlement)
          : null;
      if (query.temFiltroAtivo) {
        return ListView(children: [
          if (aviso != null) ...[aviso, const SizedBox(height: 20)],
          NeuEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'Nenhum devedor com os filtros ativos',
            message:
                'A carteira continua aqui — a busca ou os filtros estão escondendo todos.',
            actionLabel: 'Limpar filtros',
            onAction: () =>
                ref.read(debtorsQueryProvider.notifier).clearFilters(),
          ),
        ]);
      }
      return ListView(children: [
        if (aviso != null) ...[aviso, const SizedBox(height: 20)],
        const NeuEmptyState(
          icon: Icons.check_circle_outline,
          title: 'Ninguém devendo',
          message: 'Vendas a prazo e OS entregues sem acerto aparecem aqui.',
        ),
      ]);
    }
    final lista = ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.only(bottom: isMobile ? 88 : 8),
      // O cabeçalho (aviso pendente + truncado) entra ACIMA do primeiro item,
      // não como um item a mais — por isso a contagem é a mesma da lista, e
      // não `+ 1` (que deslocava os índices e estourava o último).
      itemCount: p.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(children: [
            if (p.pendingSettlement.count > 0) ...[
              AvisoPendenteAcerto(pendentes: p.pendingSettlement),
              const SizedBox(height: 10),
            ],
            if (p.truncated) ...[
              const _AvisoTruncado(),
              const SizedBox(height: 10),
            ],
            DebtorTile(debtor: p.items[0], canWrite: canWrite),
          ]);
        }
        return DebtorTile(debtor: p.items[i], canWrite: canWrite);
      },
    );
    return Column(children: [
      Expanded(child: lista),
      const SizedBox(height: 12),
      NeuPageControls(
        page: p.page,
        pageSize: p.pageSize,
        total: p.total,
        onPage: (n) => ref.read(debtorsQueryProvider.notifier).goToPage(n),
      ),
    ]);
  }
}

/// Topo: total na rua, quanto está vencido (em vermelho), quantos devem.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.pagina});
  final AsyncValue<DebtorsPage> pagina;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final p = pagina.value;
    Widget kpi(String rotulo, String valor, {Color? cor}) => Expanded(
          child: NeuCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rotulo, style: TextStyle(color: neu.inkMuted, fontSize: 14)),
              const SizedBox(height: 6),
              Text(valor,
                  style: TextStyle(
                      color: cor ?? neu.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    return Row(children: [
      kpi('Total a receber', p == null ? '—' : formatMoney(p.totalDue)),
      const SizedBox(width: 10),
      kpi('Vencido', p == null ? '—' : formatMoney(p.overdueTotal),
          cor: neu.danger),
      const SizedBox(width: 10),
      kpi(p != null && p.total == 1 ? 'devedor' : 'devedores',
          p == null ? '—' : '${p.total}'),
    ]);
  }
}

class _AvisoTruncado extends StatelessWidget {
  const _AvisoTruncado();
  @override
  Widget build(BuildContext context) => NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: context.neu.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A carteira é muito grande e a lista pode estar incompleta. '
              'Use os filtros para estreitar.',
              style: TextStyle(color: context.neu.inkMuted, fontSize: 14),
            ),
          ),
        ]),
      );
}
