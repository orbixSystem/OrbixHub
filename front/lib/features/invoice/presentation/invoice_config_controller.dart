import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/invoice_config_models.dart';
import '../domain/invoice_config_repository.dart';

/// Controller da tela de Configuração Fiscal (`/m/invoice/config`).
///
/// Usa [AsyncNotifier] para expor [AsyncValue<InvoiceFiscalConfig>], espelhando
/// o padrão de [SettingsController]. O estado carrega automaticamente via
/// [build]; [load] pode ser chamado manualmente para re-buscar.
class InvoiceConfigController extends AsyncNotifier<InvoiceFiscalConfig> {
  InvoiceConfigRepository get _repo => ref.read(invoiceConfigRepositoryProvider);

  @override
  Future<InvoiceFiscalConfig> build() async {
    // Re-busca sempre que o tenant ativo muda (login / logout / switch-tenant) —
    // este provider é kept-alive; sem reagir à sessão manteria em cache a
    // config fiscal do tenant anterior ao trocar de conta.
    final session = ref.watch(sessionControllerProvider);
    final tenantId =
        session is SessionAuthenticated ? session.me.activeTenant?.id : null;
    if (tenantId == null) {
      throw StateError('Nenhum tenant ativo na sessão.');
    }
    return _repo.fetch();
  }

  /// Re-busca a configuração fiscal do servidor.
  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetch());
  }

  /// Aplica [patch] (apenas os campos alterados) e atualiza o estado em memória.
  Future<void> save(Map<String, dynamic> patch) async {
    final updated = await _repo.update(patch);
    state = AsyncData(updated);
  }

  /// Cadastra a empresa no provedor fiscal (usa a identidade fiscal já
  /// cadastrada no núcleo) e atualiza o estado em memória.
  Future<void> registerEmpresa() async {
    final updated = await _repo.registerEmpresa();
    state = AsyncData(updated);
  }

  /// Envia o certificado A1 (.pfx/.p12) + senha e atualiza o estado em memória.
  Future<void> pickAndUploadCertificate(
    Uint8List bytes,
    String filename,
    String password,
  ) async {
    final updated = await _repo.uploadCertificate(bytes, filename, password);
    state = AsyncData(updated);
  }
}
