import 'package:flutter/material.dart';

/// Componentes de gráfico reutilizáveis do OrbixHub (`core/widgets/charts`).
///
/// Filosofia: NÃO estilizar caso a caso. As telas (relatórios, dashboard) só
/// montam um [ChartCard] e passam dados para [OrbixLineChart]/[OrbixBarChart]/
/// [OrbixDonutChart]. Tudo é tema-aware (lê `colorScheme`, usa a cor primária da
/// oficina — `scheme.primary`) e responsivo (fl_chart preenche a largura). Sem
/// cores hardcoded que quebrem no claro/escuro.
///
/// Este arquivo concentra os utilitários compartilhados: formatação pt-BR de
/// moeda/data para os eixos, a casca de card e os estados vazio / ponto único.

// ---------------------------------------------------------------------------
// Formatação pt-BR (eixos, tooltips)
// ---------------------------------------------------------------------------

/// Moeda compacta para rótulos de eixo: "R$ 1,2 mil", "R$ 3,4 mi". Mantém os
/// eixos legíveis sem estourar a largura. Para o tooltip/valores exatos use
/// `formatMoney` (em `metric_card.dart`).
String compactMoney(num value) {
  final abs = value.abs();
  if (abs >= 1000000) return 'R\$ ${_compact(value / 1000000)} mi';
  if (abs >= 1000) return 'R\$ ${_compact(value / 1000)} mil';
  return 'R\$ ${value.round()}';
}

/// Número compacto sem moeda (eixo de quantidade): "1,2 mil", "3 mi".
String compactNumber(num value) {
  final abs = value.abs();
  if (abs >= 1000000) return '${_compact(value / 1000000)} mi';
  if (abs >= 1000) return '${_compact(value / 1000)} mil';
  return value % 1 == 0 ? value.round().toString() : _compact(value);
}

/// Uma casa decimal com vírgula, sem `,0` redundante (1,0 → "1").
String _compact(num value) {
  final s = value.toStringAsFixed(1);
  final clean = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  return clean.replaceAll('.', ',');
}

/// Data curta "dd/MM" para o eixo X de séries temporais.
String axisDayMonth(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}';
}

/// Data por extenso curta "dd/MM/aaaa" para o tooltip.
String tooltipDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

// ---------------------------------------------------------------------------
// Casca de card + estados
// ---------------------------------------------------------------------------

/// Casca padrão de um card de gráfico: título, subtítulo opcional e o gráfico
/// numa altura estável. Mesmo visual dos demais cards (surface clara/escura,
/// borda hairline, raio 16). [actions] (ex.: legenda inline) ficam à direita do
/// título.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.height = 240,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?actions,
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Acessibilidade dos gráficos (auditoria SysOne §5)
// ---------------------------------------------------------------------------

/// Envelope de acessibilidade do canvas de um gráfico.
///
/// O fl_chart pinta num `Canvas`: para um leitor de tela o gráfico inteiro é um
/// buraco, e o valor de cada ponto só existe no tooltip de **hover**. A
/// auditoria SysOne pede o oposto — "todo valor relevante precisa ser lido
/// corretamente em seu estado enabled, não apenas disponível visualmente por
/// hover de mouse" — e, para o desenho puramente decorativo, "marcar como
/// decorativo para leitores de tela e manter o texto associado como a fonte
/// oficial da informação".
///
/// É o que este widget faz: o desenho sempre sai da árvore de acessibilidade
/// ([ExcludeSemantics], equivalente ao `aria-hidden="true"` da recomendação) e,
/// quando não há legenda de texto ao lado que já anuncie nome + valor, um
/// [resumo] textual entra no lugar dele.
///
/// Passe `resumo: null` **só** quando existir legenda em texto real (é o caso
/// dos donuts, que listam categoria e valor ao lado) — aí a legenda já é a
/// fonte oficial e repetir tudo no rótulo semântico só faz o leitor ler duas
/// vezes.
class ChartSemantics extends StatelessWidget {
  const ChartSemantics({super.key, required this.child, this.resumo});

  final Widget child;
  final String? resumo;

  @override
  Widget build(BuildContext context) {
    final desenho = ExcludeSemantics(child: child);
    if (resumo == null) return desenho;
    return Semantics(container: true, label: resumo, child: desenho);
  }
}

/// Resumo textual de uma série temporal, para o [ChartSemantics].
///
/// Descreve período, extremos e valor final — o que responde "como foi o
/// período?" sem obrigar o leitor a ouvir 90 pontos em sequência. O detalhe
/// ponto a ponto fica nas tabelas do relatório, que são texto de verdade.
String resumoSerie(
  String nome,
  List<({DateTime data, double valor})> pontos,
  String Function(double) formatar,
) {
  if (pontos.isEmpty) return '$nome: sem dados no período.';
  if (pontos.length == 1) {
    return '$nome: ${formatar(pontos.first.valor)} em '
        '${axisDayMonth(pontos.first.data)}.';
  }
  var menor = pontos.first, maior = pontos.first;
  for (final p in pontos) {
    if (p.valor < menor.valor) menor = p;
    if (p.valor > maior.valor) maior = p;
  }
  final ultimo = pontos.last;
  return '$nome: ${pontos.length} pontos, de ${axisDayMonth(pontos.first.data)} '
      'a ${axisDayMonth(ultimo.data)}. '
      'Menor ${formatar(menor.valor)} em ${axisDayMonth(menor.data)}, '
      'maior ${formatar(maior.valor)} em ${axisDayMonth(maior.data)}, '
      'último ${formatar(ultimo.valor)} em ${axisDayMonth(ultimo.data)}.';
}

/// Estado vazio dentro de um gráfico: ícone + mensagem centralizados. Usado
/// quando não há nenhum ponto no período.
class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({super.key, this.message = 'Sem dados no período.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 30, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Estado de ponto único: com um só dado, uma linha/barra "solta" não tem
/// contexto (foi o bug original). Em vez disso mostramos o valor em destaque com
/// sua legenda — honesto e legível.
class ChartSinglePoint extends StatelessWidget {
  const ChartSinglePoint({
    super.key,
    required this.value,
    required this.caption,
  });

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'Apenas um ponto no período — sem série para traçar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
