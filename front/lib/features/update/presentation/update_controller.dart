import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/update_models.dart';

/// Plataforma para a qual pedimos atualização. Só desktop Windows e Android
/// instalam pacote — web atualiza sozinha e macOS/iOS não são distribuídos
/// assim; nesses casos nem consultamos o servidor.
String? updatePlatform() {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  return null;
}

/// Versão E build instalados (do pubspec, via metadados do pacote). O build
/// importa: entre duas publicações só ele costuma mudar.
final installedVersionProvider =
    FutureProvider<({String version, int build})>((ref) async {
  if (kIsWeb) return (version: '', build: 0);
  final info = await PackageInfo.fromPlatform();
  return (
    version: info.version,
    build: int.tryParse(info.buildNumber) ?? 0,
  );
});

/// Situação da versão instalada perante o servidor. Silencioso por natureza:
/// qualquer falha (offline, servidor sem release, endpoint desligado) resolve
/// como "em dia" — checar atualização nunca pode atrapalhar quem quer trabalhar.
final updateStatusProvider = FutureProvider<({UpdateStatus status, AppUpdate update})>(
  (ref) async {
    final platform = updatePlatform();
    if (platform == null) {
      return (status: UpdateStatus.emDia, update: const AppUpdate());
    }
    try {
      final installed = await ref.watch(installedVersionProvider.future);
      if (installed.version.isEmpty) {
        return (status: UpdateStatus.emDia, update: const AppUpdate());
      }
      final update =
          await ref.read(updateRepositoryProvider).latest(platform);
      return (
        status: resolveUpdateStatus(
          installedVersion: installed.version,
          installedBuild: installed.build,
          update: update,
        ),
        update: update,
      );
    } on AppException {
      return (status: UpdateStatus.emDia, update: const AppUpdate());
    } on Object {
      return (status: UpdateStatus.emDia, update: const AppUpdate());
    }
  },
);


/// Versão que o usuário mandou deixar para depois ([chaveDaVersao]), PERSISTIDA.
///
/// Antes isso era estado do widget do banner: morria no primeiro rebuild e o
/// aviso voltava a interromper — "Depois" não significava nada. Guardado aqui,
/// a decisão atravessa reinícios do app, e continua valendo só para AQUELA
/// versão (a próxima volta a avisar).
final atualizacaoAdiadaProvider =
    NotifierProvider<AtualizacaoAdiadaNotifier, String?>(
        AtualizacaoAdiadaNotifier.new);

class AtualizacaoAdiadaNotifier extends Notifier<String?> {
  static const _key = 'update_adiada_versao';

  @override
  String? build() {
    _carregar();
    return null;
  }

  Future<void> _carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v != null && v != state) state = v;
    } on Object {
      // Preferências indisponíveis não podem quebrar o app: sem memória do
      // "depois", o pior caso é o banner aparecer de novo.
      return;
    }
  }

  Future<void> adiar(String chave) async {
    state = chave;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, chave);
    } on Object {
      return;
    }
  }
}

/// Onde o aviso de atualização deve aparecer AGORA — a leitura única que o
/// banner, o sino e o bloqueio de tela compartilham. Com três leitores
/// decidindo por conta própria, um deles acabaria discordando dos outros.
final avisoAtualizacaoProvider = Provider<({AvisoAtualizacao onde, AppUpdate update})>(
  (ref) {
    final data = ref.watch(updateStatusProvider).asData?.value;
    if (data == null) {
      return (onde: AvisoAtualizacao.nenhum, update: const AppUpdate());
    }
    return (
      onde: resolveAviso(
        status: data.status,
        update: data.update,
        adiada: ref.watch(atualizacaoAdiadaProvider),
      ),
      update: data.update,
    );
  },
);
