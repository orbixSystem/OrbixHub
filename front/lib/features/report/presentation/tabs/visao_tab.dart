import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/ui.dart';
import '../report_providers.dart';
import '../widgets/documento_do_mes.dart';
import '../widgets/livro_do_mes.dart';
import '../widgets/sinais_do_mes.dart';
import '../widgets/visao_charts.dart';

/// A leitura do mês — a tela que Relatórios abre.
///
/// A página é um documento: a frase que abre, os números que a sustentam, o
/// que saiu da curva e, por último, os gráficos como evidência. A ordem é a de
/// quem vai decidir alguma coisa. O menu de nove relatórios pedia o contrário —
/// que o dono soubesse o que procurar antes de ver qualquer coisa.
class VisaoTab extends ConsumerWidget {
  const VisaoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visaoAsync = ref.watch(visaoMensalProvider);
    final resumoAsync = ref.watch(resumoMensalProvider);

    return visaoAsync.when(
      loading: () => const _Preparando(),
      error: (e, _) => _Erro(
        mensagem: e is AppException ? e.message : 'Não foi possível carregar.',
        onRetry: () => ref.invalidate(visaoMensalProvider),
      ),
      data: (visao) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          resumoAsync.when(
            loading: () => const _DocumentoCarregando(),
            // Falha ao buscar o texto não pode esconder os números: eles não
            // dependem de nada externo.
            error: (_, _) => const SizedBox.shrink(),
            data: (pagina) {
              final resumo = pagina.resumo;
              return resumo == null
                  ? DocumentoAindaNaoEscrito(
                      rotuloDoMes: visao.periodo.rotulo,
                      mesCorrente: ref.watch(mesSelecionadoProvider) == null,
                    )
                  : DocumentoDoMes(resumo: resumo);
            },
          ),
          const SizedBox(height: 16),
          LivroDoMes(kpis: visao.kpis, serie: visao.graficos.serieDiaria),
          if (visao.sinais.isNotEmpty) ...[
            const SizedBox(height: 16),
            SinaisDoMes(sinais: visao.sinais),
          ],
          const SizedBox(height: 16),
          FaturamentoDoMesChart(serie: visao.graficos.serieDiaria),
          const SizedBox(height: 16),
          ParaOndeFoiChart(fatias: visao.graficos.despesasPorCategoria),
        ],
      ),
    );
  }
}

/// A espera, com o texto certo.
///
/// "Carregando" não diz nada; aqui o sistema está somando o mês inteiro em
/// cinco módulos, e dizer isso faz a espera parecer trabalho — que é o que é.
class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: neu.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Fechando as contas do mês',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentoCarregando extends StatelessWidget {
  const _DocumentoCarregando();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // Esqueleto com a forma do que vem: duas linhas de manchete e três de
    // prosa. Um spinner no lugar de um texto não prepara o olho para nada.
    Widget barra(double largura, double altura) => Container(
          width: largura,
          height: altura,
          decoration: BoxDecoration(
            color: neu.line,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          barra(96, 11),
          const SizedBox(height: 16),
          barra(420, 21),
          const SizedBox(height: 10),
          barra(300, 21),
          const SizedBox(height: 22),
          barra(double.infinity, 1),
          const SizedBox(height: 18),
          barra(540, 11),
          const SizedBox(height: 9),
          barra(560, 11),
          const SizedBox(height: 9),
          barra(380, 11),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onRetry});

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: neu.danger, size: 26),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
