import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../cashier/domain/cashier_format.dart';
import '../../../cashier/domain/cashier_models.dart';
import '../../../cashier/presentation/cashier_providers.dart';
import '../../domain/receivables_models.dart';
import '../receivables_providers.dart';
import '../receive_title_dialog.dart';

/// Entregues e nunca acertados no caixa.
///
/// Não são fiado — ninguém decidiu fiar — mas também não podem sumir: desde que
/// o fiado passou a ser DECLARADO, um título que nunca passou pelo caixa não
/// entra na carteira, e sem este aviso viraria dinheiro esquecido.
class AvisoPendenteAcerto extends ConsumerWidget {
  const AvisoPendenteAcerto({super.key, required this.pendentes});

  final PendingSettlement pendentes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final n = pendentes.count;
    final umSo = n == 1;
    return InkWell(
      // Sem isto o aviso e um beco sem saida: diz que existem titulos
      // esquecidos e nao deixa descobrir QUAIS.
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _PendentesDialog(),
      ),
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: neu.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              umSo
                  ? '1 título finalizado (${formatMoney(pendentes.total)}) '
                      'ainda não passou pelo caixa. Receba ou marque como '
                      'fiado para ele entrar na carteira.'
                  : '$n títulos finalizados (${formatMoney(pendentes.total)}) '
                      'ainda não passaram pelo caixa. Receba ou marque como '
                      'fiado para eles entrarem na carteira.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: neu.inkMuted),
        ],
      ),
      ),
    );
  }
}

/// QUAIS sao os titulos finalizados que nunca passaram pelo caixa. Tocar um
/// abre o mesmo dialogo de receber -- que e onde se resolve, recebendo ou
/// declarando fiado.
class _PendentesDialog extends ConsumerWidget {
  const _PendentesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(pendingSettlementProvider);
    return NeuDialog(
      title: 'Finalizados sem acerto',
      maxWidth: 520,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Fechar',
            kind: NeuButtonKind.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
      ],
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Nao foi possivel carregar: $e'),
        data: (page) {
          if (page.items.isEmpty) {
            return const NeuEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nada pendente',
              message: 'Todos os titulos finalizados ja passaram pelo caixa.',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Toque para receber ou marcar como fiado.',
                style: TextStyle(color: neu.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final t in page.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PendenteTile(titulo: t),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Uma linha do drill-down: qual titulo, de quem, quanto e desde quando.
class _PendenteTile extends ConsumerWidget {
  const _PendenteTile({required this.titulo});

  final ReceivableTitle titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final rotulo =
        titulo.origin == 'os' ? titulo.number : 'Venda ${titulo.number}';
    final dias = _diasDesde(titulo.createdAt);
    return InkWell(
      onTap: () => _resolver(context, ref),
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              titulo.origin == 'os'
                  ? Icons.build_outlined
                  : Icons.shopping_bag_outlined,
              size: 18,
              color: neu.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // O CLIENTE e o titulo — cobrar fiado comeca por "quem
                  // deve". `customerName` e opcional no titulo achatado: venda
                  // de balcao sem cliente vem nula.
                  Text(
                    (titulo.customerName ?? '').trim().isEmpty
                        ? 'Sem cliente'
                        : titulo.customerName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (titulo.customerName ?? '').trim().isEmpty
                          ? neu.inkMuted
                          : neu.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [rotulo, ?dias].join(' · '),
                    style: TextStyle(color: neu.inkMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMoney(titulo.balance),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Icon(Icons.chevron_right, size: 18, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _resolver(BuildContext context, WidgetRef ref) async {
    final CashierConfig config;
    try {
      config = (await ref.read(cashierControllerProvider.future)).config;
    } on Object catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, 'Nao foi possivel abrir o caixa: $e');
      }
      return;
    }
    if (!context.mounted) return;
    await showReceiveTitleDialog(
      context,
      ref,
      config: config,
      title: titulo,
    );
    // Resolvido um, a lista e a carteira mudam.
    ref.invalidate(pendingSettlementProvider);
    ref.invalidate(debtorsProvider);
  }
}

/// "há N dias" a partir do título mais antigo. Sem vencimento no modelo, esta é
/// a única noção de tempo honesta — não é atraso, é idade da dívida.
///
/// Duplicada de `debtor_tile.dart`: é privada por design (cada widget decide
/// sozinho como formatar "desde quando"), e os dois arquivos nasceram do mesmo
/// corte de `receivables_tab.dart` sem uma home comum óbvia para o helper.
String? _diasDesde(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final dias = DateTime.now().difference(d).inDays;
  if (dias <= 0) return 'de hoje';
  if (dias == 1) return 'há 1 dia';
  return 'há $dias dias';
}
