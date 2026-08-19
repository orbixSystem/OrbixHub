import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../../expenses/presentation/expense_detail_dialog.dart';
import '../../os/presentation/os_detail_dialog.dart';
import '../../os/presentation/payment_status.dart';
import '../../receivables/presentation/receivables_tab.dart';
import '../../sale/domain/sale_models.dart';
import '../../sale/presentation/sale_create_dialog.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import 'cashier_providers.dart';
import 'entry_edit_dialogs.dart';
import 'receive_picker_dialog.dart';
import '../domain/cashier_timeline.dart';
import 'cashier_timeline_list.dart';

/// Módulo Caixa: três abas — "Caixa" (entradas do dia + ações rápidas), "Fiado"
/// (contas a receber, agrupadas por cliente) e "Histórico" (movimentos por
/// período — o relatório do caixa). Quais aparecem depende do papel: Fiado
/// exige `cashier.read`, Histórico é de gestão.
///
/// Corpo apenas — a moldura é do shell. UI só fala com o repository (via
/// controller). Visual 100% no design system neumórfico (`core/ui`), responsivo.
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  int _tab = 0; // 0 = Caixa · 1 = Fiado · 2 = Histórico

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.write') ?? false;
  }

  /// Gestão do caixa (sangria/suprimento, estorno, histórico).
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

  bool _canReadReceivables() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.read') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final canManage = _canManage();
    final canFiado = _canReadReceivables();
    // Abas montadas conforme o papel: o atendente vê Caixa (+ Fiado, que
    // precisa para cobrar); o Histórico é relatório de gestão. Ordem =
    // frequência de uso: opera-se o dia, cobra-se o fiado, consulta-se o período.
    final segments = <int, String>{
      0: 'Caixa',
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
            // Aviso PERMANENTE offline.
            const OfflineScreenNotice(
              message: 'Você está offline. Os lançamentos são guardados neste '
                  'aparelho e só serão efetivados no sistema quando a conexão '
                  'voltar.',
            ),
            if (segments.length > 1) ...[
              CoachTarget(
                'caixa.abas',
                child: NeuSegmented<int>(
                  segments: segments,
                  selected: segments.containsKey(_tab) ? _tab : 0,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(child: _body(canFiado: canFiado, canManage: canManage)),
          ],
        ),
      ),
    );
  }

  /// Corpo da aba selecionada. Cai no Caixa quando a aba guardada não está
  /// mais disponível (troca de papel/empresa sem recriar a tela).
  Widget _body({required bool canFiado, required bool canManage}) {
    if (_tab == 1 && canFiado) return ReceivablesTab(canWrite: _canWrite());
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
        return _FreeBody(
          state: state,
          canWrite: _canWrite(),
          canManage: _canManage(),
          canSale: _canSale(),
          onVerHistorico: () => setState(() => _tab = 2),
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

/// Caixa SEM cerimônia de abertura (`requireOpenSession = false`).
class _FreeBody extends ConsumerWidget {
  const _FreeBody({
    required this.state,
    required this.canWrite,
    required this.canManage,
    required this.canSale,
    this.onVerHistorico,
  });

  final CashierState state;
  final bool canWrite;
  final bool canManage;
  final bool canSale;

  /// Atalho para a aba Histórico (só existe para quem tem gestão).
  final VoidCallback? onVerHistorico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Caixa de hoje', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        // AÇÕES em grid: duas portas claras de entrada de dinheiro. Fiado (ver
        // quem deve, parcelar, receber parcela) tem aba própria — não é uma
        // ação de checkout, é gestão de dívida.
        if (canWrite || canSale)
          CoachTarget(
            'caixa.acoes',
            child: _AcoesGrid(
              acoes: [
                if (canSale)
                  _Acao(
                    label: 'Venda avulsa',
                    icon: Icons.shopping_cart_checkout_outlined,
                    cor: context.neu.navy,
                    exigeConexao: 'a venda avulsa é registrada no servidor',
                    onTap: () => _startSale(context, ref),
                  ),
                if (canWrite)
                  _Acao(
                    label: 'Receber OS',
                    icon: Icons.payments_outlined,
                    cor: context.neu.success,
                    onTap: () =>
                        showReceivePickerDialog(context, ref, state.config),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Últimos lançamentos',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (canManage && onVerHistorico != null)
              TextButton.icon(
                onPressed: onVerHistorico,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                iconAlignment: IconAlignment.end,
                label: const Text('Ver tudo'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CoachTarget(
            'caixa.ultimos',
            child: _ExtractList(
              entries: state.entries,
              canManage: canManage,
              salesById: state.salesById,
              limite: 5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid das ações do caixa. Cartões grandes, 2 por linha no celular — o que se
/// vem fazer aqui não deveria caber num botão de 36px.
class _AcoesGrid extends StatelessWidget {
  const _AcoesGrid({required this.acoes});

  final List<_Acao> acoes;

  @override
  Widget build(BuildContext context) {
    if (acoes.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        // Alvo de ~200px por cartão; nunca menos de 2 colunas (nem 1 cartão
        // gigante sozinho numa tela larga).
        final colunas = (c.maxWidth / 200).floor().clamp(1, 3);
        final largura =
            colunas == 1 ? c.maxWidth : (c.maxWidth - (colunas - 1) * 10) / colunas;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in acoes) SizedBox(width: largura, child: _AcaoCard(acao: a)),
          ],
        );
      },
    );
  }
}

/// Uma ação do grid.
class _Acao {
  const _Acao({
    required this.label,
    required this.icon,
    required this.cor,
    required this.onTap,
    this.exigeConexao,
  });

  final String label;
  final IconData icon;
  final Color cor;
  final VoidCallback onTap;

  /// Motivo, quando a ação só funciona online (embrulha em RequiresConnection).
  final String? exigeConexao;
}

class _AcaoCard extends StatelessWidget {
  const _AcaoCard({required this.acao});

  final _Acao acao;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final card = NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: acao.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: acao.cor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(NeuTokens.rChip),
                ),
                child: Center(child: Icon(acao.icon, size: 18, color: acao.cor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  acao.label,
                  maxLines: 2,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final motivo = acao.exigeConexao;
    return motivo == null
        ? card
        : RequiresConnection(reason: motivo, child: card);
  }
}

class _ExtractList extends ConsumerWidget {
  const _ExtractList({
    required this.entries,
    required this.canManage,
    this.salesById = const {},
    this.limite,
  });
  final List<CashEntry> entries;
  final bool canManage; // estorno = gestão (dono/gerente)
  final Map<String, Sale> salesById;

  /// Máximo de linhas exibidas (`null` = todas). O Caixa do dia mostra poucas,
  /// como confirmação; o extrato completo é o Histórico.
  final int? limite;

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
    final visiveis = limite == null || entries.length <= limite!
        ? entries
        : entries.sublist(0, limite!);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: visiveis.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EntryTile(
        entry: visiveis[i],
        canManage: canManage,
        sale: visiveis[i].saleId == null ? null : salesById[visiveis[i].saleId],
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
        'Venda'
      else if (entry.saleKind == 'expense')
        'Despesa',
    ];
    // Lançamento que aponta para uma venda ou OS abre a ORIGEM dele.
    //
    // Venda abre em diálogo (dá para editar itens e exportar sem sair do caixa);
    // OS NAVEGA para a tela dela, que é grande demais para caber num diálogo e
    // tem o próprio fluxo (itens, fotos, timeline, exportar PDF). Antes o
    // recebimento de OS era um beco sem saída: mostrava "OS" e não levava a lugar
    // nenhum, obrigando a procurar a ordem à mão.
    final daVenda = entry.saleKind == 'sale' && entry.saleId != null;
    final daOs = entry.saleKind == 'os' && entry.saleId != null;
    // Saída de conta a pagar: abre a DESPESA em diálogo, como a venda. Antes a
    // baixa gravava origem nula e a linha do extrato dizia "Despesa · Aluguel"
    // sem levar a lugar nenhum — para achar a conta era preciso lembrar o mês e
    // procurar à mão. A ida (despesa → lançamento) já existia; faltava a volta.
    final daDespesa = entry.saleKind == 'expense' && entry.saleId != null;
    // Situação da venda NA LINHA. Antes só dava para saber clicando: uma venda
    // cancelada tinha a mesma cara de uma normal, porque cancelar a venda NÃO
    // mexe no lançamento do caixa (o dinheiro continua na gaveta até alguém
    // estornar). Fiado e pagamento parcial tinham o mesmo problema.
    final selo = sale == null
        ? null
        : sale!.status == 'canceled'
            // Cancelada manda no rótulo: é a informação que muda o que fazer,
            // e vem antes de qualquer coisa sobre pagamento.
            ? NeuStatusChip(
                label: 'Cancelada',
                color: neu.danger,
                tint: neu.danger.withValues(alpha: .14),
              )
            : PaymentTag(status: sale!.paymentStatus, dense: true);
    // Só vira `Wrap` quando há selo/badge: sem eles, o subtítulo continua uma
    // linha de texto simples, como sempre foi.
    final extras = <Widget>[
      ?selo,
      if (pending) SyncRowBadge(entity: 'cash_entry', id: entry.id, dense: true),
    ];
    return NeuListTile(
      onTap: daVenda
          ? () => showSaleDetailDialog(context, saleId: entry.saleId!)
          : daOs
              ? () => showOsDetailDialog(context, orderId: entry.saleId!)
              : daDespesa
                  ? () => showExpenseDetailDialog(context, ref,
                      id: entry.saleId!)
                  : null,
      leading: _DirectionGlyph(color: color, isIn: isIn),
      title: Text(
        categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: reversed ? neu.inkMuted : neu.ink,
        ),
      ),
      subtitle: extras.isEmpty
          ? Text(subtitleParts.join(' · '))
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [Text(subtitleParts.join(' · ')), ...extras],
            ),
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
          //
          // Nas linhas de VENDA o menu não aparece: a linha abre o detalhe da
          // venda, que é onde se age sobre ela (itens, cliente, cancelar) E
          // sobre o recebimento. Dois caminhos para a mesma coisa, um deles
          // escondido atrás de três pontinhos, só confunde.
          if (canManage && !reversed && !daVenda) ...[
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
          // Afordância: sem isto nada indica que a linha é clicável (venda, OS
          // e despesa navegam no toque — só a venda mostrava o chevron).
          if (daVenda || daOs || daDespesa) ...[
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
                                    color: neu.inkFaint, fontSize: 12),
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
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
            ),
          ),
        // Cancelar a venda devolve o estoque, mas NÃO desfaz o recebimento: o
        // dinheiro segue no caixa até alguém estornar o lançamento. Dizer isso
        // aqui evita o fechamento fechar torto sem ninguém entender por quê.
        if (widget.filtro == CashierFilter.canceladas)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Cancelar devolve o estoque, mas o dinheiro já recebido segue no '
              'caixa até o lançamento ser estornado.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

