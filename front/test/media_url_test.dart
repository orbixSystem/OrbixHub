import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/config/app_config.dart';
import 'package:orbixhub_front/core/network/media_url.dart';

/// A URL da foto é gravada pelo backend com o host DELE (STORAGE_PUBLIC_URL).
/// Se esse host/porta não for alcançável pelo dispositivo, a foto vira
/// "Foto indisponível" mesmo tendo subido — por isso resolvemos no cliente.
void main() {
  // Nos testes (VM desktop) a base é http://localhost:4400/api.
  final origin = Uri.parse(AppConfig.apiBaseUrl).origin;

  group('resolveMediaUrl', () {
    test('conserta a porta errada do STORAGE_PUBLIC_URL', () {
      // Backend configurado em :3000, API servindo em :4400 → foto quebrada.
      expect(
        resolveMediaUrl('http://localhost:3000/files/abc.jpg'),
        '$origin/files/abc.jpg',
      );
    });

    test('conserta host de emulador (10.0.2.2) visto do desktop', () {
      expect(
        resolveMediaUrl('http://10.0.2.2:4400/files/abc.jpg'),
        '$origin/files/abc.jpg',
      );
    });

    test('resolve URL relativa contra a origem da API', () {
      expect(resolveMediaUrl('/files/abc.jpg'), '$origin/files/abc.jpg');
      expect(resolveMediaUrl('files/abc.jpg'), '$origin/files/abc.jpg');
    });

    test('preserva caminho e query ao reescrever', () {
      expect(
        resolveMediaUrl('http://127.0.0.1:9000/files/a/b.jpg?v=2'),
        '$origin/files/a/b.jpg?v=2',
      );
    });

    test('NÃO mexe em endereços externos', () {
      const logo =
          'https://raw.githubusercontent.com/x/logos/thumb/volkswagen.png';
      expect(resolveMediaUrl(logo), logo);
      const s3 = 'https://cdn.exemplo.com/orbix/foto.jpg';
      expect(resolveMediaUrl(s3), s3);
    });

    test('vazio/nulo/só espaços → null (cai no placeholder)', () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl(''), isNull);
      expect(resolveMediaUrl('   '), isNull);
    });
  });
}
