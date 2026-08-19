import '../../../core/error/app_exception.dart';

/// Por que a falha aconteceu — cada uma pede uma reação diferente de quem
/// abriu o link.
enum TrackingErrorKind {
  /// O token na URL nem tem forma de token (link truncado no WhatsApp, etc.).
  linkInvalido,

  /// O servidor respondeu que não existe OS para esse token (404).
  naoEncontrado,

  /// Não houve resposta: servidor fora, rede caída, CORS.
  semConexao,

  /// O servidor respondeu, mas quebrou (5xx).
  servidor,

  /// Outro 4xx (429, 403…) — mostra o que o backend disse.
  outro,
}

/// O que a tela pública deve mostrar para uma falha.
class TrackingErrorInfo {
  const TrackingErrorInfo({
    required this.kind,
    required this.title,
    required this.message,
    required this.canRetry,
    this.detail,
  });

  final TrackingErrorKind kind;
  final String title;
  final String message;

  /// Se faz sentido oferecer "Tentar de novo" — só quando a falha pode passar
  /// sozinha. Link errado não melhora com insistência.
  final bool canRetry;

  /// Linha técnica curta (status + requestId) exibida em miúdo. É o que a
  /// pessoa lê no telefone e repassa para quem for investigar: com ela dá para
  /// achar a linha exata no log do servidor.
  final String? detail;
}

/// Traduz a falha em algo verdadeiro.
///
/// Antes, QUALQUER erro virava "Acompanhamento não encontrado" — servidor fora,
/// 500 do banco, CORS. O cliente concluía que a OS não existe e a oficina
/// levava a culpa por um problema de infraestrutura.
TrackingErrorInfo trackingErrorInfo({
  required bool validToken,
  required AppException? error,
}) {
  if (!validToken) {
    return const TrackingErrorInfo(
      kind: TrackingErrorKind.linkInvalido,
      title: 'Link inválido',
      message: 'Esse link parece incompleto. Confira se ele foi copiado '
          'inteiro, ou peça um novo à oficina.',
      canRetry: false,
    );
  }

  final status = error?.statusCode;

  if (error == null || status == 404) {
    return const TrackingErrorInfo(
      kind: TrackingErrorKind.naoEncontrado,
      title: 'Acompanhamento não encontrado',
      message: 'Verifique o link recebido. Se o problema continuar, entre em '
          'contato com a oficina.',
      canRetry: false,
    );
  }

  if (status == null) {
    return TrackingErrorInfo(
      kind: TrackingErrorKind.semConexao,
      title: 'Sem conexão com o servidor',
      message: 'Não conseguimos falar com o sistema da oficina. Verifique sua '
          'internet e tente de novo.',
      canRetry: true,
      detail: _detalhe(error),
    );
  }

  if (status >= 500) {
    return TrackingErrorInfo(
      kind: TrackingErrorKind.servidor,
      title: 'Sistema temporariamente indisponível',
      message: 'O acompanhamento existe, mas o sistema falhou ao carregá-lo. '
          'Tente de novo em instantes.',
      canRetry: true,
      detail: _detalhe(error),
    );
  }

  return TrackingErrorInfo(
    kind: TrackingErrorKind.outro,
    title: 'Não foi possível carregar',
    message: error.message,
    canRetry: true,
    detail: _detalhe(error),
  );
}

/// `500 · req 8f2c1d…` — status sempre; requestId quando o servidor mandou.
String? _detalhe(AppException? e) {
  if (e == null) return null;
  final status = e.statusCode?.toString() ?? 'sem resposta';
  final id = e.requestId;
  return id == null ? 'Código: $status' : 'Código: $status · req $id';
}
