import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../domain/monthly_models.dart';

/// O mês em uma página: o texto que abre Relatórios.
///
/// Três blocos, sempre na mesma ordem — o que aconteceu, o que merece atenção,
/// o que fazer. A ordem é a do raciocínio de quem vai decidir alguma coisa; uma
/// lista de gráficos exige que o dono monte esse raciocínio sozinho, que é
/// exatamente o trabalho que ele não tem tempo de fazer.
///
/// O selo diz quem escreveu. Quando o texto foi montado pelo sistema (sem IA),
/// ele avisa — creditar à IA um texto que ela não escreveu é mentir sobre o
/// produto, e um dia alguém compara dois meses e percebe.
class ResumoMesCard extends StatelessWidget {
  const ResumoMesCard({super.key, required this.resumo});

  final ResumoMensal resumo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final n = resumo.narrativa;

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: neu.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O mês em uma página',
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _SeloDeOrigem(resumo: resumo),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            n.titulo,
            style: TextStyle(
              color: neu.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            n.leitura,
            style: TextStyle(color: neu.inkMuted, fontSize: 14.5, height: 1.55),
          ),
          if (n.alertas.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Bloco(
              titulo: 'O que merece atenção',
              icone: Icons.warning_amber_rounded,
              cor: neu.warning,
              itens: n.alertas,
            ),
          ],
          if (n.recomendacoes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Bloco(
              titulo: 'Para este mês',
              icone: Icons.flag_outlined,
              cor: neu.navy,
              itens: n.recomendacoes,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Escrito por IA" ou "Resumo automático" — e quando foi gerado.
class _SeloDeOrigem extends StatelessWidget {
  const _SeloDeOrigem({required this.resumo});

  final ResumoMensal resumo;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ia = resumo.escritoPorIa;
    return Tooltip(
      message: ia
          ? 'Texto escrito por IA sobre os números apurados pelo sistema. '
              'Nenhum número vem do modelo.'
          : 'Texto montado pelo próprio sistema a partir dos números do mês.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: neu.inkFaint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          ia ? 'Escrito por IA' : 'Resumo automático',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Bloco extends StatelessWidget {
  const _Bloco({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.itens,
  });

  final String titulo;
  final IconData icone;
  final Color cor;
  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, size: 15, color: cor),
            const SizedBox(width: 7),
            Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 9),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// O que aparece no lugar do resumo quando o mês ainda não fechou.
///
/// Não é um erro nem um vazio: é o estado normal do mês corrente. Dizer isso
/// explicitamente evita a leitura óbvia e errada — "a IA não funcionou".
class ResumoAindaNaoGerado extends StatelessWidget {
  const ResumoAindaNaoGerado({super.key, required this.rotuloDoMes});

  final String rotuloDoMes;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 20, color: neu.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O resumo de $rotuloDoMes chega quando o mês fechar',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Todo dia 1º o sistema escreve a leitura do mês anterior e '
                  'avisa você. Os números abaixo já são de agora.',
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
      ),
    );
  }
}
