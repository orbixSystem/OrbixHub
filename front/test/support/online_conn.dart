import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';

/// Controller de conectividade fixo em ONLINE para testes que NÃO são sobre o
/// modo offline. Dois motivos:
/// - o `ConnState` default é `offline` (fail-safe do B3) e, a partir do B9, as
///   telas reagem a isso (avisos/estado "Requer conexão");
/// - o controller real assina o platform channel do `connectivity_plus`, que
///   não existe no ambiente de teste.
class OnlineConnectivityController extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

/// Override pronto: adicione às `overrides` do `ProviderScope` do teste.
final onlineConnOverride = connectivityControllerProvider.overrideWith(
  OnlineConnectivityController.new,
);
