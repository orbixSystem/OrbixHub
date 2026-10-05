import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/ui.dart';
import '../report_providers.dart';
import '../widgets/livro_do_mes.dart';
import '../widgets/sinais_do_mes.dart';
import '../widgets/visao_painel.dart';

/// A visão geral — o mesmo mês da aba anterior, em gráficos.
///
/// O texto escrito mora no "Relatório do mês"; aqui ficam os números que o
/// sustentam: o livro de valores, o que saiu da curva e um gráfico de cada
/// assunto, com o caminho para a página que trata dele por inteiro. As duas
/// páginas respondem a mesma pergunta em linguagens diferentes — repetir o
/// documento nas duas faria o dono reler a mesma manchete e procurar, sem
/// achar, o que mudou da primeira para a segunda.
class VisaoTab extends ConsumerWidget {
  const VisaoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visaoAsync = ref.watch(visaoMensalProvider);

    return visaoAsync.when(
      loading: () => const _Preparando(),
      error: (e, _) => _Erro(
        mensagem: e is AppException ? e.message : 'Não foi possível carregar.',
        onRetry: () => ref.invalidate(visaoMensalProvider),
      ),
      data: (visao) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LivroDoMes(kpis: visao.kpis, serie: visao.graficos.serieDiaria),
          if (visao.sinais.isNotEmpty) ...[
            const SizedBox(height: 16),
            SinaisDoMes(sinais: visao.sinais),
          ],
          const SizedBox(height: 16),
          PainelDaVisao(graficos: visao.graficos),
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
