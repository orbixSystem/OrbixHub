import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:printing/printing.dart';

/// Testes de PLATAFORMA (não rodam em `flutter test` — precisam de dispositivo):
///
///     flutter test integration_test/file_picker_platform_test.dart -d macos
///     flutter test integration_test/file_picker_platform_test.dart -d <android>
///     flutter test integration_test/file_picker_platform_test.dart -d windows
///
/// Guardam a regressão que motivou este arquivo: no macOS o file_picker recusa
/// a operação com `ENTITLEMENT_NOT_FOUND` quando o app não declara
/// `com.apple.security.files.user-selected.read-*` — e recusa MESMO com a
/// sandbox desligada, porque ele consulta os entitlements do processo.
///
/// Como o seletor é um diálogo modal (ninguém o fecha num teste automatizado),
/// verificamos o que importa e é determinístico: a chamada não é rejeitada de
/// imediato pela camada nativa. Erro de configuração aparece na hora; o
/// diálogo aberto significa que a plataforma aceitou o pedido.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seletor de arquivos abre sem ser barrado pela plataforma', (
    tester,
  ) async {
    Object? erro;
    unawaited(
      FilePicker.pickFiles(type: FileType.image, withData: true)
          .catchError((Object e) {
        erro = e;
        return null;
      }),
    );

    // Janela curta: uma recusa de configuração (entitlement/permissão ausente)
    // volta em milissegundos, bem antes de qualquer interação do usuário.
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(seconds: 3));

    if (erro is PlatformException) {
      final e = erro as PlatformException;
      fail(
        'A plataforma recusou o seletor de arquivos: ${e.code} — ${e.message}. '
        'No macOS, adicione com.apple.security.files.user-selected.read-write '
        'aos entitlements (Debug e Release).',
      );
    }
    expect(erro, isNull, reason: 'Falha inesperada ao abrir o seletor: $erro');
  });

  testWidgets('impressão está disponível (PDF de OS/ficha/relatórios)', (
    tester,
  ) async {
    // No macOS sob sandbox isto exige com.apple.security.print; em Android e
    // Windows o serviço é do sistema. `info` consulta a camada nativa.
    final info = await Printing.info();
    expect(
      info.canPrint || info.canShare,
      isTrue,
      reason: 'Nem impressão nem compartilhamento disponíveis: $info',
    );
  });
}
