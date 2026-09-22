import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../domain/report_models.dart';
import 'report_providers.dart';

final customersRankingProvider = FutureProvider.autoDispose
    .family<CustomersRanking, ReportRange>((ref, range) {
  return ref.read(reportRepositoryProvider).customersRanking(range: range);
});

/// "Melhores clientes" em DUAS listas: por dinheiro e por recorrência.
///
/// São duas porque respondem a perguntas diferentes — quem traz mais dinheiro
/// nem sempre é quem volta mais, e a oficina trata os dois de jeitos
/// diferentes. Uma nota combinada esconderia justamente essa diferença.
class CustomersRankingCard extends ConsumerWidget {
  const CustomersRankingCard({super.key, required this.range});

  final ReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customersRankingProvider(range));
    return async.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _Erro(mensagem: '$e'),
      data: (r) {
        if (r.porReceita.isEmpty) {
          return const NeuEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Sem clientes no período',
            message: 'Vendas e OS de clientes cadastrados aparecem aqui, '
                'ordenadas por quanto já pagaram e com que frequência voltam.',
          );
        }
        // Lado a lado quando cabe; empilhado no celular. O corte é por LARGURA
        // real: duas colunas de ranking abaixo de ~760 ficam ilegíveis, com o
        // nome do cliente cortado antes do valor.
        return LayoutBuilder(
          builder: (context, box) {
            final lado = box.maxWidth >= 760;
            final receita = _Lista(
              titulo: 'Quem mais pagou',
              subtitulo: 'Dinheiro recebido no período',
              icone: Icons.workspace_premium_outlined,
              itens: r.porReceita,
              valorDe: (c) => formatMoney(c.recebido),
              detalheDe: (c) => '${c.atendimentos} '
                  '${c.atendimentos == 1 ? "atendimento" : "atendimentos"}',
            );
            final recorrencia = _Lista(
              titulo: 'Quem mais volta',
              subtitulo: 'Nº de atendimentos no período',
              icone: Icons.repeat_rounded,
              itens: r.porRecorrencia,
              valorDe: (c) => '${c.atendimentos}',
              detalheDe: (c) => formatMoney(c.recebido),
            );
            if (!lado) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [receita, const SizedBox(height: 14), recorrencia],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: receita),
                const SizedBox(width: 14),
                Expanded(child: recorrencia),
              ],
            );
          },
        );
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.itens,
    required this.valorDe,
    required this.detalheDe,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final List<ClienteRanqueado> itens;
  final String Function(ClienteRanqueado) valorDe;
  final String Function(ClienteRanqueado) detalheDe;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: neu.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitulo, style: TextStyle(color: neu.inkMuted, fontSize: 14)),
          const SizedBox(height: 12),
          for (var i = 0; i < itens.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Posição em vez de medalha: a lista pode ter 10 linhas, e
                  // ouro/prata/bronze deixaria as sete últimas sem identidade.
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? neu.accent : neu.inkFaint,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      itens[i].customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valorDe(itens[i]),
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        detalheDe(itens[i]),
                        style: TextStyle(color: neu.inkFaint, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem});
  final String mensagem;

  @override
  Widget build(BuildContext context) => NeuCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Não foi possível carregar o ranking de clientes.\n$mensagem',
          style: TextStyle(color: context.neu.inkMuted, fontSize: 14),
        ),
      );
}
