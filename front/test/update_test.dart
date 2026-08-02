import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/update/domain/update_models.dart';

/// A decisão de atualizar é uma função pura — e é ela que pode travar a
/// oficina no meio do expediente. Por isso está coberta caso a caso.

const _base = AppUpdate(
  enabled: true,
  platform: 'android',
  version: '1.2.0',
  minSupported: '1.1.0',
  url: 'https://objects.example/app.apk',
  sha256: 'abc',
);

void main() {
  group('compareVersions', () {
    test('compara por partes, não por texto', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
    });

    test('partes faltantes valem zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('2', '1.9.9'), greaterThan(0));
    });

    test('ignora o build number ("1.2.3+45")', () {
      expect(compareVersions('1.2.3+45', '1.2.3+9'), 0);
    });
  });

  group('resolveUpdateStatus', () {
    test('versão nova disponível → sugere (adiável)', () {
      expect(
        resolveUpdateStatus(installedVersion: '1.1.5', update: _base),
        UpdateStatus.disponivel,
      );
    });

    test('abaixo do mínimo suportado → obrigatória', () {
      expect(
        resolveUpdateStatus(installedVersion: '1.0.9', update: _base),
        UpdateStatus.obrigatoria,
      );
    });

    test('exatamente no mínimo ainda é adiável', () {
      expect(
        resolveUpdateStatus(installedVersion: '1.1.0', update: _base),
        UpdateStatus.disponivel,
      );
    });

    test('já na última versão → nada a fazer', () {
      expect(
        resolveUpdateStatus(installedVersion: '1.2.0', update: _base),
        UpdateStatus.emDia,
      );
    });

    test('versão à frente (build local) não pede downgrade', () {
      expect(
        resolveUpdateStatus(installedVersion: '1.3.0', update: _base),
        UpdateStatus.emDia,
      );
    });

    test('servidor sem atualização configurada não incomoda ninguém', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '0.1.0',
          update: const AppUpdate(enabled: false),
        ),
        UpdateStatus.emDia,
      );
    });

    test('resposta sem URL não vira atualização (nada a baixar)', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '1.0.0',
          update: const AppUpdate(enabled: true, version: '9.9.9'),
        ),
        UpdateStatus.emDia,
      );
    });

    test('sem minSupported, só sugere — nunca bloqueia', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '0.0.1',
          update: const AppUpdate(
            enabled: true,
            version: '5.0.0',
            url: 'https://objects.example/app.apk',
          ),
        ),
        UpdateStatus.disponivel,
      );
    });
  });

  group('build number (mesma versão, publicação nova)', () {
    // O caso do dia a dia: o pubspec fica em 1.0.0 e cada publicação muda só o
    // build. Ignorar o build faria toda atualização passar despercebida.
    const mesmaVersao = AppUpdate(
      enabled: true,
      version: '1.0.0',
      buildNumber: 13,
      minSupported: '1.0.0',
      minSupportedBuild: 13,
      url: 'https://objects.example/app.apk',
    );

    test('build mais velho na mesma versão → obrigatória (forceAll)', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '1.0.0',
          installedBuild: 12,
          update: mesmaVersao,
        ),
        UpdateStatus.obrigatoria,
      );
    });

    test('mesmo build → em dia', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '1.0.0',
          installedBuild: 13,
          update: mesmaVersao,
        ),
        UpdateStatus.emDia,
      );
    });

    test('versão maior vence o build menor', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '1.1.0',
          installedBuild: 1,
          update: mesmaVersao,
        ),
        UpdateStatus.emDia,
      );
    });

    test('sem mínimo de build, versão nova ainda é sugerida', () {
      expect(
        resolveUpdateStatus(
          installedVersion: '1.0.0',
          installedBuild: 12,
          update: const AppUpdate(
            enabled: true,
            version: '1.0.0',
            buildNumber: 13,
            url: 'https://objects.example/app.apk',
          ),
        ),
        UpdateStatus.disponivel,
      );
    });
  });

  group('AppUpdate.fromJson', () {
    test('lê a resposta do backend', () {
      final u = AppUpdate.fromJson(const {
        'enabled': true,
        'platform': 'windows',
        'version': '1.0.3',
        'buildNumber': 12,
        'minSupported': '1.0.0',
        'notes': 'Correções na OS',
        'url': 'https://objects.example/setup.exe?token=x',
        'sha256': 'def456',
        'sizeBytes': 45000000,
      });
      expect(u.hasDownload, isTrue);
      expect(u.version, '1.0.3');
      expect(u.sha256, 'def456');
      expect(u.sizeBytes, 45000000);
    });
  });
}
