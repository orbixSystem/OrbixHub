import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cashier/domain/cashier_format.dart';
import '../../../os/presentation/os_status.dart';
import '../report_providers.dart';
import '../report_tabs.dart';
import 'barra_de_filtros.dart';
import 'filtro_de_periodo.dart';

/// Quais filtros cada aba mostra.
///
/// Um filtro só entra numa aba quando há o que ele recorte ali: oferecer
/// "forma de pagamento" na aba de Despesas seria um controle que não muda
/// nada, e um filtro que não muda nada ensina a ignorar a barra inteira.
///
/// O relatório escrito não aparece aqui: ele é um texto de um mês fechado, e
/// recortá-lo por técnico ou por forma de pagamento deixaria a prosa falando
/// de números que não estão mais na tela.
const Map<ReportTab, List<FiltroDeAba>> filtrosDaAba = {
  ReportTab.visao: [],
  ReportTab.faturamento: [FiltroDeAba.tipoVenda, FiltroDeAba.pagamento],
  ReportTab.caixa: [FiltroDeAba.metodo],
  ReportTab.despesas: [FiltroDeAba.categoriaDespesa],
  ReportTab.ordens: [
    FiltroDeAba.responsavel,
    FiltroDeAba.statusOs,
    FiltroDeAba.buscaOs,
  ],
  ReportTab.equipe: [FiltroDeAba.responsavel],
  ReportTab.clientes: [],
  ReportTab.estoque: [FiltroDeAba.buscaEstoque, FiltroDeAba.situacaoEstoque],
};

/// A linha de filtros de uma aba: o período e os recortes daquele assunto.
///
/// O PERÍODO vem sempre, e primeiro. É o filtro que governa todo o resto da
/// página, e deixá-lo noutro canto da tela — como estava, no cabeçalho —
/// separava a pergunta "de quando?" das outras perguntas do mesmo recorte.
class FiltrosDaAba extends ConsumerWidget {
  const FiltrosDaAba({super.key, required this.aba});

  final ReportTab aba;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quais = filtrosDaAba[aba] ?? const <FiltroDeAba>[];
    final f = ref.watch(reportFiltersProvider);
    final notifier = ref.read(reportFiltersProvider.notifier);

    final chips = <Widget>[
      // Estoque é uma FOTO do agora: quantidade em prateleira não tem período,
      // e um seletor ali prometeria uma viagem no tempo que o dado não
      // permite.
      if (aba != ReportTab.estoque) const FiltroDePeriodo(),
      if (aba != ReportTab.estoque && quais.isNotEmpty)
        const DivisorDeFiltros(),
      for (final filtro in quais) _chip(context, ref, filtro, f, notifier),
    ];

    return BarraDeFiltros(
      filtros: chips,
      ativos: f.ativosEntre(quais),
      aoLimpar: () => notifier.limpar(quais),
    );
  }

  Widget _chip(
    BuildContext context,
    WidgetRef ref,
    FiltroDeAba filtro,
    ReportFilters f,
    ReportFiltersController n,
  ) {
    switch (filtro) {
      case FiltroDeAba.responsavel:
        final membros = ref.watch(reportMembersProvider).value ?? const [];
        return FiltroDeOpcao(
          rotulo: 'Responsável',
          icone: Icons.person_outline_rounded,
          valor: f.assignedTo,
          larguraMinima: 150,
          opcoes: [
            for (final m in membros) (valor: m.id, rotulo: m.name),
          ],
          aoMudar: n.setAssignedTo,
        );
      case FiltroDeAba.statusOs:
        return FiltroDeOpcao(
          rotulo: 'Situação da OS',
          icone: Icons.flag_outlined,
          valor: f.status,
          larguraMinima: 150,
          opcoes: [
            for (final s in osStatuses) (valor: s, rotulo: osStatusLabel(s)),
          ],
          aoMudar: n.setStatus,
        );
      case FiltroDeAba.buscaOs:
        return FiltroDeBusca(
          rotulo: 'Buscar nº ou cliente',
          valor: f.osQ,
          aoMudar: n.setOsQ,
        );
      case FiltroDeAba.tipoVenda:
        return FiltroDeOpcao(
          rotulo: 'Tipo',
          icone: Icons.category_outlined,
          valor: f.saleType,
          larguraMinima: 120,
          opcoes: const [
            (valor: 'servico', rotulo: 'Serviço'),
            (valor: 'produto', rotulo: 'Produto'),
          ],
          aoMudar: n.setSaleType,
        );
      case FiltroDeAba.pagamento:
        return FiltroDeOpcao(
          rotulo: 'Pagamento',
          icone: Icons.payments_outlined,
          valor: f.salePaymentStatus,
          larguraMinima: 140,
          opcoes: const [
            (valor: 'pago', rotulo: 'Pago'),
            (valor: 'parcial', rotulo: 'Parcial'),
            (valor: 'a_receber', rotulo: 'A receber'),
          ],
          aoMudar: n.setSalePaymentStatus,
        );
      case FiltroDeAba.metodo:
        return FiltroDeOpcao(
          rotulo: 'Forma de pagamento',
          icone: Icons.credit_card_outlined,
          valor: f.metodo,
          larguraMinima: 170,
          opcoes: [
            for (final m in cashierMethods) (valor: m, rotulo: methodLabel(m)),
          ],
          aoMudar: n.setMetodo,
        );
      case FiltroDeAba.categoriaDespesa:
        // As categorias vêm do próprio relatório do período: oferecer uma que
        // não tem lançamento no mês é oferecer uma tela vazia.
        final linhas = ref.watch(expensesReportProvider).value?.rows ?? const [];
        return FiltroDeOpcao(
          rotulo: 'Categoria',
          icone: Icons.sell_outlined,
          valor: f.categoriaDespesa,
          larguraMinima: 150,
          opcoes: [
            for (final l in linhas)
              (valor: l.categoryName, rotulo: l.categoryName),
          ],
          aoMudar: n.setCategoriaDespesa,
        );
      case FiltroDeAba.buscaEstoque:
        return FiltroDeBusca(
          rotulo: 'Buscar peça ou código',
          valor: f.estoqueQ,
          aoMudar: n.setEstoqueQ,
        );
      case FiltroDeAba.situacaoEstoque:
        return FiltroDeOpcao(
          rotulo: 'Situação',
          icone: Icons.inventory_2_outlined,
          valor: f.estoqueSituacao,
          larguraMinima: 150,
          opcoes: const [
            (valor: 'abaixo', rotulo: 'Abaixo do mínimo'),
            (valor: 'zerado', rotulo: 'Zerados'),
            (valor: 'ok', rotulo: 'Com estoque folgado'),
          ],
          aoMudar: n.setEstoqueSituacao,
        );
    }
  }
}
