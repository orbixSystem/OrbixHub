import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../domain/receivables_query.dart';
import 'receivables_providers.dart';

/// Busca + chips de vencimento + origem + ordenação. Chips, não menus: a
/// escolha fica VISÍVEL sem abrir nada — critério da tela é ser fácil.
class ReceivablesFiltersBar extends ConsumerStatefulWidget {
  const ReceivablesFiltersBar({super.key});
  @override
  ConsumerState<ReceivablesFiltersBar> createState() =>
      _ReceivablesFiltersBarState();
}

class _ReceivablesFiltersBarState
    extends ConsumerState<ReceivablesFiltersBar> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(debtorsQueryProvider);
    final n = ref.read(debtorsQueryProvider.notifier);
    final isMobile = context.isMobile;

    final vencimento = NeuSegmented<VencimentoFiltro>(
      segments: {for (final v in VencimentoFiltro.values) v: v.rotulo},
      selected: q.vencimento,
      onChanged: n.setVencimento,
    );
    final origem = NeuSegmented<OrigemFiltro>(
      segments: {for (final o in OrigemFiltro.values) o: o.rotulo},
      selected: q.origem,
      onChanged: n.setOrigem,
    );
    final ordem = PopupMenuButton<OrdemDevedores>(
      tooltip: 'Ordenar',
      initialValue: q.sort,
      onSelected: n.setSort,
      itemBuilder: (_) => [
        for (final o in OrdemDevedores.values)
          PopupMenuItem(value: o, child: Text(o.rotulo)),
      ],
      child: NeuStatusChip(
        label: q.sort.rotulo,
        color: context.neu.inkMuted,
        tint: context.neu.inkMuted.withValues(alpha: .14),
        icon: Icons.swap_vert_rounded,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isMobile ? double.infinity : 380),
              child: NeuSearchBar(
                hint: 'Buscar devedor',
                controller: _busca,
                onChanged: n.setQuery,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ordem,
        ]),
        const SizedBox(height: 10),
        // Wrap: no celular os dois segmentados empilham; no desktop ficam lado
        // a lado.
        Wrap(spacing: 12, runSpacing: 10, children: [vencimento, origem]),
      ],
    );
  }
}
