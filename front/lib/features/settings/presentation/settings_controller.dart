import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/branding.dart';
import '../../../di.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

/// Controller da tela de configurações.
///
/// Usa [AsyncNotifier] para expor [AsyncValue<SettingsBundle>], espelhando o
/// padrão de [NotificationsNotifier]. O estado carrega automaticamente via
/// [build]; [load] pode ser chamado manualmente para re-buscar.
///
/// Quando [saveCompany] recebe `themePreset` ou `primaryColor`, invalida
/// [brandingSeedProvider] para que o tema re-renderize imediatamente.
class SettingsController extends AsyncNotifier<SettingsBundle> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<SettingsBundle> build() async {
    return _repo.fetch();
  }

  /// Re-busca o bundle completo do servidor.
  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetch());
  }

  /// Aplica [patch] à empresa e atualiza o bundle em memória.
  ///
  /// Se o patch contiver `themePreset` ou `primaryColor`, invalida
  /// [brandingSeedProvider] para re-renderizar o tema.
  Future<void> saveCompany(Map<String, dynamic> patch) async {
    final updatedCompany = await _repo.updateCompany(patch);
    state = state.whenData(
      (bundle) => bundle.copyWith(company: updatedCompany),
    );
    if (patch.containsKey('themePreset') || patch.containsKey('primaryColor')) {
      ref.invalidate(brandingSeedProvider);
    }
  }

  /// Faz upload de logo e atualiza o bundle em memória.
  Future<void> uploadLogo(
    Uint8List bytes,
    String filename,
    String contentType,
  ) async {
    final updatedCompany =
        await _repo.uploadLogo(bytes, filename, contentType);
    state = state.whenData(
      (bundle) => bundle.copyWith(company: updatedCompany),
    );
  }

  /// Remove o logo da empresa e atualiza o bundle em memória.
  Future<void> removeLogo() async {
    final updatedCompany = await _repo.removeLogo();
    state = state.whenData(
      (bundle) => bundle.copyWith(company: updatedCompany),
    );
  }
}

