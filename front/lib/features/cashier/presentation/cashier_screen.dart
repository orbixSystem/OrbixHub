import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../../receivables/presentation/receivables_tab.dart';
import '../../sale/domain/sale_models.dart';
import '../../sale/presentation/sale_create_dialog.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import 'cashier_dialogs.dart';
import 'cashier_providers.dart';
import 'sales_history.dart';

/// Módulo Caixa: três abas — "Caixa do dia" (sessão atual: abrir/extrato/totais/
/// fechar), "Fiado" (contas a receber, agrupadas por cliente) e "Histórico"
/// (movimentos por período — o relatório do caixa). Quais aparecem depende do
/// papel: Fiado exige `cashier.read`, Histórico é de gestão.
///
/// Corpo apenas — a moldura é do shell. UI só fala com o repository (via
/// controller). Visual 100% no design system neumórfico (`core/ui`), responsivo.
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  int _tab = 0; // 0 = Caixa do dia · 1 = Fiado · 2 = Histórico

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.write') ?? false;
  }

  /// Gestão do caixa (abrir/fechar, despesa/sangria/suprimento, estorno, histórico).
  /// Dono/gerente; o atendente (caixa) NÃO tem.
  bool _canManage() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.manage') ?? false;
  }

  bool _canSale() {
    final s = ref.read(sessionControllerProvider);
    final me = s.meOrNull;
    return me != null && me.hasModule('sale') && me.hasPermission('sale.write');
  }

  /// Ler a carteira de fiado exige as mesmas permissões do extrato
  /// (`cashier.read`) — quem opera o caixa precisa saber quem deve.
  bool _canReadReceivables() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.read') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final canManage = _canManage();
    final canFiado = _canReadReceivables();
    // Abas montadas conforme o papel: o atendente vê Caixa do dia (+ Fiado, que
    // precisa para cobrar); o Histórico é relatório de gestão.
    final segments = <int, String>{
      0: 'Caixa do dia',
      if (canFiado) 1: 'Fiado',
      if (canManage) 2: 'Histórico',
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aviso PERMANENTE offline: o caixa opera no aparelho, mas nada é
            // efetivado no sistema até a conexão voltar.
            const OfflineScreenNotice(
              message: 'Você está offline. Os lançamentos são guardados neste '
                  'aparelho e só serão efetivados no sistema quando a conexão '
                  'voltar.',
            ),
            // Com uma única aba disponível não há o que segmentar.
            if (segments.length > 1) ...[
              NeuSegmented<int>(
                segments: segments,
                selected: segments.containsKey(_tab) ? _tab : 0,
                onChanged: (v) => setState(() => _tab = v),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(child: _body(canFiado: canFiado, canManage: canManage)),
          ],
        ),
      ),
    );
  }

  /// Corpo da aba selecionada. Cai no Caixa do dia quando a aba guardada não
  /// está mais disponível (troca de papel/empresa sem recriar a tela).
  Widget _body({required bool canFiado, required bool canManage}) {
    if (_tab == 1 && canFiado) {
      return ReceivablesTab(canWrite: _canWrite());
    }
    if (_tab == 2 && canManage) return const _CashierHistory();
    return _dayBody();
  }

  Widget _dayBody() {
    final async = ref.watch(cashierControllerProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(
        message: '$e',
        onRetry: () => ref.invalidate(cashierControllerProvider),
      ),
      data: (state) => state.isOpen
          ? _OpenBody(
              state: state,
              canWrite: _canWrite(),
              canManage: _canManage(),
              canSale: _canSale())
          : _ClosedBody(
              canManage: _canManage(), canSale: _canSale()),
    );
  }
}

/// Abre o fluxo único de venda avulsa (venda + recebimento/a receber + nota). O
/// próprio diálogo cuida de tudo e mostra o resultado; aqui só o disparamos.
Future<void> _startSale(BuildContext context, WidgetRef ref) async {
  await showSaleCreateDialog(context);
}

/// Hora local "HH:MM" de um timestamp ISO (vazio se nulo/ inválido).
String _fmtHora(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Métrica no padrão do dashboard (valor grande em cima, rótulo embaixo).
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color ?? neu.ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
      ],
    );
  }
}

/// Glyph de direção do movimento: círculo tintado com seta (entrada/saída).
class _DirectionGlyph extends StatelessWidget {
  const _DirectionGlyph({required this.color, required this.isIn, this.size = 40});
  final Color color;
  final bool isIn;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: size * .5,
        color: color,
      ),
    );
  }
}

class _ClosedBody extends ConsumerWidget {
  const _ClosedBody({required this.canManage, required this.canSale});
  final bool canManage; // abrir caixa = gestão (dono/gerente)
  final bool canSale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuEmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'Caixa fechado',
              message: canManage
                  ? 'Abra o caixa para registrar entradas e saídas do dia.'
                  : 'Aguarde o dono/gerente abrir o caixa para começar a operar.',
            ),
            if (canManage)
              NeuButton(
                label: 'Abrir caixa',
                icon: Icons.lock_open_outlined,
                onPressed: () => showOpenSessionDialog(context, ref),
              ),
            if (canSale) ...[
              const SizedBox(height: 12),
              // Venda avulsa (módulo `sale`) não tem camada offline.
              RequiresConnection(
                reason: 'a venda avulsa é registrada no servidor',
                child: NeuButton(
                  label: 'Venda avulsa',
                  kind: NeuButtonKind.secondary,
                  icon: Icons.shopping_cart_checkout_outlined,
                  onPressed: () => _startSale(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpenBody extends ConsumerWidget {
  const _OpenBody({
    required this.state,
    required this.canWrite,
    required this.canManage,
    required this.canSale,
  });
  final CashierState state;
  final bool canWrite;
  final bool canManage;
  final bool canSale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final session = state.session!;
    final totals = session.totals;
    final abertoHora = _fmtHora(session.openedAt);
    // Cabeçalho responsivo: título + "Aberto desde HH:MM" à esquerda, botão
    // Fechar à direita; em telas estreitas quebra pra baixo (Wrap).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Caixa do dia',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 12),
                NeuStatusChip(
                  label: abertoHora.isEmpty
                      ? 'Aberto'
                      : 'Aberto desde $abertoHora',
                  color: neu.success,
                  tint: neu.successTint,
                  icon: Icons.lock_open_outlined,
                ),
              ],
            ),
            if (canManage)
              NeuButton(
                label: 'Fechar caixa',
                kind: NeuButtonKind.secondary,
                icon: Icons.lock_outline,
                onPressed: () => showCloseSessionDialog(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(session: session),
        const SizedBox(height: 16),
        if (canWrite || canSale || canManage)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canSale)
                RequiresConnection(
                  reason: 'a venda avulsa é registrada no servidor',
                  child: NeuButton(
                    label: 'Venda avulsa',
                    icon: Icons.shopping_cart_checkout_outlined,
                    onPressed: () => _startSale(context, ref),
                  ),
                ),
              // Receber OS = operação do atendente (cashier.write).
              if (canWrite)
                NeuButton(
                  label: 'Receber OS',
                  icon: Icons.payments_outlined,
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'os_payment'),
                ),
              // Ajustes da gaveta = gestão (dono/gerente).
              if (canManage) ...[
                NeuButton(
                  label: 'Despesa / sangria',
                  kind: NeuButtonKind.secondary,
                  icon: Icons.remove,
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'despesa'),
                ),
                NeuButton(
                  label: 'Suprimento',
                  kind: NeuButtonKind.secondary,
                  icon: Icons.add,
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'suprimento'),
                ),
              ],
            ],
          ),
        if (totals != null && session.byMethod.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Totais por método',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in session.byMethod)
                _MethodPill(
                  label:
                      '${methodLabel(m.method)}: ${formatMoney(m.inAmount - m.outAmount)}',
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Extrato', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Expanded(
          child: _ExtractList(
            entries: state.entries,
            canManage: canManage,
            salesById: state.salesById,
          ),
        ),
      ],
    );
  }
}

/// Resumo do caixa aberto — cartão de métricas no padrão do dashboard.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});
  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final t = session.totals;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          _Metric(label: 'Abertura', value: formatMoney(session.openingAmount)),
          _Metric(
              label: 'Entradas',
              value: formatMoney(t?.inTotal ?? 0),
              color: neu.success),
          _Metric(
              label: 'Saídas',
              value: formatMoney(t?.outTotal ?? 0),
              color: neu.danger),
          _Metric(
              label: 'Esperado em caixa',
              value: formatMoney(t?.expected ?? 0),
              color: neu.navy),
        ],
      ),
    );
  }
}

/// Pílula informativa (total por forma de pagamento) — mesmo desenho dos chips
/// de filtro do app, sem interação.
class _MethodPill extends StatelessWidget {
  const _MethodPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: neu.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: neu.raised(),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: neu.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ExtractList extends ConsumerWidget {
  const _ExtractList({
    required this.entries,
    required this.canManage,
    this.salesById = const {},
  });
  final List<CashEntry> entries;
  final bool canManage; // estorno = gestão (dono/gerente)
  final Map<String, Sale> salesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const NeuEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhum movimento ainda',
        message:
            'Os recebimentos e lançamentos do dia aparecem aqui assim que forem registrados.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EntryTile(
        entry: entries[i],
        canManage: canManage,
        sale: entries[i].saleId == null ? null : salesById[entries[i].saleId],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.canManage, this.sale});
  final CashEntry entry;
  final bool canManage;

  /// Venda de origem, quando houver — é o que permite dizer PARA QUEM.
  final Sale? sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color = reversed
        ? neu.inkMuted
        : isIn
            ? neu.success
            : neu.danger;
    // A descrição já carrega o nº da venda/OS (ex.: "OS-0001"/"VND-0001"); se vier
    // vazia (entries antigas), cai no rótulo genérico da origem.
    final hasDesc = entry.description != null && entry.description!.isNotEmpty;
    final hora = _fmtHora(entry.createdAt);
    // Lançamento criado offline (ainda no outbox): selo "pendente de envio".
    final pending = (ref.watch(pendingIdsProvider('cash_entry')).value ??
            const <String>{})
        .contains(entry.id);
    // Cliente antes da descrição (que já traz o número): "para quem" era a
    // informação que faltava na linha do extrato.
    final cliente = sale?.customerName;
    final subtitleParts = <String>[
      if (hora.isNotEmpty) hora,
      methodLabel(entry.method),
      if (cliente != null && cliente.isNotEmpty) cliente,
      if (hasDesc)
        entry.description!
      else if (entry.saleKind == 'os')
        'OS'
      else if (entry.saleKind == 'sale')
        'Venda',
    ];
    return NeuListTile(
      leading: _DirectionGlyph(color: color, isIn: isIn),
      title: Text(
        categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: reversed ? neu.inkMuted : neu.ink,
        ),
      ),
      subtitle: pending
          ? Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(subtitleParts.join(' · ')),
                SyncRowBadge(entity: 'cash_entry', id: entry.id, dense: true),
              ],
            )
          : Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIn ? '+' : '−'} ${formatMoney(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
              decoration: reversed ? TextDecoration.lineThrough : null,
            ),
          ),
          if (canManage && !reversed) ...[
            const SizedBox(width: 10),
            NeuIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'Estornar',
              size: 38,
              onPressed: () => _confirmReverse(context, ref),
            ),
          ],
          if (reversed) ...[
            const SizedBox(width: 8),
            NeuStatusChip(
              label: 'Estornado',
              color: neu.inkMuted,
              tint: neu.inkMuted.withValues(alpha: .14),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReverse(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final ok = await showNeuDialog<bool>(
      context,
      dialog: NeuDialog(
        title: 'Estornar lançamento',
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
              label: 'Estornar',
              kind: NeuButtonKind.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
        child: NeuTextField(
          label: 'Motivo do estorno',
          controller: reasonCtrl,
          hint: 'Ex.: valor lançado errado',
          maxLength: 500,
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um motivo (mín. 3 caracteres).')),
      );
      return;
    }
    try {
      await ref.read(cashierControllerProvider.notifier).reverse(entry.id, reason);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: neu.danger, size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkMuted)),
          const SizedBox(height: 12),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ===================== Histórico do Caixa (movimentos por período) =====================

/// Relatório do CAIXA: o que de fato passou pelo caixa no período (baseado nos
/// movimentos/`cash_entry`, não na data de criação da OS/venda). Período por
/// presets (Hoje/7/30 dias), totais por método/origem + extrato. Read-only.
class _CashierHistory extends ConsumerWidget {
  const _CashierHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final preset = ref.watch(cashierHistoryPresetProvider);
    final lente = ref.watch(cashierHistoryLenteProvider);
    final async = ref.watch(cashierHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in const [
              ('hoje', 'Hoje'),
              ('7d', '7 dias'),
              ('30d', '30 dias'),
            ])
              _ChoicePill(
                label: p.$2,
                selected: preset == p.$1,
                onTap: () =>
                    ref.read(cashierHistoryPresetProvider.notifier).set(p.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBox(
              message: '$e',
              onRetry: () => ref.invalidate(cashierHistoryProvider),
            ),
            data: (data) {
              final s = data.summary;
              return ListView(
                children: [
                  // Resumo do período
                  NeuCard(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 28,
                      runSpacing: 16,
                      children: [
                        _Metric(
                            label: 'Recebido',
                            value: formatMoney(s.totalIn),
                            color: neu.success),
                        _Metric(
                            label: 'Saídas',
                            value: formatMoney(s.totalOut),
                            color: neu.danger),
                        _Metric(
                            label: 'Saldo',
                            value: formatMoney(s.net),
                            color: neu.navy),
                      ],
                    ),
                  ),
                  if (s.byMethod.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Por forma (entrou · saiu · saldo)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    NeuCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      radius: NeuTokens.rField,
                      child: Column(
                        children: [
                          for (var i = 0; i < s.byMethod.length; i++) ...[
                            if (i > 0)
                              Container(height: 1, color: neu.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                        methodLabel(s.byMethod[i].method),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: neu.ink)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        '+ ${formatMoney(s.byMethod[i].inAmount)}',
                                        textAlign: TextAlign.right,
                                        style:
                                            TextStyle(color: neu.success)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        '− ${formatMoney(s.byMethod[i].outAmount)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(color: neu.danger)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        formatMoney(s.byMethod[i].inAmount -
                                            s.byMethod[i].outAmount),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: neu.ink)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Duas lentes do MESMO período: "Movimentos" é o livro-caixa
                  // (dinheiro que entrou/saiu, inclusive despesas) e "Vendas" é
                  // o que foi vendido. Não são a mesma coisa: venda em fiado não
                  // move o caixa, e sangria não é venda.
                  NeuSegmented<int>(
                    segments: const {0: 'Movimentos', 1: 'Vendas'},
                    selected: lente,
                    onChanged: (v) =>
                        ref.read(cashierHistoryLenteProvider.notifier).set(v),
                  ),
                  const SizedBox(height: 12),
                  if (lente == 1)
                    SalesHistoryList(sales: data.sales)
                  else if (data.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: NeuEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhum movimento no período',
                        message:
                            'Troque o período acima para ver outros dias do caixa.',
                      ),
                    )
                  else
                    for (final e in data.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryEntryTile(
                          entry: e,
                          sale: e.saleId == null
                              ? null
                              : data.salesById[e.saleId],
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pílula de escolha (presets de período) — mesmo desenho dos chips de filtro
/// da lista de OS: selecionada = navy sólido; demais = extrudadas.
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : neu.raised(),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? neu.onNavy : neu.inkMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Linha do extrato histórico: data + categoria + método/origem + valor.
///
/// Quando o lançamento aponta para uma VENDA (`saleKind == 'sale'`), a linha
/// abre o detalhe: o histórico mostrava só "Venda avulsa · R$ 150", sem dizer o
/// que foi vendido nem permitir agir. Lançamentos de OS não abrem aqui — a OS
/// tem tela própria, alcançada pela lista de OS.
class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry, this.sale});
  final CashEntry entry;

  /// Venda de origem, quando o lançamento aponta para uma. Serve para dizer
  /// PARA QUEM foi a venda — o lançamento do caixa só guarda `sale_id`.
  final Sale? sale;

  /// Só venda: `saleId` presente e origem 'sale'.
  String? get _saleId =>
      entry.saleKind == 'sale' && (entry.saleId?.isNotEmpty ?? false)
          ? entry.saleId
          : null;

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color =
        reversed ? neu.inkMuted : (isIn ? neu.success : neu.danger);
    final hasDesc = entry.description != null && entry.description!.isNotEmpty;
    // Cliente da venda antes da descrição: "para quem" é a informação que
    // faltava na linha (a descrição já traz o número da venda).
    final cliente = sale?.customerName;
    final sub = <String>[
      _fmtDate(entry.createdAt),
      methodLabel(entry.method),
      if (cliente != null && cliente.isNotEmpty) cliente,
      if (hasDesc) entry.description!,
    ].where((s) => s.isNotEmpty).join(' · ');
    return NeuListTile(
      dense: true,
      leading: _DirectionGlyph(color: color, isIn: isIn, size: 36),
      title: Text(
        categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: reversed ? neu.inkMuted : neu.ink,
        ),
      ),
      subtitle: Text(sub),
      onTap: _saleId == null
          ? null
          : () => showSaleDetailDialog(context, saleId: _saleId!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIn ? '+' : '−'} ${formatMoney(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
              decoration: reversed ? TextDecoration.lineThrough : null,
            ),
          ),
          // Affordance: só quem abre detalhe mostra a seta.
          if (_saleId != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: neu.inkFaint),
          ],
        ],
      ),
    );
  }
}
