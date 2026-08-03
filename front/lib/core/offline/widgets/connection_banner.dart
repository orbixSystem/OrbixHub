import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../ui/neu_tokens.dart';
import '../connectivity_controller.dart';

/// Faixa fina no topo da área de conteúdo do shell, para as TRANSIÇÕES de
/// conectividade (o estado persistente vive no [ConnectionChip] — este
/// banner nunca duplica o rótulo de status, só avisa da mudança).
///
/// - `offline`: fica visível enquanto durar ("Você está offline — …"; na web
///   o texto muda, pois não há outbox/replay no navegador — ver [isWeb]).
/// - `syncing`: "Sincronizando alterações…".
/// - volta a `online` depois de ter estado offline/syncing: flash verde
///   "Conexão restabelecida — dados sincronizados" por ~3s, depois some.
/// - esteve `online` o tempo todo: nunca aparece nada.
class ConnectionBanner extends ConsumerStatefulWidget {
  const ConnectionBanner({super.key, this.isWeb = kIsWeb});

  /// Injetável para teste (produção usa [kIsWeb]).
  final bool isWeb;

  @override
  ConsumerState<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends ConsumerState<ConnectionBanner> {
  Timer? _flashTimer;
  bool _showFlash = false;

  /// Houve uma queda de verdade desde o último aviso de reconexão?
  ///
  /// Sem isto o banner mentia: o SyncEngine faz `syncing` → `online` a cada
  /// rodada (60s), e tratar `syncing` como "estava desconectado" anunciava
  /// "Conexão restabelecida" de minuto em minuto com a internet intacta. Só
  /// `offline` é queda; `syncing` é o fim normal de uma rodada.
  bool _houveQueda = false;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged(ConnStatus? previous, ConnStatus next) {
    if (next == ConnStatus.offline) _houveQueda = true;
    if (_houveQueda && next == ConnStatus.online) {
      _houveQueda = false;
      _flashTimer?.cancel();
      setState(() => _showFlash = true);
      _flashTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showFlash = false);
      });
      return;
    }
    if (next != ConnStatus.online && _showFlash) {
      // Nova queda chegou enquanto o flash ainda estava visível: não
      // sobrepõe mensagens — o flash cede lugar ao aviso de offline/syncing.
      _flashTimer?.cancel();
      setState(() => _showFlash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnState>(connectivityControllerProvider, (previous, next) {
      _onStatusChanged(previous?.status, next.status);
    });
    final state = ref.watch(connectivityControllerProvider);
    // A flag também é ligada AQUI porque `ref.listen` só reage a MUDANÇAS: se a
    // tela já nasce offline, nenhuma transição é observada e a reconexão
    // seguinte não seria anunciada.
    if (state.status == ConnStatus.offline) _houveQueda = true;
    final spec = _specFor(state, context.neu);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: spec == null
          ? const SizedBox.shrink(key: ValueKey('conn-banner-empty'))
          : _BannerBar(key: ValueKey('conn-banner-${spec.id}'), spec: spec),
    );
  }

  _BannerSpec? _specFor(ConnState state, NeuTokens neu) {
    final status = state.status;
    if (_showFlash) {
      return _BannerSpec(
        id: 'reconnected',
        message: 'Conexão restabelecida — dados sincronizados',
        color: neu.success,
        tint: neu.successTint,
        icon: Icons.check_circle_rounded,
      );
    }
    switch (status) {
      case ConnStatus.offline:
        return _BannerSpec(
          id: 'offline',
          message: widget.isWeb
              ? 'Você está offline — o Orbix precisa de conexão no navegador'
              : 'Você está offline — alterações serão enviadas ao reconectar',
          // Vermelho suave (era cinza, quase invisível): mesmo idioma dos
          // avisos vermelhos das telas, sem virar um alerta cheio.
          color: neu.danger,
          tint: neu.dangerTint,
          icon: Icons.cloud_off_rounded,
        );
      case ConnStatus.syncing:
        // Só avisa quando existe alteração DESTE usuário esperando. O engine
        // marca `syncing` em toda rodada (60s), inclusive nas que só puxam
        // novidades — anunciar isso pintava um banner de minuto em minuto sem
        // nada do usuário pendente. Housekeeping não é notícia.
        if (state.pendingCount == 0 && state.failedCount == 0) return null;
        return _BannerSpec(
          id: 'syncing',
          message: 'Sincronizando alterações…',
          color: neu.warning,
          tint: neu.warningTint,
          icon: Icons.sync_rounded,
        );
      case ConnStatus.online:
        return null;
    }
  }
}

class _BannerSpec {
  const _BannerSpec({
    required this.id,
    required this.message,
    required this.color,
    required this.tint,
    required this.icon,
  });

  final String id;
  final String message;
  final Color color;
  final Color tint;
  final IconData icon;
}

class _BannerBar extends StatelessWidget {
  const _BannerBar({super.key, required this.spec});
  final _BannerSpec spec;

  @override
  Widget build(BuildContext context) {
    // A faixa vive no topo da ÁREA DE CONTEÚDO (abaixo do header). O sino + o
    // toggle de tema (GlobalControls) ficam no topo-direito da TELA, sobre o
    // header — não sobre esta faixa —, então não é preciso reservar largura p/ eles.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      color: spec.tint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(spec.icon, size: 16, color: spec.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              spec.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.color,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
