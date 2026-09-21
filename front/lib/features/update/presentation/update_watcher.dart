import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/update_models.dart';
import 'update_banner.dart';
import 'update_controller.dart';

/// Vigia de atualização: reconsulta o servidor enquanto o app está aberto.
///
/// O gap que isto fecha: `updateStatusProvider` é um future cacheado, avaliado
/// UMA vez. Quem entra no app e fica — o caso normal de um balcão, onde a
/// máquina não é desligada e ninguém faz logout — nunca mais era consultado.
/// Uma versão publicada na terça só aparecia quando alguém reiniciasse o app.
///
/// Dois gatilhos, porque cobrem situações diferentes:
/// - **periódico** ([_intervalo]): o app que fica aberto o dia inteiro;
/// - **voltar ao app** (`resumed`): celular guardado no bolso ou janela
///   minimizada por horas — reabrir é o momento natural de conferir.
///
/// O piso de [_minimoEntreConsultas] existe para o segundo gatilho: alternar
/// entre janelas dispara `resumed` a todo momento, e consultar a cada
/// alternância seria uma consulta por minuto sem nenhuma informação nova.
///
/// Renderiza o banner (quando é o caso) para viver na árvore onde o banner já
/// vivia — um vigia que não desenha nada teria de ser montado à parte, e a
/// próxima pessoa a mexer no shell não saberia que precisa mantê-lo.
class UpdateWatcher extends ConsumerStatefulWidget {
  const UpdateWatcher({super.key});

  /// De quanto em quanto tempo reconsultar com o app aberto. Seis horas cobre
  /// um expediente sem transformar a checagem em tráfego de fundo.
  static const Duration _intervalo = Duration(hours: 6);

  /// Piso entre duas consultas, qualquer que seja o gatilho.
  static const Duration _minimoEntreConsultas = Duration(minutes: 30);

  @override
  ConsumerState<UpdateWatcher> createState() => _UpdateWatcherState();
}

class _UpdateWatcherState extends ConsumerState<UpdateWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _ultimaConsulta = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      UpdateWatcher._intervalo,
      (_) => _reconsultar(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconsultar();
  }

  void _reconsultar() {
    if (!mounted) return;
    final agora = DateTime.now();
    if (agora.difference(_ultimaConsulta) < UpdateWatcher._minimoEntreConsultas) {
      return;
    }
    _ultimaConsulta = agora;
    // Invalidar é o suficiente: o provider é silencioso por natureza (qualquer
    // falha resolve como "em dia"), então uma reconsulta sem rede não vira erro
    // na tela de quem está trabalhando.
    ref.invalidate(updateStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final aviso = ref.watch(avisoAtualizacaoProvider);
    // Só o banner mora aqui. O bloqueio é do shell (substitui a tela inteira) e
    // o sino se serve do mesmo provider.
    if (aviso.onde != AvisoAtualizacao.banner) return const SizedBox.shrink();
    return UpdateBanner(update: aviso.update);
  }
}
