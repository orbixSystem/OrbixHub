import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// Versão instalada (do pubspec, via metadados do pacote).
final installedVersionProvider = FutureProvider<String>((ref) async {
  if (kIsWeb) return '';
  final info = await PackageInfo.fromPlatform();
  return info.version;
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
      if (installed.isEmpty) {
        return (status: UpdateStatus.emDia, update: const AppUpdate());
      }
      final update =
          await ref.read(updateRepositoryProvider).latest(platform);
      return (
        status: resolveUpdateStatus(
          installedVersion: installed,
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
