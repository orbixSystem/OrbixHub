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
final customerLifetimeProvider =
    FutureProvider.autoDispose.family<ClienteRanqueado, String>((ref, id) {
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
        return LayoutBuilder(
          builder: (context, box) {
            // Dois por linha no estreito, quatro no largo — calculado a partir
            // da largura real disponível.
            final largura = box.maxWidth < 520
                ? (box.maxWidth - 10) / 2
                : (box.maxWidth - 30) / 4;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Kpi(
                  largura: largura,
                  rotulo: 'Já pagou',
                  valor: formatMoney(c.recebido),
                  icone: Icons.payments_outlined,
                  destaque: true,
                ),
                _Kpi(
                  largura: largura,
                  rotulo: 'Atendimentos',
                  valor: '${c.atendimentos}',
                  detalhe: '${c.osCount} OS · ${c.saleCount} vendas',
                  icone: Icons.repeat_rounded,
                ),
                _Kpi(
                  largura: largura,
                  rotulo: 'Ticket médio',
                  valor: formatMoney(c.ticketMedio),
                  icone: Icons.receipt_long_outlined,
                ),
                _Kpi(
                  largura: largura,
                  rotulo: 'Cliente desde',
                  valor: _mesAno(c.primeiroEm),
                  detalhe: 'Último: ${_mesAno(c.ultimoEm)}',
                  icone: Icons.event_available_outlined,
                ),
                if (c.desconto > 0)
                  _Kpi(
                    largura: largura,
                    rotulo: 'Descontos dados',
                    valor: formatMoney(c.desconto),
                    icone: Icons.local_offer_outlined,
                  ),
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
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${meses[d.month - 1]}/${d.year}';
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.largura,
    required this.rotulo,
    required this.valor,
    required this.icone,
    this.detalhe,
    this.destaque = false,
  });

  final double largura;
  final String rotulo;
  final String valor;
  final IconData icone;
  final String? detalhe;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      width: largura,
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icone,
                    size: 16,
                    color: destaque ? neu.success : neu.inkMuted),
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
            if (detalhe != null) ...[
              const SizedBox(height: 2),
              Text(
                detalhe!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
            ],
          ],
        ),
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
