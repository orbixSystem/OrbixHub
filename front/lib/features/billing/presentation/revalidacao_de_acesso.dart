import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';

/// Relê o `/me` quando o servidor recusa uma ação, para o bloqueio chegar a
/// quem já está com o app aberto.
///
/// O `/me` é lido uma vez, no login. Sem isto, bloquear um ambiente às 10h só
/// apareceria na tela no dia seguinte: quem estava trabalhando seguiria vendo o
/// sistema liberado e tomaria 403 a cada gravação — descobrir o bloqueio ao
/// perder uma OS preenchida é o pior jeito possível de descobrir.
///
/// O gatilho é o próprio 403 do servidor — o sinal de que a régua mudou —, com
/// trava de tempo: uma tela que dispara seis requisições bloqueadas de uma vez
/// não vira seis releituras.
class RevalidacaoDeAcesso extends Notifier<DateTime?> {
  /// Só para agrupar a rajada de 403 de uma mesma tela; o bloqueio precisa
  /// aparecer na ação seguinte, não minutos depois.
  static const intervalo = Duration(seconds: 20);

  @override
  DateTime? build() => null;

  void talvezRevalidar() {
    final agora = DateTime.now();
    final ultima = state;
    if (ultima != null && agora.difference(ultima) < intervalo) return;
    state = agora;

    scheduleMicrotask(() async {
      try {
        await ref.read(sessionControllerProvider.notifier).reloadMe();
      } on Object {
        // Sem rede o app tem caminho próprio (offline). Falhar aqui não pode
        // derrubar ninguém de uma sessão válida.
      }
    });
  }
}

final revalidacaoDeAcessoProvider =
    NotifierProvider<RevalidacaoDeAcesso, DateTime?>(RevalidacaoDeAcesso.new);
