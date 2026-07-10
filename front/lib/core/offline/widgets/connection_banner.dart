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

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged(ConnStatus? previous, ConnStatus next) {
    final wasDisconnected =
        previous == ConnStatus.offline || previous == ConnStatus.syncing;
    if (wasDisconnected && next == ConnStatus.online) {
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
    final spec = _specFor(state.status, context.neu);

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

  _BannerSpec? _specFor(ConnStatus status, NeuTokens neu) {
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
          color: neu.inkMuted,
          tint: neu.surfaceHi,
          icon: Icons.cloud_off_rounded,
        );
      case ConnStatus.syncing:
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: spec.tint,
      child: Row(
        children: [
          Icon(spec.icon, size: 16, color: spec.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              spec.message,
              style: TextStyle(
                color: spec.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
