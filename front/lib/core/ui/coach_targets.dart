import 'package:flutter/widgets.dart';

/// Registro de ALVOS de tutorial, por nome.
///
/// O conteúdo dos tutoriais é central (`screen_tutorials.dart`), mas as
/// `GlobalKey` só podem nascer nas telas. Amarrar o conteúdo à chave exigiria
/// importar a tela no registro (ou espalhar o texto pelas telas) — as duas coisas
/// ruins. Então a tela registra "este widget é o alvo `caixa.abas`" e o passo do
/// tutorial pede o alvo por NOME.
///
/// Alvo ausente não é erro: o passo simplesmente vira um cartão centralizado.
/// É o que mantém o tutorial completo no celular, onde vários elementos do
/// desktop não existem.
abstract final class CoachTargets {
  static final Map<String, GlobalKey> _keys = {};

  /// Chave estável para [name] — a MESMA em rebuilds, senão o holofote perderia
  /// o alvo a cada frame.
  static GlobalKey key(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey(debugLabel: 'coach:$name'));

  /// Chave já registrada e MONTADA, ou `null`.
  static GlobalKey? live(String name) {
    final k = _keys[name];
    if (k == null) return null;
    final box = k.currentContext?.findRenderObject();
    return (box is RenderBox && box.hasSize) ? k : null;
  }
}

/// Marca um widget como alvo de tutorial. Uso: `CoachTarget('caixa.abas', child: ...)`.
class CoachTarget extends StatelessWidget {
  const CoachTarget(this.name, {super.key, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: CoachTargets.key(name), child: child);
}
