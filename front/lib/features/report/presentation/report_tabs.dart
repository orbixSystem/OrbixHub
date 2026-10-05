import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';
import 'report_catalog.dart';

/// As abas de Relatórios.
///
/// Substituem o menu lateral de nove itens. A diferença não é estética: o menu
/// exigia que o dono soubesse o que procurar ANTES de ver qualquer coisa — e
/// quem precisa de relatório normalmente não sabe. A aba "Visão" responde
/// "como foi o mês" sem ninguém escolher nada; as outras três agrupam os
/// detalhamentos por assunto, do jeito que a pergunta nasce ("quanto entrou?",
/// "como foi a oficina?", "quem são meus clientes?").
enum ReportTab {
  resumo,
  visao,
  faturamento,
  caixa,
  despesas,
  ordens,
  equipe,
  clientes,
  estoque,
}

class ReportTabSpec {
  const ReportTabSpec({
    required this.tab,
    required this.label,
    required this.icon,
    required this.secoes,
  });

  final ReportTab tab;
  final String label;
  final IconData icon;

  /// Os relatórios que moram nesta aba, na ordem em que aparecem. A aba
  /// "Visão" tem a lista vazia: ela não é uma coleção de relatórios, é a
  /// leitura do mês.
  final List<ReportKind> secoes;
}

/// Em que aba cada relatório mora. Fora da função de montagem para que a
/// resposta seja a mesma em qualquer lugar que precise dela.
/// Uma aba por assunto, e só um relatório por aba.
///
/// Antes três abas abrigavam oito relatórios empilhados, e a página de
/// "Dinheiro" rolava por três tabelas inteiras. Assunto por assunto a página
/// termina na altura da tela — e escolher uma aba é mais barato que rolar
/// procurando onde o próximo relatório começa.
const Map<ReportKind, ReportTab> _abaDoRelatorio = {
  ReportKind.revenue: ReportTab.faturamento,
  ReportKind.cashFlow: ReportTab.caixa,
  ReportKind.expenses: ReportTab.despesas,
  ReportKind.osOperational: ReportTab.ordens,
  ReportKind.topItems: ReportTab.ordens,
  ReportKind.team: ReportTab.equipe,
  ReportKind.inventoryPosition: ReportTab.estoque,
  ReportKind.customers: ReportTab.clientes,
};

const _ordem = [
  // O relatório escrito abre Relatórios. É a única página que responde "como
  // foi o mês" em palavras, para quem não vai ler gráfico nenhum — e por isso
  // vem antes do painel, que é a mesma resposta em desenho.
  (ReportTab.resumo, 'Relatório do mês', Icons.auto_awesome_rounded),
  (ReportTab.visao, 'Visão geral', Icons.insights_rounded),
  (ReportTab.faturamento, 'Faturamento', Icons.trending_up_rounded),
  (ReportTab.caixa, 'Caixa', Icons.point_of_sale_outlined),
  (ReportTab.despesas, 'Despesas', Icons.receipt_long_outlined),
  (ReportTab.ordens, 'Ordens', Icons.build_outlined),
  (ReportTab.equipe, 'Equipe', Icons.groups_outlined),
  (ReportTab.clientes, 'Clientes', Icons.people_alt_outlined),
  (ReportTab.estoque, 'Estoque', Icons.inventory_2_outlined),
];

/// As abas que este usuário deve ver, derivadas SOMENTE do `/me`.
///
/// Função pura (testada), igual a [availableReports] — e construída EM CIMA
/// dela, para que a régua de "quem vê o quê" continue num lugar só.
///
/// Aba sem nenhum relatório disponível não aparece: uma oficina que não
/// contratou clientes não deve ver uma aba "Clientes" vazia explicando que
/// está vazia. O "Relatório do mês" e a "Visão geral" são as exceções — as
/// duas existem sempre que Relatórios existe, porque são a leitura do mês
/// (uma em palavras, a outra em gráficos).
List<ReportTabSpec> abasDisponiveis(Me me) {
  final disponiveis = availableReports(me).map((r) => r.kind).toSet();
  if (disponiveis.isEmpty) return const [];

  final abas = <ReportTabSpec>[];
  for (final (tab, label, icon) in _ordem) {
    final secoes = _abaDoRelatorio.entries
        .where((e) => e.value == tab && disponiveis.contains(e.key))
        .map((e) => e.key)
        .toList();
    if (tab == ReportTab.resumo ||
        tab == ReportTab.visao ||
        secoes.isNotEmpty) {
      abas.add(
        ReportTabSpec(tab: tab, label: label, icon: icon, secoes: secoes),
      );
    }
  }
  return abas;
}
