import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../report/presentation/report_providers.dart';
import '../../report/domain/report_models.dart';

/// Ciclo de vida do cliente — o que ele já deixou, em dinheiro e em visitas.
///
/// Sem período: a pergunta é "quanto este cliente vale desde sempre". O número
/// é o RECEBIDO, não o faturado — quem está devendo não deve aparecer como
/// cliente grande.
final customerLifetimeProvider = FutureProvider.autoDispose
    .family<ClienteRanqueado, String>((ref, id) {
      return ref.read(reportRepositoryProvider).customerLifetime(id);
    });

/// Faixa de KPIs no topo do histórico do cliente.
///
/// Responsiva por medida, não por breakpoint: os cartões vão num [Wrap] e
/// quebram sozinhos. Num telefone estreito viram duas colunas; num desktop,
/// uma linha. Fixar contagem por breakpoint erraria nos tamanhos do meio.
class CustomerKpis extends ConsumerWidget {
  const CustomerKpis({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerLifetimeProvider(customerId));
    return async.when(
      loading: () => const _Esqueleto(),
      // Falha nos KPIs não pode derrubar o histórico: o histórico é a razão de
      // a tela existir, os números são complemento.
      error: (_, _) => const SizedBox.shrink(),
      data: (c) {
        if (c.atendimentos == 0) return const SizedBox.shrink();

        final cards = <_Kpi>[
          _Kpi(
            rotulo: 'Já pagou',
            valor: formatMoney(c.recebido),
            icone: Icons.payments_outlined,
            destaque: true,
          ),
          _Kpi(
            rotulo: 'Atendimentos',
            valor: '${c.atendimentos}',
            detalhe: '${c.osCount} OS · ${c.saleCount} vendas',
            icone: Icons.repeat_rounded,
          ),
          _Kpi(
            rotulo: 'Ticket médio',
            valor: formatMoney(c.ticketMedio),
            icone: Icons.receipt_long_outlined,
          ),
          _Kpi(
            rotulo: 'Cliente desde',
            valor: _mesAno(c.primeiroEm),
            detalhe: 'Último: ${_mesAno(c.ultimoEm)}',
            icone: Icons.event_available_outlined,
          ),
          if (c.desconto > 0)
            _Kpi(
              rotulo: 'Descontos dados',
              valor: formatMoney(c.desconto),
              icone: Icons.local_offer_outlined,
            ),
        ];

        return LayoutBuilder(
          builder: (context, box) {
            // UMA linha sempre que os cards couberem com largura legível. O
            // corte é por largura POR CARD (140), não por breakpoint de tela:
            // com 4 ou 5 KPIs o ponto de quebra muda, e um breakpoint fixo
            // apertaria os 5 num monitor onde os 4 caberiam folgados.
            const minPorCard = 140.0;
            final cabemTodos =
                (box.maxWidth - 10 * (cards.length - 1)) / cards.length >=
                minPorCard;
            final porLinha = cabemTodos
                ? cards.length
                : (box.maxWidth >= 360 ? 2 : 1);

            final linhas = <Widget>[];
            for (var i = 0; i < cards.length; i += porLinha) {
              final fatia = cards.skip(i).take(porLinha).toList();
              linhas.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < fatia.length; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(child: fatia[j]),
                    ],
                    // Preenche a última linha incompleta para os cards não
                    // esticarem: dois cards ocupando a largura de quatro
                    // ficariam maiores que os de cima, e a faixa perderia o
                    // alinhamento que o pedido quer.
                    for (var k = fatia.length; k < porLinha; k++) ...[
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < linhas.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  // IntrinsicHeight iguala a altura DENTRO da linha; a linha de
                  // detalhe reservada (ver [_Kpi]) iguala ENTRE as linhas.
                  IntrinsicHeight(child: linhas[i]),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

String _mesAno(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  const meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${meses[d.month - 1]}/${d.year}';
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.rotulo,
    required this.valor,
    required this.icone,
    this.detalhe,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final IconData icone;
  final String? detalhe;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icone,
                size: 16,
                color: destaque ? neu.success : neu.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: destaque ? neu.success : neu.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          // A linha de detalhe é SEMPRE renderizada, mesmo vazia: sem ela
          // o card sem detalhe fica mais baixo, e com os cards em linhas
          // diferentes o IntrinsicHeight não consegue igualar entre linhas.
          const SizedBox(height: 2),
          Text(
            detalhe ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neu.inkFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 86,
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
