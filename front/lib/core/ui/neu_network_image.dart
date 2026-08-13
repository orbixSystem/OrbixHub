import 'package:flutter/material.dart';

import '../network/media_url.dart';
import 'neu_tokens.dart';

/// Imagem de rede (S3/MinIO) com placeholder de carregamento e de ERRO embutidos
/// — nunca deixa um 404/URL expirada quebrar a UI com o "quadrado quebrado" do
/// Flutter. Use em toda carga de foto (galerias, miniaturas de chat,
/// comentarios). Cantos arredondados opcionais via [radius].
class NeuNetworkImage extends StatelessWidget {
  const NeuNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    Widget placeholder({required bool loading}) => Container(
          width: width,
          height: height,
          color: neu.base,
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: neu.inkFaint,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined,
                        color: neu.inkFaint, size: 26),
                    if ((height ?? 0) >= 72 || height == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Foto indisponível',
                        style: TextStyle(color: neu.inkFaint, fontSize: 12),
                      ),
                    ],
                  ],
                ),
        );

    // A URL vem do backend com o host que ELE conhece; resolvemos para o que
    // este dispositivo alcança (senão a foto vira "indisponível" no emulador
    // ou quando a porta da API não é a do STORAGE_PUBLIC_URL).
    final src = resolveMediaUrl(url) ?? '';
    final Widget child = src.isEmpty
        ? placeholder(loading: false)
        : Image.network(
            src,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, w, progress) =>
                progress == null ? w : placeholder(loading: true),
            errorBuilder: (_, _, _) => placeholder(loading: false),
          );

    if (radius <= 0) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}
