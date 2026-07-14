import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../ui/ui.dart';
import '../connectivity_controller.dart';

/// Camada de UX offline (B9) — os avisos que o USUÁRIO vê.
///
/// Três peças reutilizáveis:
/// - [OfflinePendingNotice]: aviso VERMELHO inline ("será enviado quando a
///   conexão voltar") nas seções cujo conteúdo é gravado localmente e só sobe
///   no replay do outbox;
/// - [RequiresConnection]: envelopa uma AÇÃO que não funciona offline
///   (desabilita + tooltip "Requer conexão");
/// - [RequiresConnectionView]: estado vazio de uma TELA que não funciona
///   offline (nunca uma tela em branco/quebrada);
/// - [PendingSyncBadge]: selo "pendente de envio" em registros criados offline.
///
/// Regra: tudo aqui só aparece com `ConnStatus.offline` — `syncing` conta como
/// online (mesma régua do `LocalFirst` em `di.dart`).

/// `true` quando o app está offline de verdade (status `offline`).
/// Derivado do [connectivityControllerProvider] com `select` — rebuilda a UI
/// só quando o STATUS muda (não a cada mudança de contador de pendências).
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(
    connectivityControllerProvider.select(
      (s) => s.status == ConnStatus.offline,
    ),
  );
});

/// Texto padrão do tooltip/mensagem de ação indisponível offline.
const kRequiresConnectionTooltip = 'Requer conexão';

/// Ids de uma entidade com mutação local ainda não confirmada pelo servidor
/// (outbox `pending`/`failed` — ver `LocalDb.unsyncedIds`, B8). Vazio na web,
/// sem sessão ou em teste (sem `LocalDb`) — nenhum selo aparece.
///
/// Reavalia quando o contador de pendências muda (o SyncEngine o atualiza a
/// cada enfileiramento/replay).
final pendingIdsProvider = FutureProvider.family<Set<String>, String>((
  ref,
  entity,
) async {
  ref.watch(connectivityControllerProvider.select((s) => s.pendingCount));
  final db = ref.watch(localDbProvider);
  if (db == null) return const <String>{};
  return db.unsyncedIds(entity);
});

/// Aviso VERMELHO inline: o que está sendo escrito fica no aparelho e só chega
/// ao sistema quando a conexão voltar. Some quando online.
///
/// Discreto (12.5px, ícone pequeno) mas inconfundível: usa o vermelho de erro
/// do tema (`colorScheme.error`). [dense] reduz o espaçamento superior.
class OfflinePendingNotice extends ConsumerWidget {
  const OfflinePendingNotice({
    super.key,
    this.message = 'Será enviado ao sistema quando a conexão voltar',
    this.dense = false,
  });

  final String message;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) return const SizedBox.shrink();
    return OfflinePendingNoticeBody(message: message, dense: dense);
  }
}

/// Corpo do aviso sem a dependência do provider — usado por [OfflinePendingNotice]
/// e quando o chamador já sabe que a linha está pendente.
class OfflinePendingNoticeBody extends StatelessWidget {
  const OfflinePendingNoticeBody({
    super.key,
    required this.message,
    this.dense = false,
  });

  final String message;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.only(top: dense ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: error),
          const SizedBox(width: 6),
          // Flexible: em telas estreitas o texto quebra em vez de estourar.
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: error,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso PERMANENTE de topo de tela (Caixa): faixa vermelha suave, largura
/// total, some quando online.
class OfflineScreenNotice extends ConsumerWidget {
  const OfflineScreenNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) return const SizedBox.shrink();
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuSurface(
        elevation: NeuElevation.flat,
        radius: NeuTokens.rField,
        color: error.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          // Em telas estreitas a mensagem quebra em 2–3 linhas: o ícone fica
          // ancorado na PRIMEIRA linha (centralizado ele flutuava no meio do
          // parágrafo).
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.cloud_off_rounded, size: 18, color: error),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Envelopa uma AÇÃO que exige servidor (enviar link, emitir NF, apagar…):
/// offline vira inerte (sem toque), esmaecida e com tooltip "Requer conexão".
/// Não altera a árvore quando online (zero custo visual).
class RequiresConnection extends ConsumerWidget {
  const RequiresConnection({super.key, required this.child, this.reason});

  final Widget child;

  /// Explicação extra no tooltip (ex.: "o link é enviado pelo servidor").
  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) return child;
    final message = reason == null
        ? kRequiresConnectionTooltip
        : '$kRequiresConnectionTooltip — $reason';
    return Tooltip(
      message: message,
      // No mobile o tooltip só aparece no toque LONGO: sem isto o usuário toca
      // o botão esmaecido e "não acontece nada". O GestureDetector (fora do
      // IgnorePointer) captura o toque e explica com um snackbar.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(message)));
        },
        child: Opacity(opacity: 0.55, child: IgnorePointer(child: child)),
      ),
    );
  }
}

/// Estado vazio de uma TELA que não funciona offline. Base [NeuEmptyState] —
/// mesmo visual dos demais estados vazios do app.
class RequiresConnectionView extends StatelessWidget {
  const RequiresConnectionView({
    super.key,
    required this.message,
    this.title = 'Requer conexão',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuEmptyState(
              icon: Icons.cloud_off_rounded,
              title: title,
              message: message,
            ),
            if (onRetry != null)
              NeuButton(
                label: 'Tentar de novo',
                icon: Icons.refresh_rounded,
                kind: NeuButtonKind.secondary,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// Registro criado offline (ainda não existe no servidor): selo "pendente de
/// envio". Sempre visível (mesmo depois que a conexão volta, até o replay
/// substituir a linha) — é o estado da LINHA, não da rede.
class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: neu.warningTint,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_send_outlined,
            size: dense ? 12 : 14,
            color: neu.warning,
          ),
          const SizedBox(width: 5),
          Text(
            'Pendente de envio',
            style: TextStyle(
              color: neu.warning,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Número provisório de OS criada offline (`OS-P1`, `OS-P2`…) — o servidor
/// atribui o definitivo no replay (ver task B8).
bool isPendingOsNumber(String? number) =>
    number != null && number.startsWith('OS-P');
