import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../../features/auth/presentation/session_state.dart';
import '../../ui/ui.dart';
import '../db/local_db.dart';

/// Painel "Alterações pendentes" (B9 / I4) — a casa das mutações que ainda não
/// chegaram ao servidor.
///
/// Duas famílias, visualmente distintas:
/// - **pendentes** (`pending`): vão subir sozinhas na próxima rodada de sync;
/// - **falhas** (`failed`): o servidor RECUSOU (motivo em PT-BR vindo dele) e o
///   engine NUNCA as retenta sozinho. Aqui o usuário tem as duas únicas saídas:
///   **Tentar de novo** (volta a `pending`) ou **Descartar** (some da fila — e,
///   se era um create, a linha local fantasma some junto).
///
/// Abre no toque do indicador de conexão (`ConnectionChip`).

/// Mutações do usuário atual ainda vivas no outbox (pending + failed).
/// Reavalia quando os contadores do indicador mudam (o SyncEngine os publica a
/// cada rodada/enfileiramento).
final outboxEntriesProvider = FutureProvider<List<OutboxData>>((ref) async {
  ref.watch(connectivityControllerProvider.select((s) => s.pendingCount));
  ref.watch(connectivityControllerProvider.select((s) => s.failedCount));
  final db = ref.watch(localDbProvider);
  final userId = ref.watch(sessionControllerProvider).meOrNull?.user.id;
  if (db == null || userId == null) return const [];
  return db.outboxFor(userId);
});

/// Rótulo humano (PT-BR) de uma mutação do outbox — o usuário nunca vê
/// `service_order.addItem`.
String describeMutation(String entity, String op) {
  const entities = <String, String>{
    'customer': 'Cliente',
    'subject': 'Objeto',
    'inventory_item': 'Item de estoque',
    'service_order': 'Ordem de serviço',
    'cash_session': 'Caixa',
    'cash_entry': 'Lançamento do caixa',
    'cash_expense_template': 'Despesa fixa',
    'expense': 'Despesa',
    'expense_category': 'Categoria de despesa',
    'expense_recurrence': 'Despesa recorrente',
  };
  const ops = <String, String>{
    'create': 'criação',
    'update': 'edição',
    'archive': 'arquivamento',
    'unarchive': 'reativação',
    'delete': 'exclusão',
    'changeStatus': 'mudança de status',
    'addItem': 'item adicionado',
    'updateItem': 'item editado',
    'deleteItem': 'item removido',
    'createNote': 'nota na timeline',
    'applyTemplate': 'checklist aplicado',
    'open': 'abertura',
    'close': 'fechamento',
    'reverse': 'estorno',
  };
  final e = entities[entity] ?? entity;
  final o = ops[op] ?? op;
  return '$e — $o';
}

/// Abre o painel (diálogo) de alterações pendentes/falhas.
Future<void> showPendingChangesPanel(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PendingChangesDialog(),
  );
}

class _PendingChangesDialog extends ConsumerWidget {
  const _PendingChangesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final entries = ref.watch(outboxEntriesProvider);
    return NeuDialog(
      title: 'Alterações pendentes',
      child: entries.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Text(
          'Não foi possível ler a fila local.',
          style: TextStyle(color: neu.danger),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const NeuEmptyState(
              icon: Icons.cloud_done_rounded,
              title: 'Tudo sincronizado',
              message: 'Nenhuma alteração aguardando envio.',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in rows) _OutboxTile(row: row),
            ],
          );
        },
      ),
    );
  }
}

class _OutboxTile extends ConsumerWidget {
  const _OutboxTile({required this.row});

  final OutboxData row;

  Future<void> _act(WidgetRef ref, Future<void> Function(LocalDb db) op) async {
    final db = ref.read(localDbProvider);
    if (db == null) return;
    await op(db);
    ref.invalidate(outboxEntriesProvider);
    // Re-publica os contadores e tenta esvaziar a fila imediatamente.
    await ref.read(syncEngineProvider)?.nudge();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final failed = row.status == 'failed';
    final color = failed ? neu.danger : neu.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuSurface(
        elevation: NeuElevation.flat,
        radius: NeuTokens.rField,
        color: (failed ? neu.dangerTint : neu.warningTint).withValues(
          alpha: 0.5,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  failed
                      ? Icons.error_outline_rounded
                      : Icons.schedule_send_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    describeMutation(row.entity, row.op),
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  failed ? 'Falhou ao enviar' : 'Pendente de envio',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            // A mensagem do SERVIDOR (PT-BR) — antes ficava só no banco local.
            if (failed && (row.message?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                row.message!,
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
            if (failed) ...[
              const SizedBox(height: 10),
              // Wrap (não Row): em telas estreitas os dois botões quebram em
              // duas linhas em vez de estourar o cartão.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  NeuButton(
                    label: 'Descartar',
                    icon: Icons.delete_outline_rounded,
                    kind: NeuButtonKind.danger,
                    onPressed: () => _act(
                      ref,
                      (db) => db.discardOutbox(row.clientMutationId),
                    ),
                  ),
                  NeuButton(
                    label: 'Tentar de novo',
                    icon: Icons.refresh_rounded,
                    kind: NeuButtonKind.secondary,
                    onPressed: () => _act(
                      ref,
                      (db) => db.retryOutbox(row.clientMutationId),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
