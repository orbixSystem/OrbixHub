import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/vertical/vertical_providers.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Chip de status REAL da OS com troca embutida — usado no cabeçalho do detalhe
/// **e** em cada card da lista, para trocar o status sem abrir a OS.
///
/// Vive fora de `detail/` porque a lista também precisa dele: enquanto era um
/// `_StatusSelect` privado do header, mudar o status exigia entrar na OS, e a
/// lista só sabia mostrar o status SIMPLIFICADO (três grupos) — de onde vinha a
/// impressão de que "tudo fica em andamento".
class OsStatusSelect extends ConsumerStatefulWidget {
  const OsStatusSelect({
    super.key,
    required this.order,
    this.dense = false,
    this.enabled = true,
  });

  final ServiceOrder order;

  /// Versão compacta, para caber no card da lista.
  final bool dense;

  /// `false` deixa só o chip (sem menu) — ex.: sem `os.write`.
  final bool enabled;

  @override
  ConsumerState<OsStatusSelect> createState() => _OsStatusSelectState();
}

class _OsStatusSelectState extends ConsumerState<OsStatusSelect> {
  bool _busy = false;

  Future<void> _changeStatus(String newStatus) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(osRepositoryProvider)
          .changeStatus(widget.order.id, newStatus);
      if (!mounted) return;
      ref.invalidate(orderProvider(widget.order.id));
      ref.invalidate(orderListProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.status;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = osStatusColor(status);
    final ink = osStatusInk(status, Theme.of(context).brightness);
    final vertical = ref.watch(verticalProvider);

    final targets = osTargetsFor(
      status,
      vertical: vertical,
      canApprove: ref.watch(_canApproveProvider),
    );
    final canChange = widget.enabled && targets.isNotEmpty && !_busy;

    final fonte = widget.dense ? 11.0 : 12.0;
    final icone = widget.dense ? 12.0 : 13.0;
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.dense ? 8 : 10,
        vertical: widget.dense ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            SizedBox(
              width: icone,
              height: icone,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            )
          else
            Icon(osStatusIcon(status), size: icone, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              osStatusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: fonte,
              ),
            ),
          ),
          if (canChange) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: icone + 3, color: ink),
          ],
        ],
      ),
    );

    if (!canChange) return chip;

    final neu = context.neu;
    return PopupMenuButton<String>(
      tooltip: 'Alterar status',
      color: neu.surface,
      position: PopupMenuPosition.under,
      onSelected: _changeStatus,
      itemBuilder: (_) => [
        // Status atual (desabilitado, para contexto).
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(osStatusIcon(status), size: 16, color: osStatusColor(status)),
              const SizedBox(width: 10),
              Text(
                osStatusLabel(status),
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.check_rounded, size: 16, color: neu.inkMuted),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final target in targets)
          PopupMenuItem(
            value: target,
            child: Row(
              children: [
                Icon(
                  osStatusIcon(target),
                  size: 16,
                  color: osStatusColor(target),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    osStatusLabel(target),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: target == 'cancelada' ? neu.danger : neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: chip,
    );
  }
}

final _canApproveProvider = Provider.autoDispose<bool>((ref) {
  final me = ref.watch(sessionControllerProvider).meOrNull;
  return me?.hasPermission('os.approve') ?? false;
});
