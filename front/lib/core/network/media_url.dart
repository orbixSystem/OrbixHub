import '../config/app_config.dart';

/// Resolve a URL de uma mídia servida pelo NOSSO backend (fotos de veículo/OS,
/// logo do tenant) contra o endereço que ESTE dispositivo consegue alcançar.
///
/// O backend grava a URL usando `STORAGE_PUBLIC_URL`, um valor fixo escolhido no
/// servidor — e ele quase nunca vale para todos os clientes ao mesmo tempo:
/// `http://localhost:3000` funciona no desktop que roda a API, mas no emulador
/// Android `localhost` é o próprio emulador (o host é `10.0.2.2`), e uma porta
/// diferente da que a API está servindo simplesmente não responde. O resultado é
/// a foto virar "indisponível" mesmo tendo sido enviada com sucesso.
///
/// Aqui reescrevemos só o que é nosso e local: URLs relativas (`/files/x`) e
/// URLs apontando para um host de loopback. Endereços externos (logos de marca,
/// S3/MinIO, domínio de produção) passam intactos.
String? resolveMediaUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;

  final api = Uri.parse(AppConfig.apiBaseUrl);

  // Relativa (`/files/abc.jpg`) — resolve contra a origem da API.
  if (!uri.hasScheme) {
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${api.origin}$path';
  }

  if (!_isLoopback(uri.host)) return trimmed;

  // Loopback: mantém caminho e query, troca host/porta/esquema pelos da API.
  return uri
      .replace(
        scheme: api.scheme,
        host: api.host,
        port: api.hasPort ? api.port : null,
      )
      .toString();
}

/// Hosts que só valem dentro da máquina/emulador que os gerou.
bool _isLoopback(String host) =>
    host == 'localhost' ||
    host == '127.0.0.1' ||
    host == '0.0.0.0' ||
    host == '10.0.2.2' || // host da máquina visto de dentro do emulador Android
    host == '10.0.3.2'; // idem no Genymotion
