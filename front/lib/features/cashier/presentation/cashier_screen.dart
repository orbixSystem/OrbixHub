import 'dart:async';

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
import 'entry_edit_dialogs.dart';
import 'cashier_providers.dart';
import '../domain/cashier_timeline.dart';
import 'cashier_timeline_list.dart';

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
      data: (state) {
        // Ordem importa: com a exigência DESLIGADA a sessão é detalhe interno
        // (o backend cria uma implícita no primeiro lançamento). Mostrar
        // "Aberto desde HH:MM" e "Fechar caixa" nesse caso reintroduz a
        // cerimônia que a config justamente dispensou.
        if (state.isOpen && state.config.requireOpenSession) {
          return _OpenBody(
            state: state,
            canWrite: _canWrite(),
            canManage: _canManage(),
            canSale: _canSale(),
          );
        }
        // A cerimônia de abrir/fechar existe para CONFERIR GAVETA de dinheiro.
        // Quem recebe só por Pix/cartão (ou opera sozinho) não tem gaveta para
        // conferir, e para esse caso o backend já aceita lançar sem sessão
        // (`requireOpenSession=false` cria uma sessão implícita). A tela ignorava
        // essa config e bloqueava com "Caixa fechado" — agora respeita.
        if (!state.config.requireOpenSession) {
          return _FreeBody(
            state: state,
            canWrite: _canWrite(),
            canManage: _canManage(),
            canSale: _canSale(),
          );
        }
        return _ClosedBody(
          canManage: _canManage(),
          canSale: _canSale(),
        );
      },
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
  const _DirectionGlyph({required this.color, required this.isIn});
  static const size = 40.0;
  final Color color;
  final bool isIn;

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

/// Caixa SEM cerimônia de abertura (`requireOpenSession = false`).
///
/// A sessão de caixa existe para conferir GAVETA de dinheiro: contar no fim do
/// dia e achar falta/sobra. Quem recebe só por Pix/cartão, ou opera sozinho, não
/// tem gaveta para conferir — para essa oficina, exigir "abrir o caixa" antes de
/// registrar qualquer coisa é atrito puro.
///
/// Aqui o caixa é um livro de lançamentos do dia: registra e pronto. A abertura
/// segue disponível como AÇÃO (quem quiser conferência de gaveta abre quando
/// quiser), só não é mais pré-requisito.
class _FreeBody extends ConsumerWidget {
  const _FreeBody({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text('Caixa de hoje',
                style: Theme.of(context).textTheme.titleLarge),

          ],
        ),
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
              if (canWrite)
                NeuButton(
                  label: 'Receber OS',
                  icon: Icons.payments_outlined,
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'os_payment'),
                ),
              // Sem controle de gaveta (o padrão), "suprimento" não tem o que
              // conferir — aporte só significa algo contra um valor de abertura.
              // A categoria continua no diálogo para quem precisar dela.
              if (canManage)
                NeuButton(
                  label: 'Despesa / sangria',
                  kind: NeuButtonKind.secondary,
                  icon: Icons.remove,
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'despesa'),
                ),
            ],
          ),
        const SizedBox(height: 24),
        Text('Lançamentos de hoje',
            style: Theme.of(context).textTheme.titleMedium),
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
    // Lançamento que aponta para uma VENDA abre o detalhe dela — é de lá que se
    // edita os itens. Antes só o Histórico levava à venda, então corrigir o que
    // foi vendido obrigava a sair do Caixa do dia.
    final daVenda = entry.saleKind == 'sale' && entry.saleId != null;
    return NeuListTile(
      onTap: daVenda
          ? () => showSaleDetailDialog(context, saleId: entry.saleId!)
          : null,
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
          // Editar / Corrigir / Estornar num menu só: três ícones na linha não
          // caberiam no celular, e as ações são raras (não merecem o espaço).
          if (canManage && !reversed) ...[
            const SizedBox(width: 6),
            EntryActionsMenu(entry: entry),
          ],
          if (reversed) ...[
            const SizedBox(width: 8),
            NeuStatusChip(
              label: 'Estornado',
              color: neu.inkMuted,
              tint: neu.inkMuted.withValues(alpha: .14),
            ),
          ],
          // Afordância: sem isto nada indica que a linha da venda é clicável.
          if (daVenda) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: neu.inkFaint),
          ],
        ],
      ),
    );
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
    final filtro = ref.watch(cashierHistoryFilterProvider);
    final busca = ref.watch(cashierHistoryBuscaProvider);
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
                  const SizedBox(height: 24),
                  Text('O que aconteceu',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _HistoricoFiltros(
                    filtro: filtro,
                    busca: busca,
                    onFiltro: (f) =>
                        ref.read(cashierHistoryFilterProvider.notifier).set(f),
                    onBusca: (b) =>
                        ref.read(cashierHistoryBuscaProvider.notifier).set(b),
                  ),
                  const SizedBox(height: 12),
                  // Uma lista só, cada linha detalhada. Antes havia duas lentes
                  // (Movimentos | Vendas) e o usuário tinha de escolher — mas o
                  // dia é um só, e alternar escondia metade do que aconteceu.
                  Builder(
                    builder: (_) {
                      final todos = buildCashierTimeline(
                        entries: data.entries,
                        sales: data.sales,
                      );
                      // Servidor já recortou; aqui fica só a coerência entre as
                      // duas fontes (venda em fiado não é entrada de caixa).
                      final visiveis = filterCashierTimeline(
                        todos,
                        filtro: filtro,
                        busca: busca,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (todos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                visiveis.length == todos.length
                                    ? '${todos.length} '
                                        '${todos.length == 1 ? "registro" : "registros"}'
                                    : '${visiveis.length} de ${todos.length}',
                                style: TextStyle(
                                    color: neu.inkFaint, fontSize: 11.5),
                              ),
                            ),
                          // O Histórico é aba de gestão (só aparece com
                          // `cashier.manage`), então corrigir dali é permitido.
                          CashierTimelineList(
                            events: visiveis,
                            canManage: true,
                          ),
                        ],
                      );
                    },
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

/// Filtros do histórico: tipo + busca.
///
/// Ambos são aplicados no SERVIDOR (e no espelho SQLite quando offline), não na
/// página já carregada — filtrar em memória quebraria a paginação e daria
/// resultado diferente conforme a conexão.
class _HistoricoFiltros extends StatefulWidget {
  const _HistoricoFiltros({
    required this.filtro,
    required this.busca,
    required this.onFiltro,
    required this.onBusca,
  });

  final CashierFilter filtro;
  final String busca;
  final ValueChanged<CashierFilter> onFiltro;
  final ValueChanged<String> onBusca;

  @override
  State<_HistoricoFiltros> createState() => _HistoricoFiltrosState();
}

class _HistoricoFiltrosState extends State<_HistoricoFiltros> {
  late final _ctrl = TextEditingController(text: widget.busca);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Espera o usuário parar de digitar antes de ir ao servidor — sem isso cada
  /// letra dispararia uma consulta.
  void _buscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => widget.onBusca(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuTextField(
          label: 'Buscar',
          controller: _ctrl,
          hint: 'Cliente, OS, venda ou descrição',
          prefixIcon: Icons.search_rounded,
          onChanged: _buscar,
          suffix: _ctrl.text.isEmpty
              ? null
              : NeuIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Limpar busca',
                  size: 34,
                  onPressed: () {
                    _ctrl.clear();
                    _debounce?.cancel();
                    widget.onBusca('');
                    setState(() {});
                  },
                ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in CashierFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoicePill(
                    label: cashierFilterLabel(f),
                    selected: widget.filtro == f,
                    onTap: () => widget.onFiltro(f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        if (widget.filtro == CashierFilter.entradas)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Venda em fiado não conta como entrada — nada entrou no caixa.',
              style: TextStyle(color: neu.inkFaint, fontSize: 11),
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

