import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
// Rótulo PT-BR da forma de pagamento — função PURA do caixa, reaproveitada em
// vez de duplicada. Mesmo caso de `formatMoney` do dashboard, logo acima: não é
// acesso a dado de outro módulo, é vocabulário compartilhado.
import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../../dashboard/presentation/widgets/metric_card.dart' show formatMoney;
import '../domain/expense_installment_payment.dart';
import '../domain/expense_models.dart';
import '../domain/expense_next_due.dart';
import '../domain/expense_ordering.dart';
import '../domain/expense_status.dart';
import 'expense_detail_dialog.dart';
import 'expense_form_dialog.dart';
import 'expense_visuals.dart';
import 'expenses_providers.dart';
import 'month_picker_dialog.dart';

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
        //
        // Tocável: as setas resolvem "mês que vem", mas chegar em dezembro do
        // ano passado custava treze toques. O rótulo é o alvo óbvio para isso —
        // é onde a pessoa já está olhando para saber em que mês está.
        SizedBox(
          width: compacto ? 150 : 190,
          child: InkWell(
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            onTap: () async {
              final escolhido = await showMonthPickerDialog(
                context,
                inicial: mes,
              );
              if (escolhido != null) {
                ref.read(mesEmFocoProvider.notifier).definir(escolhido);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '${_meses[mes.month - 1]} ${mes.year}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: compacto ? 16 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // A setinha é o que denuncia que o rótulo abre algo — sem ela,
                  // texto tocável é descoberta por acidente.
                  Icon(
                    Icons.expand_more_rounded,
                    size: compacto ? 18 : 20,
                    color: neu.inkFaint,
                  ),
                ],
              ),
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

    // A LIXEIRA vem de outra fonte (o servidor só manda as ativas na listagem
    // normal), então ela tem o próprio corpo — carregando, erro e vazio
    // inclusive. Os totais e os filtros continuam no topo para a cliente saber
    // de que mês é o lixo que está vendo e ter como voltar.
    if (filtro == FiltroDespesa.excluidas) {
      return ListView(
        padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 4 : 8),
        children: [
          _Totais(mes: mes),
          const SizedBox(height: 14),
          _Filtros(mes: mes, hoje: hoje),
          const SizedBox(height: 12),
          _CorpoLixeira(hoje: hoje, categorias: porId),
          const SizedBox(height: 24),
        ],
      );
    }

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
              FiltroDespesa.excluidas => true, // tratado acima
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
                // Resumo do parcelamento: o total da compra NÃO é derivável do
                // mês (só vêm as parcelas que vencem nele), então o servidor
                // manda.
                grupo: e.installmentGroupId == null
                    ? null
                    : mes.installmentGroups
                        .where((g) => g.groupId == e.installmentGroupId)
                        .firstOrNull,
                // Qual parcela precisa ser paga antes desta, se houver.
                //
                // Dá para responder com o que já está na tela: as irmãs
                // ANTERIORES em aberto sempre aparecem na listagem do mês (conta
                // vencida e não paga é arrastada para os meses seguintes), e são
                // exatamente elas que bloqueiam. As posteriores não importam.
                bloqueadaPor: e.installmentGroupId == null
                    ? null
                    : parcelaQueBloqueia(
                        mes.items
                            .where((o) =>
                                o.installmentGroupId == e.installmentGroupId)
                            .toList(),
                        alvo: e,
                      ),
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

/// A LIXEIRA do mês: contas excluídas, com restaurar e apagar de vez.
///
/// Widget próprio porque a fonte é outra ([despesasExcluidasProvider]) e por
/// isso tem os próprios estados de carregando/erro — enfiar isso no corpo normal
/// misturaria dois carregamentos independentes numa tela só.
class _CorpoLixeira extends ConsumerWidget {
  const _CorpoLixeira({required this.hoje, required this.categorias});

  final DateTime hoje;
  final Map<String, ExpenseCategory> categorias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(despesasExcluidasProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: NeuEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar',
          // A lixeira é online-only (ver LocalFirstExpensesRepository): sem rede
          // a mensagem do repositório já explica isso, e repeti-la aqui é melhor
          // que um erro genérico.
          message: e is AppException
              ? e.message
              : 'Tente de novo em instantes.',
        ),
      ),
      data: (lixeira) {
        if (lixeira.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 32),
            child: NeuEmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'Nada excluído neste mês',
              message: 'O que você excluir aparece aqui e pode voltar para a '
                  'lista. Nada é apagado de verdade sem você mandar.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Aviso do que a tela É. Sem ele, uma lista de contas idêntica à
            // normal, só que com outros botões, se confunde com a de verdade.
            _AvisoLixeira(quantas: lixeira.items.length),
            const SizedBox(height: 10),
            for (final e in lixeira.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinhaDespesa(
                  despesa: e,
                  categoria: categorias[e.categoryId],
                  hoje: hoje,
                  naLixeira: true,
                  grupo: e.installmentGroupId == null
                      ? null
                      : lixeira.installmentGroups
                          .where((g) => g.groupId == e.installmentGroupId)
                          .firstOrNull,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Faixa que explica a lixeira. Curta: quem chegou aqui já sabe o que procura.
class _AvisoLixeira extends StatelessWidget {
  const _AvisoLixeira({required this.quantas});

  final int quantas;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.delete_outline_rounded, size: 18, color: neu.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quantas == 1
                  ? '1 despesa excluída. Ela não entra nos totais do mês.'
                  : '$quantas despesas excluídas. Elas não entram nos totais do mês.',
              style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
            ),
          ),
        ],
      ),
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
      // ÚLTIMO, e sem contagem: a lixeira não vem na listagem do mês (é outra
      // consulta), então não há número para mostrar sem uma ida extra ao
      // servidor a cada abertura da tela — e ninguém abre despesas para saber
      // quanto lixo tem.
      (FiltroDespesa.excluidas, 'Excluídas'),
    ];

    return _ChipsComIndicadorDeScroll(
      children: [
        for (final (valor, rotulo) in opcoes)
          _FiltroChip(
            label: rotulo,
            selected: atual == valor,
            onTap: () => ref.read(filtroDespesaProvider.notifier).definir(valor),
          ),
      ],
    );
  }
}

/// Lista horizontal com uma DICA de que dá para arrastar: uma seta some na
/// borda direita, esmaece sozinha quando a lista chega ao fim, e reaparece se
/// o usuário voltar. Sem isso, "Vencidas" e "Pagas" (que ficam fora da tela no
/// mobile) só existem para quem descobrisse o arrasto por acidente.
class _ChipsComIndicadorDeScroll extends StatefulWidget {
  const _ChipsComIndicadorDeScroll({required this.children});

  final List<Widget> children;

  @override
  State<_ChipsComIndicadorDeScroll> createState() =>
      _ChipsComIndicadorDeScrollState();
}

class _ChipsComIndicadorDeScrollState
    extends State<_ChipsComIndicadorDeScroll> {
  final _scroll = ScrollController();

  /// `null` enquanto o primeiro layout não rodou — evita a seta piscar (mostra
  /// e some) antes de sabermos se há conteúdo fora da tela.
  bool? _temMaisPraVer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_atualizar);
    // Só depois do 1º frame o `maxScrollExtent` existe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizar());
  }

  @override
  void dispose() {
    _scroll.removeListener(_atualizar);
    _scroll.dispose();
    super.dispose();
  }

  void _atualizar() {
    if (!_scroll.hasClients) return;
    // Pequena folga (2px) para não deixar a seta piscando bem no finalzinho
    // por causa de arredondamento de subpixel.
    final noFim =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 2;
    final valor = _scroll.position.maxScrollExtent > 0 && !noFim;
    if (valor != _temMaisPraVer) setState(() => _temMaisPraVer = valor);
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: widget.children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => widget.children[i],
          ),
          if (_temMaisPraVer ?? false)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                // Não intercepta o toque: é só indicação visual, o arrasto
                // continua funcionando por baixo dela.
                child: Container(
                  width: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [neu.base.withValues(alpha: 0), neu.base],
                    ),
                  ),
                  alignment: Alignment.center,
                  // Ícone DIFERENTE do "próximo mês" do cabeçalho (mesma
                  // tela): duplo-chevron é o vocabulário comum de "role para
                  // ver mais", e não colide com outra seta já presente aqui.
                  child: Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    size: 16,
                    color: neu.inkFaint,
                  ),
                ),
              ),
            ),
        ],
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
            fontSize: 14,
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
    this.grupo,
    this.naLixeira = false,
    this.bloqueadaPor,
  });

  final Expense despesa;
  final ExpenseCategory? categoria;
  final DateTime hoje;

  /// A parcela que precisa ser paga ANTES desta (parcela se paga na ordem), ou
  /// `null` quando é a vez desta. Calculada pela lista, que tem as irmãs do mês.
  final Expense? bloqueadaPor;

  /// `true` quando o card está na LIXEIRA. Muda as ações: dar baixa numa conta
  /// excluída não significa nada, então o toque rápido some e o menu passa a
  /// oferecer restaurar e apagar de vez.
  final bool naLixeira;

  /// Resumo do parcelamento (total da compra e quantas pagas), quando é parcela.
  final InstallmentGroupSummary? grupo;

  /// Quando a conta vai ser cobrada de novo (fixa ou parcelada). Calculada pela
  /// lista, que tem as regras e as irmãs em mãos.
  final DateTime? proxima;

  @override
  ConsumerState<_LinhaDespesa> createState() => _LinhaDespesaState();
}

class _LinhaDespesaState extends ConsumerState<_LinhaDespesa> {
  bool _ocupado = false;

  /// Menu da LIXEIRA: restaurar ou apagar de vez.
  ///
  /// Separado de [_abrirAcoes] porque não é o mesmo menu com itens a mais — é
  /// outro conjunto de ações. Editar e dar baixa numa conta excluída não
  /// significam nada, e oferecê-las convidaria a mexer no lixo em vez de
  /// restaurar primeiro.
  Future<void> _executarAcaoLixeira(String acao) async {
    switch (acao) {
      case 'restaurar':
        await _restaurar();
      case 'apagar':
        await _apagarDeVez();
    }
  }

  Future<void> _restaurar() async {
    setState(() => _ocupado = true);
    try {
      await ref.read(expensesRepositoryProvider).restaurar(widget.despesa.id);
      // As DUAS listas mudam: a conta sai da lixeira e volta para o mês.
      ref.invalidate(despesasExcluidasProvider);
      ref.invalidate(despesasDoMesProvider);
      if (mounted) {
        showNeuSuccessSnackBar(
          context,
          widget.despesa.parcelada
              ? 'Compra restaurada.'
              : 'Despesa restaurada.',
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      showNeuErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Hard delete, com a confirmação proporcional ao estrago.
  ///
  /// O aviso diz exatamente O QUE some (a compra inteira, quando é parcelada) e
  /// que não há volta — é a última tela antes da única operação irreversível do
  /// sistema.
  Future<void> _apagarDeVez() async {
    final e = widget.despesa;
    final quantas = widget.grupo?.count ?? 0;
    final ok = await showNeuConfirm(
      context,
      title: 'Apagar de vez?',
      message: e.parcelada && quantas > 1
          ? '"${e.description}" e as $quantas parcelas da compra serão apagadas '
              'para sempre. Não é possível restaurar depois.'
          : '"${e.description}" será apagada para sempre. '
              'Não é possível restaurar depois.',
      confirmLabel: 'Apagar de vez',
      danger: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(expensesRepositoryProvider).excluirDeVez(e.id);
      ref.invalidate(despesasExcluidasProvider);
      if (mounted) showNeuSuccessSnackBar(context, 'Apagada de vez.');
    } on AppException catch (erro) {
      // O caminho comum de recusa: conta com pagamento no caixa. A mensagem do
      // servidor explica o motivo melhor que qualquer tradução aqui.
      if (!mounted) return;
      showNeuErrorSnackBar(context, erro.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Menu de ações da conta: editar e excluir.
  ///
  /// **Duplicar está desligado** (comentado abaixo, junto com o `case` que o
  /// atende) — decisão do dono do produto. O suporte no formulário continua de
  /// pé e funcionando: `showExpenseFormDialog(modelo: ...)` cria uma conta nova
  /// usando outra como molde. Para reativar basta descomentar os dois trechos
  /// marcados com `DUPLICAR`; nada além disso é necessário.
  ///
  /// A ideia original: conta a pagar se repete de forma irregular (o mesmo
  /// fornecedor, valor diferente), e recadastrar do zero era o caminho mais
  /// usado e o mais chato.
  Future<void> _executarAcao(String acao) async {
    switch (acao) {
      case 'editar':
        final g = widget.grupo;
        final ok = await showExpenseFormDialog(
          context,
          ref,
          atual: widget.despesa,
          // O resumo do grupo já traz o total da compra e quantas foram pagas —
          // é o que o formulário precisa para editar o TOTAL em vez do valor
          // desta parcela.
          compra: widget.despesa.parcelada && g != null
              ? (total: g.total, pagas: g.paidCount)
              : null,
        );
        if (ok) ref.invalidate(despesasDoMesProvider);
      // DUPLICAR — desligado a pedido do dono do produto. Descomente junto com
      // o item do menu lá embaixo.
      //
      // `modelo`, não `atual`: o formulário preenche os campos a partir desta
      // conta mas grava uma NOVA. Passar em `atual` com o id apagado — como era
      // antes — só fazia o formulário entrar em modo edição e salvar num
      // `PATCH /expenses/` sem id, que o backend responde com 404.
      //
      // case 'duplicar':
      //   final ok =
      //       await showExpenseFormDialog(context, ref, modelo: widget.despesa);
      //   if (ok) ref.invalidate(despesasDoMesProvider);
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
      showNeuErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternarPago() async {
    // Parcela fora de ordem nem chega a virar requisição: o servidor recusaria
    // com 409, e gastar uma ida à rede para saber o que a tela já sabe deixa o
    // toque com cara de travado.
    final bloqueio = widget.bloqueadaPor;
    if (!widget.despesa.pago && bloqueio != null) {
      showNeuErrorSnackBar(
        context,
        'Pague antes a parcela ${bloqueio.rotuloParcela}, que vence em '
        '${_dataCompleta(bloqueio.vencimento)}.',
      );
      return;
    }

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
        showNeuSuccessSnackBar(context, 'Pago. Próxima cobrança em ${_dataCompleta(prox)}.');
      }
    } on AppException catch (e) {
      if (!mounted) return;
      showNeuErrorSnackBar(context, e.message);
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
    final g = widget.grupo;
    final partes = <(IconData, String)>[
      // "de R$ 900,00 · 2 de 6 pagas": o valor grande do card é o da PARCELA (o
      // que se deve neste mês); o total da compra é o contexto que faltava.
      if (g != null && g.total > 0)
        (
          Icons.view_week_outlined,
          'de ${formatMoney(g.total)} · ${g.paidCount} de ${g.count} pagas',
        ),
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
      // `Row` com CADA texto em `Flexible`: a causa raiz do overflow aqui não
      // era o número de partes, era a coluna do VALOR sem teto (ver o
      // `ConstrainedBox` na coluna do preço) comendo quase o card inteiro —
      // corrigido lá, sobra largura real para negociar aqui. Com 2 ou 3 partes
      // presentes, cada uma cede espaço para as outras (ellipsis), o que é bem
      // melhor que estourar a tela: é informação secundária.
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
                  //
                  // Menor no mobile: junto com os 2 botões de ação e o valor,
                  // era o que faltava para o nome/status terem espaço real — não
                  // adianta só truncar mais texto se dá para devolver largura.
                  Container(
                    width: context.isMobile ? 32 : 40,
                    height: context.isMobile ? 32 : 40,
                    decoration: BoxDecoration(
                      color: corCat.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconeDaCategoria(widget.categoria?.icon),
                      size: context.isMobile ? 17 : 21,
                      color: corCat,
                    ),
                  ),
                  SizedBox(width: context.isMobile ? 8 : 12),
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
                        // A causa raiz do overflow desta linha (e da coluna do
                        // título) era a coluna do VALOR sem teto de largura (ver
                        // o `ConstrainedBox` na coluna do preço, mais abaixo) —
                        // ela sozinha comia quase o card inteiro num celular,
                        // deixando ~0px para tudo aqui. Corrigido lá, `Row` +
                        // `Flexible` volta a funcionar normalmente: a categoria
                        // (secundária) cede espaço para o status (o sinal que
                        // importa: cor + "vencido"/"hoje").
                        Row(
                          children: [
                            Icon(iconeDoStatus(s), size: 13, color: corStatus),
                            const SizedBox(width: 4),
                            // `Flexible`, não fixo: mesmo com o valor travado,
                            // "Vence em 10 dias" (16 caracteres) ainda não cabe
                            // sozinho num celular de 360px ao lado do ícone da
                            // categoria e dos 2 botões. `Flexible` NUNCA
                            // estoura — na pior das hipóteses trunca com "…", o
                            // que é sempre melhor que um erro de layout. Peso
                            // maior que a categoria: é o sinal mais importante.
                            Flexible(
                              flex: 3,
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
                            if (widget.categoria != null)
                              Flexible(
                                child: Text(
                                  ' · ${widget.categoria!.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: neu.inkMuted, fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                        ..._detalhesExtra(neu),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // TETO de largura — achado depurando o corte do nome: um
                  // `Column` que é filho DIRETO de uma `Row` (sem `Expanded`)
                  // recebe largura NÃO LIMITADA para se medir, e o valor em
                  // negrito ("R$ 2.500,00", 15.5pt bold) mede ~170px sozinho —
                  // quase o card inteiro num celular de 360px. Sem este teto, a
                  // coluna da descrição ficava com 0px (nome INVISÍVEL, não só
                  // cortado) e a Row ainda estourava por conta própria. Isto NÃO
                  // era um bug só de parcela: qualquer despesa com valor alto
                  // sofria, mesmo sem parcelamento.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "2/6" na coluna da DIREITA, não mais colado no
                        // título. No mobile o card já é apertado (ícone +
                        // texto + valor + 2 botões); um selo de largura fixa
                        // espremido ENTRE o nome e a borda cortava a descrição
                        // cedo demais. Aqui ele não disputa espaço com o
                        // nome — só com o valor, que já tem seu próprio teto.
                        if (e.parcelada) ...[
                          _SeloParcela(rotulo: e.rotuloParcela),
                          const SizedBox(height: 3),
                        ],
                        // `FittedBox` encolhe o valor em vez de estourar —
                        // mesmo padrão já usado em `_CardTotal` para o mesmo
                        // problema (valor grande, espaço pequeno).
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            // "Valor a confirmar" em vez de R$ 0,00: zero
                            // leria como "não devo nada", o oposto do que a
                            // linha significa.
                            e.temValor
                                ? formatMoney(e.valorEfetivo)
                                : 'a confirmar',
                            style: TextStyle(
                              color: e.temValor ? neu.ink : neu.inkMuted,
                              fontSize: e.temValor ? 15.5 : 13,
                              fontWeight: FontWeight.w800,
                              fontStyle: e.temValor ? null : FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dataCompleta(e.vencimento),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: neu.inkFaint, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Menor no mobile (38, contra o padrão 48): junto com o
                  // ícone da categoria já reduzido, é o que devolve largura
                  // real ao nome/status — sem isso, mesmo com texto flexível
                  // e valor travado, "Vence em 10 dias" continuava sem espaço
                  // nenhum para existir num celular de 360px.
                  Builder(builder: (context) {
                    final tamanho = context.isMobile ? 38.0 : 48.0;
                    if (_ocupado) {
                      return SizedBox(
                        width: tamanho,
                        height: tamanho,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    // Na lixeira o toque rápido vira RESTAURAR: dar baixa numa
                    // conta excluída não significa nada, e restaurar é o que
                    // 9 em 10 visitas à lixeira querem fazer.
                    if (widget.naLixeira) {
                      return NeuIconButton(
                        icon: Icons.restore_rounded,
                        tooltip: 'Restaurar',
                        size: tamanho,
                        onPressed: _restaurar,
                      );
                    }
                    return NeuIconButton(
                      icon: e.pago
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                      tooltip:
                          e.pago ? 'Desfazer pagamento' : 'Marcar como paga',
                      size: tamanho,
                      onPressed: _alternarPago,
                    );
                  }),
                  // Editar / excluir (ou restaurar / apagar de vez, na lixeira).
                  // Botão VISÍVEL, não gesto escondido: descobrir a ação por
                  // toque longo não é descoberta, é sorte.
                  _MenuAcoesDespesa(
                    naLixeira: widget.naLixeira,
                    parcelada: widget.despesa.parcelada,
                    habilitado: !_ocupado,
                    onSelected: widget.naLixeira
                        ? _executarAcaoLixeira
                        : _executarAcao,
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
          fontSize: 12,
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

/// Ações da linha de despesa nos MESMOS três pontinhos da lista de OS.
///
/// Era um bottom sheet: no desktop uma gaveta subia do rodapé da janela para
/// oferecer duas opções — longe do clique, cobrindo a tela e sem relação com a
/// linha que a abriu. O menu ancorado aparece onde se tocou e some ao escolher,
/// que é o comportamento que o resto do app já usa.
class _MenuAcoesDespesa extends StatelessWidget {
  const _MenuAcoesDespesa({
    required this.naLixeira,
    required this.parcelada,
    required this.habilitado,
    required this.onSelected,
  });

  final bool naLixeira;
  final bool parcelada;
  final bool habilitado;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      enabled: habilitado,
      padding: EdgeInsets.zero,
      color: neu.surface,
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert_rounded, size: 20, color: neu.inkMuted),
      onSelected: onSelected,
      itemBuilder: (_) => naLixeira
          // LIXEIRA: outro conjunto de ações, não o mesmo com itens a mais —
          // editar ou dar baixa numa conta excluída não significa nada.
          ? [
              PopupMenuItem(
                value: 'restaurar',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.restore_rounded, color: neu.success),
                  title: const Text('Restaurar'),
                  subtitle: Text(
                    parcelada
                        ? 'Devolve a compra inteira'
                        : 'Devolve para a lista',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'apagar',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.delete_forever_rounded, color: neu.danger),
                  title: Text(
                    'Apagar de vez',
                    style: TextStyle(color: neu.danger),
                  ),
                  subtitle: const Text('Não tem como desfazer'),
                ),
              ),
            ]
          : [
              const PopupMenuItem(
                value: 'editar',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              // DUPLICAR — desligado a pedido do dono do produto. Descomente
              // junto com o `case` em `_executarAcao`.
              //
              // const PopupMenuItem(
              //   value: 'duplicar',
              //   child: ListTile(
              //     dense: true,
              //     contentPadding: EdgeInsets.zero,
              //     leading: Icon(Icons.copy_all_outlined),
              //     title: Text('Duplicar'),
              //   ),
              // ),
              PopupMenuItem(
                value: 'excluir',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: neu.danger),
                  title: Text(
                    'Excluir',
                    style: TextStyle(color: neu.danger),
                  ),
                ),
              ),
            ],
    );
  }
}
