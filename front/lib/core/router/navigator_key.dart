import 'package:flutter/widgets.dart';

/// The app's root navigator key. Lets global overlay controls (rendered above
/// the Navigator via MaterialApp.builder) open modals/sheets through the
/// Navigator's own overlay context.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Observa as rotas MODAIS (diálogos / bottom sheets — qualquer [PopupRoute])
/// no root navigator e expõe quantas estão abertas. Os controles globais (sino
/// + toggle de tema) são um [OverlayEntry] no topo do overlay do root navigator,
/// então por construção ficam ACIMA da barreira de um modal. Eles se escondem
/// enquanto houver modal aberto, lendo este sinal.
class ModalRouteObserver extends NavigatorObserver {
  final ValueNotifier<int> depth = ValueNotifier<int>(0);

  bool get isModalOpen => depth.value > 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) depth.value++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && depth.value > 0) depth.value--;
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && depth.value > 0) depth.value--;
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute && depth.value > 0) depth.value--;
    if (newRoute is PopupRoute) depth.value++;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// Instância única observando o root navigator (ligada em [GoRouter.observers]).
final modalRouteObserver = ModalRouteObserver();
