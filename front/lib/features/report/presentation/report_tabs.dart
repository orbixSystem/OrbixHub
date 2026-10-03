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
enum ReportTab { visao, dinheiro, operacao, clientes }

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
const Map<ReportKind, ReportTab> _abaDoRelatorio = {
  ReportKind.revenue: ReportTab.dinheiro,
  ReportKind.cashFlow: ReportTab.dinheiro,
  ReportKind.expenses: ReportTab.dinheiro,
  ReportKind.osOperational: ReportTab.operacao,
  ReportKind.team: ReportTab.operacao,
  ReportKind.topItems: ReportTab.operacao,
  ReportKind.inventoryPosition: ReportTab.operacao,
  ReportKind.customers: ReportTab.clientes,
};

const _ordem = [
  (ReportTab.visao, 'Visão', Icons.insights_rounded),
  (ReportTab.dinheiro, 'Dinheiro', Icons.payments_outlined),
  (ReportTab.operacao, 'Operação', Icons.build_outlined),
  (ReportTab.clientes, 'Clientes', Icons.people_alt_outlined),
];

/// As abas que este usuário deve ver, derivadas SOMENTE do `/me`.
///
/// Função pura (testada), igual a [availableReports] — e construída EM CIMA
/// dela, para que a régua de "quem vê o quê" continue num lugar só.
///
/// Aba sem nenhum relatório disponível não aparece: uma oficina que não
/// contratou clientes não deve ver uma aba "Clientes" vazia explicando que
/// está vazia. A "Visão" é a exceção — ela existe sempre que Relatórios
/// existe, porque é a própria leitura do mês.
List<ReportTabSpec> abasDisponiveis(Me me) {
  final disponiveis = availableReports(me).map((r) => r.kind).toSet();
  if (disponiveis.isEmpty) return const [];

  final abas = <ReportTabSpec>[];
  for (final (tab, label, icon) in _ordem) {
    final secoes = _abaDoRelatorio.entries
        .where((e) => e.value == tab && disponiveis.contains(e.key))
        .map((e) => e.key)
        .toList();
    if (tab == ReportTab.visao || secoes.isNotEmpty) {
      abas.add(
        ReportTabSpec(tab: tab, label: label, icon: icon, secoes: secoes),
      );
    }
  }
  return abas;
}
