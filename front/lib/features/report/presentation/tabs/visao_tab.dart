import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/monthly_models.dart';
import '../report_providers.dart';
import '../widgets/kpi_card.dart';
import '../widgets/resumo_mes_card.dart';
import '../widgets/visao_charts.dart';

/// A leitura do mês — a tela que Relatórios abre.
///
/// A ordem é a de quem vai decidir alguma coisa: primeiro o que aconteceu (o
/// texto), depois os números que o sustentam, depois o que merece atenção, e
/// por fim os gráficos que mostram o ritmo. O menu lateral de nove relatórios
/// pedia o contrário — que o dono soubesse o que procurar antes de ver
/// qualquer coisa.
class VisaoTab extends ConsumerWidget {
  const VisaoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visaoAsync = ref.watch(visaoMensalProvider);
    final resumoAsync = ref.watch(resumoMensalProvider);

    return visaoAsync.when(
      loading: () => const _Carregando(),
      error: (e, _) => _Erro(
        mensagem: e is AppException ? e.message : 'Não foi possível carregar.',
        onRetry: () => ref.invalidate(visaoMensalProvider),
      ),
      data: (visao) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // O texto primeiro. Se o mês ainda não fechou, a ausência do resumo
          // é explicada em vez de virar um buraco na tela.
          resumoAsync.when(
            loading: () => const _CarregandoResumo(),
            // Falha ao buscar o texto não pode esconder os números: eles são a
            // parte que não depende de nada externo.
            error: (_, _) => const SizedBox.shrink(),
            data: (pagina) {
              final resumo = pagina.resumo;
              return resumo == null
                  ? ResumoAindaNaoGerado(rotuloDoMes: visao.periodo.rotulo)
                  : ResumoMesCard(resumo: resumo);
            },
          ),
          const SizedBox(height: 18),
          _GradeDeKpis(kpis: visao.kpis),
          if (visao.sinais.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Sinais(sinais: visao.sinais),
          ],
          const SizedBox(height: 18),
          FaturamentoDoMesChart(serie: visao.graficos.serieDiaria),
          const SizedBox(height: 16),
          ParaOndeFoiChart(fatias: visao.graficos.despesasPorCategoria),
        ],
      ),
    );
  }
}

/// Os números do mês. Quatro por linha no desktop, dois no celular — a conta
/// que mantém o cartão legível sem virar coluna estreita.
class _GradeDeKpis extends StatelessWidget {
  const _GradeDeKpis({required this.kpis});

  final List<KpiMensal> kpis;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth >= 1000
            ? 4
            : c.maxWidth >= 640
                ? 3
                : 2;
        const gap = 14.0;
        final largura = (c.maxWidth - gap * (colunas - 1)) / colunas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < kpis.length; i++)
              SizedBox(
                width: largura,
                child: KpiCard(kpi: kpis[i], destaque: i == 0),
              ),
          ],
        );
      },
    );
  }
}

/// O que saiu da curva, direto dos sinais apurados no servidor.
///
/// Repete o que o texto já disse, de propósito: o texto é para ler, esta lista
/// é para bater o olho. E quando o resumo ainda não existe (mês corrente), é
/// ela quem entrega o alerta — o dono não deveria esperar o dia 1º para
/// descobrir que o fiado dobrou.
class _Sinais extends StatelessWidget {
  const _Sinais({required this.sinais});

  final List<SinalMensal> sinais;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O que merece atenção',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sinais.length; i++) ...[
            if (i > 0) Divider(height: 20, color: neu.line),
            _LinhaSinal(sinal: sinais[i]),
          ],
        ],
      ),
    );
  }
}

class _LinhaSinal extends StatelessWidget {
  const _LinhaSinal({required this.sinal});

  final SinalMensal sinal;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final cor = sinal.ehCritico
        ? neu.danger
        : sinal.ehAlerta
            ? neu.warning
            : neu.info;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            sinal.ehCritico
                ? Icons.error_outline_rounded
                : sinal.ehAlerta
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded,
            size: 18,
            color: cor,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sinal.titulo,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sinal.detalhe,
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _CarregandoResumo extends StatelessWidget {
  const _CarregandoResumo();

  @override
  Widget build(BuildContext context) => const NeuCard(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onRetry});

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: neu.danger, size: 28),
          const SizedBox(height: 10),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
