import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
// Rótulo PT-BR da forma de pagamento — função PURA do caixa, reaproveitada em
// vez de duplicada. Mesmo caso de `formatMoney` do dashboard, logo acima: não é
// acesso a dado de outro módulo, é vocabulário compartilhado.
import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/expense_models.dart';
import '../domain/expense_next_due.dart';
import '../domain/expense_ordering.dart';
import '../domain/expense_status.dart';
import 'expense_detail_dialog.dart';
import 'expense_form_dialog.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';

const _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// Tela do módulo Despesas: o que tem para pagar no mês, o que já foi pago e o
/// que está vencido.
///
/// O shell é dono da moldura — esta tela devolve só o corpo.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(despesasDoMesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Cabecalho(),
        Expanded(
          child: async.when(
            // Mantém a lista ANTERIOR na tela enquanto recarrega. Cada escrita
            // (cadastrar, dar baixa, revogar) invalida o provider, e sem isto a
            // lista inteira era substituída por um spinner a cada ação — com
            // backend lento fica indistinguível de travamento. O spinner só
            // aparece no primeiro carregamento, quando não há nada para mostrar.
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Erro(
              mensagem: e is AppException ? e.message : 'Erro ao carregar as despesas.',
              onTentar: () => ref.invalidate(despesasDoMesProvider),
            ),
            data: (mes) => _Corpo(mes: mes),
          ),
        ),
      ],
    );
  }
}

/// Navegação de mês + botão de nova despesa.
class _Cabecalho extends ConsumerWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final mes = ref.watch(mesEmFocoProvider);
    final agora = DateTime.now();
    final ehMesAtual = mes.year == agora.year && mes.month == agora.month;
    final compacto = context.isMobile;

    final navegador = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Mês anterior',
          onPressed: () => ref.read(mesEmFocoProvider.notifier).voltar(),
        ),
        const SizedBox(width: 4),
        // Largura fixa: sem ela o título muda de tamanho entre "Maio" e
        // "Setembro" e as setas dançam a cada troca de mês.
        SizedBox(
          width: compacto ? 150 : 190,
          child: Text(
            '${_meses[mes.month - 1]} ${mes.year}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neu.ink,
              fontSize: compacto ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        NeuIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Próximo mês',
          onPressed: () => ref.read(mesEmFocoProvider.notifier).avancar(),
        ),
        if (!ehMesAtual) ...[
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.today_outlined,
            tooltip: 'Voltar para o mês atual',
            onPressed: () => ref.read(mesEmFocoProvider.notifier).hoje(),
          ),
        ],
      ],
    );

    final botaoNova = NeuButton(
      label: compacto ? 'Nova' : 'Nova despesa',
      icon: Icons.add_rounded,
      onPressed: () async {
        final criou = await showExpenseFormDialog(context, ref);
        if (criou) ref.invalidate(despesasDoMesProvider);
      },
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(compacto ? 4 : 8, 4, compacto ? 4 : 8, 12),
      child: compacto
          // No mobile empilha: navegador e botão lado a lado espremem o mês.
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: navegador),
                const SizedBox(height: 10),
                botaoNova,
              ],
            )
          : Row(
              children: [
                navegador,
                const Spacer(),
                botaoNova,
              ],
            ),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.mes});

  final ExpensesMonth mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroDespesaProvider);
    final busca = ref.watch(buscaDespesaProvider);
    final hoje = DateTime.now();

    final porId = {for (final c in mes.categories) c.id: c};

    final doFiltro = filtro == FiltroDespesa.semana
        // "Esta semana" tem regra própria (hoje + 7 dias, vencidas incluídas), e
        // por isso é função pura testada em vez de um `case` aqui.
        ? contasDaSemana(mes.items, hoje: hoje)
        : mes.items.where((e) {
            final s = e.situacao(hoje);
            return switch (filtro) {
              FiltroDespesa.todas => true,
              FiltroDespesa.emAberto => !e.pago,
              FiltroDespesa.vencidas => s == ExpenseStatus.vencido,
              FiltroDespesa.pagas => e.pago,
              FiltroDespesa.semana => true, // tratado acima
            };
          }).toList(growable: false);

    // Busca ANTES de ordenar (menos itens para ordenar) e ordenação por
    // URGÊNCIA por último — é ela que decide o que o olho vê primeiro.
    final visiveis = ordenarPorUrgencia(
      filtrarPorTexto(
        doFiltro,
        busca,
        nomeDaCategoria: (id) => porId[id]?.name ?? '',
      ),
      hoje: hoje,
    );

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 4 : 8),
      children: [
        _Totais(mes: mes),
        const SizedBox(height: 14),
        _Filtros(mes: mes, hoje: hoje),
        const SizedBox(height: 10),
        NeuSearchBar(
          hint: 'Buscar por descrição ou categoria',
          onChanged: ref.read(buscaDespesaProvider.notifier).definir,
        ),
        const SizedBox(height: 12),
        if (visiveis.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: NeuEmptyState(
              icon: Icons.event_available_outlined,
              title: mes.items.isEmpty
                  ? 'Nenhuma despesa neste mês'
                  : busca.trim().isNotEmpty
                      ? 'Nada encontrado'
                      : 'Nada neste filtro',
              message: mes.items.isEmpty
                  ? 'Cadastre o que você precisa pagar — aluguel, luz, internet, '
                      'impostos — e acompanhe aqui o que vence, o que já foi pago '
                      'e o que passou do prazo.'
                  : busca.trim().isNotEmpty
                      ? 'Nenhuma conta deste mês casa com "${busca.trim()}". '
                          'A busca olha a descrição e o nome da categoria.'
                      : 'Troque o filtro para ver as outras despesas do mês.',
            ),
          )
        else
          for (final e in visiveis)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LinhaDespesa(
                despesa: e,
                categoria: porId[e.categoryId],
                hoje: hoje,
                // A próxima cobrança é calculada aqui, onde as regras e as
                // irmãs do mês estão em mãos — o card não sai buscando nada.
                proxima: proximaCobranca(
                  e,
                  regras: mes.recurrences,
                  irmas: e.installmentGroupId == null
                      ? const []
                      : mes.items
                          .where((o) =>
                              o.installmentGroupId == e.installmentGroupId)
                          .toList(),
                ),
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Os quatro números do topo. "Vencido" é o único que muda de cor quando existe
/// — zero em vermelho treinaria a cliente a ignorar vermelho.
class _Totais extends StatelessWidget {
  const _Totais({required this.mes});

  final ExpensesMonth mes;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cards = <Widget>[
      _CardTotal(rotulo: 'Previsto', valor: mes.totalPrevisto, cor: neu.ink),
      _CardTotal(rotulo: 'Pago', valor: mes.totalPago, cor: neu.success),
      _CardTotal(rotulo: 'Em aberto', valor: mes.totalEmAberto, cor: neu.info),
      _CardTotal(
        rotulo: 'Vencido',
        valor: mes.totalVencido,
        cor: mes.totalVencido > 0 ? neu.danger : neu.inkMuted,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // Abaixo de ~560px cabem 2 por linha; acima, os 4 lado a lado.
        final porLinha = c.maxWidth < 560 ? 2 : 4;
        final largura = (c.maxWidth - (porLinha - 1) * 8) / porLinha;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final card in cards) SizedBox(width: largura, child: card),
          ],
        );
      },
    );
  }
}

class _CardTotal extends StatelessWidget {
  const _CardTotal({required this.rotulo, required this.valor, required this.cor});

  final String rotulo;
  final num valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(valor),
              style: TextStyle(
                color: cor,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filtros extends ConsumerWidget {
  const _Filtros({required this.mes, required this.hoje});

  final ExpensesMonth mes;
  final DateTime hoje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(filtroDespesaProvider);
    final vencidas =
        mes.items.where((e) => e.situacao(hoje) == ExpenseStatus.vencido).length;
    final abertas = mes.items.where((e) => !e.pago).length;
    final pagas = mes.items.where((e) => e.pago).length;

    // Contagem no rótulo: evita o filtro vazio surpresa ("cliquei em vencidas e
    // não tem nada") — dá para ver antes de clicar.
    String rot(String base, int n) => n > 0 ? '$base ($n)' : base;

    final daSemana = contasDaSemana(mes.items, hoje: hoje).length;

    final opcoes = <(FiltroDespesa, String)>[
      (FiltroDespesa.todas, rot('Todas', mes.items.length)),
      // Segundo na fila, não último: "o que pago esta semana" é a pergunta do
      // dia a dia, e ficaria escondido no fim de uma lista que rola.
      (FiltroDespesa.semana, rot('Esta semana', daSemana)),
      (FiltroDespesa.emAberto, rot('Em aberto', abertas)),
      (FiltroDespesa.vencidas, rot('Vencidas', vencidas)),
      (FiltroDespesa.pagas, rot('Pagas', pagas)),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opcoes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (valor, rotulo) = opcoes[i];
          return _FiltroChip(
            label: rotulo,
            selected: atual == valor,
            onTap: () => ref.read(filtroDespesaProvider.notifier).definir(valor),
          );
        },
      ),
    );
  }
}

/// Chip de filtro. Mesma linguagem visual do seletor de relatórios (pílula
/// grafite quando ativa) — o design system não tem um chip selecionável
/// genérico, e criar um exigiria uma refatoração maior que esta tela.
class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
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
      borderRadius: BorderRadius.circular(999),
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : neu.raised(),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? neu.onNavy : neu.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Uma conta na lista.
class _LinhaDespesa extends ConsumerStatefulWidget {
  const _LinhaDespesa({
    required this.despesa,
    required this.categoria,
    required this.hoje,
    this.proxima,
  });

  final Expense despesa;
  final ExpenseCategory? categoria;
  final DateTime hoje;

  /// Quando a conta vai ser cobrada de novo (fixa ou parcelada). Calculada pela
  /// lista, que tem as regras e as irmãs em mãos.
  final DateTime? proxima;

  @override
  ConsumerState<_LinhaDespesa> createState() => _LinhaDespesaState();
}

class _LinhaDespesaState extends ConsumerState<_LinhaDespesa> {
  bool _ocupado = false;

  /// Menu de ações da conta: editar, duplicar e excluir.
  ///
  /// Duplicar existe porque conta a pagar se repete de forma irregular (o mesmo
  /// fornecedor, valor diferente): recadastrar do zero era o caminho mais usado e
  /// o mais chato. Abre o formulário com tudo preenchido, MENOS a baixa — a
  /// cópia nasce em aberto, senão a nova conta apareceria paga sem ninguém pagar.
  Future<void> _abrirAcoes() async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Duplicar'),
              subtitle: const Text('Cria outra conta com os mesmos dados'),
              onTap: () => Navigator.pop(ctx, 'duplicar'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.neu.danger),
              title: Text(
                'Excluir',
                style: TextStyle(color: context.neu.danger),
              ),
              onTap: () => Navigator.pop(ctx, 'excluir'),
            ),
          ],
        ),
      ),
    );
    if (acao == null || !mounted) return;
    switch (acao) {
      case 'editar':
        final ok = await showExpenseFormDialog(context, ref,
            atual: widget.despesa);
        if (ok) ref.invalidate(despesasDoMesProvider);
      case 'duplicar':
        // `atual` sem id de baixa: o formulário trata como NOVA conta com os
        // campos pré-preenchidos.
        final base = widget.despesa.copyWith(
          id: '',
          paidAt: null,
          paidAmount: null,
          paidMethod: null,
        );
        final ok = await showExpenseFormDialog(context, ref, atual: base);
        if (ok) ref.invalidate(despesasDoMesProvider);
      case 'excluir':
        await _excluir();
    }
  }

  Future<void> _excluir() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Excluir despesa?',
      message: '"${widget.despesa.description}" sai da lista. '
          'Se ela já foi paga, o lançamento no caixa NÃO é desfeito — '
          'revogue o pagamento antes se for o caso.',
      confirmLabel: 'Excluir',
      danger: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(expensesRepositoryProvider).cancelar(widget.despesa.id);
      ref.invalidate(despesasDoMesProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternarPago() async {
    setState(() => _ocupado = true);
    final repo = ref.read(expensesRepositoryProvider);
    final estavaPaga = widget.despesa.pago;
    try {
      if (estavaPaga) {
        await repo.desmarcarPaga(widget.despesa.id);
      } else {
        await repo.marcarPaga(widget.despesa.id);
      }
      ref.invalidate(despesasDoMesProvider);
      // Ao dar baixa numa conta que volta, dizer QUANDO ela volta. Sem isso
      // pagar parece encerrar o assunto — e o aluguel reaparece no mês que vem
      // sem aviso. Pedido explícito do dono.
      final prox = widget.proxima;
      if (!estavaPaga && prox != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pago. Próxima cobrança em ${_dataCompleta(prox)}.'),
        ));
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // `finally`, não só no catch: o reset estava apenas no ramo de ERRO, então
      // o caminho de SUCESSO deixava `_ocupado = true` para sempre e a linha
      // ficava com o spinner girando — o "load infinito" ao dar baixa ou
      // revogar. O invalidate acima recarrega a lista, mas se o Flutter reusar
      // este State (mesma posição na lista) ele volta com o flag preso.
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// "10/09/2026" — com ANO. O card mostrava só dia/mês, e conta parcelada ou
  /// atrasada de dezembro passado ficava indistinguível da deste ano.
  static String _dataCompleta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Terceira linha do card: fornecedor, forma do pagamento e próxima cobrança.
  ///
  /// Só aparece quando há o que dizer — linha vazia reservada engordaria toda a
  /// lista para servir a minoria das contas.
  List<Widget> _detalhesExtra(NeuTokens neu) {
    final e = widget.despesa;
    final partes = <(IconData, String)>[
      if ((e.supplierName ?? '').trim().isNotEmpty)
        (Icons.storefront_outlined, e.supplierName!.trim()),
      if (e.pago && (e.paidMethod ?? '').isNotEmpty)
        (Icons.payments_outlined, methodLabel(e.paidMethod!)),
      if (widget.proxima != null)
        (Icons.event_repeat_outlined,
            'Próxima ${_dataCompleta(widget.proxima!)}'),
    ];
    if (partes.isEmpty) return const [];

    return [
      const SizedBox(height: 4),
      Row(
        children: [
          for (final (i, p) in partes.indexed) ...[
            if (i > 0)
              Text(' · ', style: TextStyle(color: neu.inkFaint, fontSize: 12)),
            Icon(p.$1, size: 12, color: neu.inkFaint),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                p.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final e = widget.despesa;
    final s = e.situacao(widget.hoje);
    final corStatus = corDoStatus(neu, s);
    final corCat = corHex(widget.categoria?.color);
    final dias = diasAte(e.vencimento, widget.hoje);
    // Vencida e vencendo hoje ganham uma FAIXA da cor do status na borda. Cor de
    // texto sozinha se perde numa lista longa; a faixa deixa o olho achar o
    // problema sem ler nada. As demais não ganham para a faixa continuar
    // significando algo.
    final destacar =
        s == ExpenseStatus.vencido || s == ExpenseStatus.venceHoje;

    return NeuCard(
      padding: EdgeInsets.zero,
      // O card inteiro abre o detalhe. Antes só os dois botões da direita
      // respondiam, e ver a conta exigia adivinhar que "editar" era o caminho.
      onTap: _ocupado ? null : () => _abrirDetalhe(),
      child: Row(
        children: [
          if (destacar)
            Container(
              width: 4,
              // Alto o suficiente para acompanhar o card em qualquer altura de
              // conteúdo (a Row estica os filhos ao maior deles).
              constraints: const BoxConstraints(minHeight: 62),
              decoration: BoxDecoration(
                color: corStatus,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(NeuTokens.rCard),
                ),
              ),
            )
          else
            const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
              child: Row(
                children: [
                  // Selo da categoria: ícone + cor própria. Identidade visual da
                  // categoria, separada da cor de status (na faixa e no texto).
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: corCat.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconeDaCategoria(widget.categoria?.icon),
                      size: 21,
                      color: corCat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                e.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: neu.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  // Pago fica riscado: reforça "resolvido" sem
                                  // depender só da cor.
                                  decoration:
                                      e.pago ? TextDecoration.lineThrough : null,
                                  decorationColor: neu.inkFaint,
                                ),
                              ),
                            ),
                            // "2/6" é a informação que faltava: sem ela duas
                            // parcelas da mesma compra são duas linhas idênticas.
                            if (e.parcelada) ...[
                              const SizedBox(width: 6),
                              _SeloParcela(rotulo: e.rotuloParcela),
                            ],
                            if (e.fixa) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Repete todo mês',
                                child: Icon(Icons.autorenew_rounded,
                                    size: 14, color: neu.inkFaint),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(iconeDoStatus(s), size: 13, color: corStatus),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                textoDoPrazo(s, dias),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: corStatus,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (widget.categoria != null) ...[
                              Text(' · ',
                                  style: TextStyle(
                                      color: neu.inkFaint, fontSize: 12.5)),
                              Flexible(
                                child: Text(
                                  widget.categoria!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: neu.inkMuted, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        ..._detalhesExtra(neu),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // "Valor a confirmar" em vez de R$ 0,00: zero leria como
                        // "não devo nada", o oposto do que a linha significa.
                        e.temValor ? formatMoney(e.valorEfetivo) : 'a confirmar',
                        style: TextStyle(
                          color: e.temValor ? neu.ink : neu.inkMuted,
                          fontSize: e.temValor ? 15.5 : 13,
                          fontWeight: FontWeight.w800,
                          fontStyle: e.temValor ? null : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dataCompleta(e.vencimento),
                        style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  if (_ocupado)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    NeuIconButton(
                      icon: e.pago
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                      tooltip:
                          e.pago ? 'Desfazer pagamento' : 'Marcar como paga',
                      onPressed: _alternarPago,
                    ),
                  // Editar / duplicar / excluir. Botão VISÍVEL, não gesto
                  // escondido: descobrir a ação por toque longo não é
                  // descoberta, é sorte.
                  NeuIconButton(
                    icon: Icons.more_vert_rounded,
                    tooltip: 'Mais ações',
                    onPressed: _ocupado ? null : _abrirAcoes,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDetalhe() async {
    final mudou = await showExpenseDetailDialog(
      context,
      ref,
      id: widget.despesa.id,
    );
    if (mudou) ref.invalidate(despesasDoMesProvider);
  }
}

/// Selo "2/6" da parcela.
class _SeloParcela extends StatelessWidget {
  const _SeloParcela({required this.rotulo});

  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: neu.navy.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          color: neu.inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentar});

  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: neu.inkFaint),
          const SizedBox(height: 12),
          Text(mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkMuted)),
          const SizedBox(height: 14),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            onPressed: onTentar,
          ),
        ],
      ),
    );
  }
}
