// Deriva os PNGs-mestre do ícone do app a partir do logo oficial da marca.
//
// A arte de origem (`tool/icon/orbix-logo-source.png`) é um "ícone pronto":
// quadrado navy de cantos arredondados, sobre fundo BRANCO (a arte é RGB, sem
// canal alpha). Isso não serve direto para nenhuma plataforma:
//
//   • iOS/macOS/Windows já aplicam a própria máscara de canto — entregar a arte
//     crua deixaria uma moldura branca em volta do quadrado arredondado.
//   • O adaptive icon do Android recorta a imagem — o quadrado arredondado
//     apareceria recortado *dentro* da máscara do sistema.
//
// Então geramos duas variantes:
//   icon_master.png     full-bleed navy, sem alpha (iOS/web/Windows/macOS)
//   icon_foreground.png só o glyph, transparente, na zona segura (Android)
//
// O fundo branco é identificado por flood fill a partir dos cantos, e não por
// "todo pixel claro": o nó do glyph também é quase branco, mas é cercado de
// navy, então o preenchimento não chega nele.
//
// Como rodar (a partir de `front/`):
//   dart run tool/build_app_icons.dart
//   dart run flutter_launcher_icons

import 'dart:io';

import 'package:image/image.dart';

/// Lado dos PNGs-mestre — 1024 é o maior slot exigido por iOS/macOS.
const _size = 1024;

/// Um pixel conta como "claro" (candidato a fundo) se nenhum canal for escuro.
const _lightThreshold = 150;

/// Distância máxima (Manhattan) ao navy para o pixel contar como fundo do card.
const _navyTolerance = 60;

/// Faixa de transição acima da tolerância, onde o alpha sobe de 0 a 255 —
/// preserva o antialiasing das bordas do glyph.
const _navyFeather = 60;

/// Fração do canvas ocupada pelo glyph no foreground do adaptive icon. O
/// Android só garante os ~66% centrais; 0.60 deixa uma folga confortável.
const _foregroundScale = 0.60;

/// Alpha mínimo para um pixel entrar no enquadramento do glyph.
const _bboxMinAlpha = 200;

void main() {
  final sourceFile = File('tool/icon/orbix-logo-source.png');
  if (!sourceFile.existsSync()) {
    stderr.writeln('Arte de origem não encontrada: ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  final src = decodePng(sourceFile.readAsBytesSync())!;
  stdout.writeln('origem: ${src.width}x${src.height} (${src.numChannels} canais)');

  // Fundo branco externo, achado por flood fill a partir dos quatro cantos.
  final outside = _floodFillBackground(src);

  // O navy do card: amostrado logo abaixo do topo do quadrado, onde não há glyph.
  final navy = _sampleCardColor(src, outside);
  stdout.writeln('navy do card: ${_hex(navy)}');

  _writeMaster(src, outside, navy);
  _writeForeground(src, outside, navy);
}

/// Marca o fundo externo: pixels claros conectados à borda da imagem.
///
/// Flood fill iterativo (4-vizinhos). Depois dilata 2px para engolir a franja
/// antialiasada entre o branco e a borda do card.
List<bool> _floodFillBackground(Image src) {
  final w = src.width;
  final h = src.height;
  final mask = List<bool>.filled(w * h, false);

  bool isLight(int x, int y) {
    final p = src.getPixel(x, y);
    return p.r >= _lightThreshold &&
        p.g >= _lightThreshold &&
        p.b >= _lightThreshold;
  }

  final stack = <int>[];
  void seed(int x, int y) {
    final i = y * w + x;
    if (!mask[i] && isLight(x, y)) {
      mask[i] = true;
      stack.add(i);
    }
  }

  // Semeia a borda inteira, não só os quatro cantos — mais robusto.
  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) seed(x - 1, y);
    if (x < w - 1) seed(x + 1, y);
    if (y > 0) seed(x, y - 1);
    if (y < h - 1) seed(x, y + 1);
  }

  return _dilate(mask, w, h, 2);
}

List<bool> _dilate(List<bool> mask, int w, int h, int radius) {
  var current = mask;
  for (var pass = 0; pass < radius; pass++) {
    final next = List<bool>.from(current);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (current[y * w + x]) continue;
        final up = y > 0 && current[(y - 1) * w + x];
        final down = y < h - 1 && current[(y + 1) * w + x];
        final left = x > 0 && current[y * w + x - 1];
        final right = x < w - 1 && current[y * w + x + 1];
        if (up || down || left || right) next[y * w + x] = true;
      }
    }
    current = next;
  }
  return current;
}

/// Cor com que o fundo externo é preenchido: a média do card *junto à borda*,
/// medida nos quatro lados.
///
/// O card tem um leve gradiente — mais escuro nas bordas. Amostrar o miolo daria
/// um tom claro demais e deixaria uma moldura visível em volta do contorno
/// antigo; é a borda que precisa casar, porque é ali que a emenda acontece.
ColorRgb8 _sampleCardColor(Image src, List<bool> outside) {
  final w = src.width;
  final h = src.height;
  // Quantos pixels entrar no card antes de medir, para fugir do antialiasing.
  final depth = w ~/ 60;

  var r = 0, g = 0, b = 0, n = 0;

  void sampleFrom(int startX, int startY, int stepX, int stepY) {
    var x = startX;
    var y = startY;
    while (x >= 0 && x < w && y >= 0 && y < h) {
      if (!outside[y * w + x]) {
        final px = (x + stepX * depth).clamp(0, w - 1);
        final py = (y + stepY * depth).clamp(0, h - 1);
        final p = src.getPixel(px, py);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
        return;
      }
      x += stepX;
      y += stepY;
    }
  }

  sampleFrom(w ~/ 2, 0, 0, 1); // de cima para baixo
  sampleFrom(w ~/ 2, h - 1, 0, -1); // de baixo para cima
  sampleFrom(0, h ~/ 2, 1, 0); // da esquerda para a direita
  sampleFrom(w - 1, h ~/ 2, -1, 0); // da direita para a esquerda

  if (n == 0) return ColorRgb8(0x1B, 0x20, 0x45);
  return ColorRgb8(r ~/ n, g ~/ n, b ~/ n);
}

/// Full-bleed: o card ocupa todo o quadrado e o resultado sai sem canal alpha —
/// que é o que iOS/macOS/Windows esperam receber para aplicar a própria máscara
/// de canto.
///
/// Onde havia branco (margem e cantos arredondados) entra o navy do card. Fica
/// uma emenda de contraste baixíssimo no contorno antigo, imperceptível nos
/// tamanhos em que um ícone é realmente exibido.
void _writeMaster(Image src, List<bool> outside, ColorRgb8 navy) {
  final w = src.width;
  final h = src.height;
  final flat = Image(width: w, height: h, numChannels: 3);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (outside[y * w + x]) {
        flat.setPixelRgb(x, y, navy.r, navy.g, navy.b);
      } else {
        final p = src.getPixel(x, y);
        flat.setPixelRgb(x, y, p.r, p.g, p.b);
      }
    }
  }

  _save(
    'icon_master.png',
    copyResize(
      flat,
      width: _size,
      height: _size,
      interpolation: Interpolation.cubic,
    ),
  );
}

/// Foreground do adaptive icon: só o glyph, recortado, sobre fundo transparente
/// e reduzido para a zona segura do Android.
void _writeForeground(Image src, List<bool> outside, ColorRgb8 navy) {
  final cut = Image(width: src.width, height: src.height, numChannels: 4);

  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (outside[y * src.width + x]) continue; // fundo branco externo
      final p = src.getPixel(x, y);
      final d = (p.r - navy.r).abs() + (p.g - navy.g).abs() + (p.b - navy.b).abs();
      if (d <= _navyTolerance) continue; // fundo navy do card

      final alpha = d >= _navyTolerance + _navyFeather
          ? 255
          : (((d - _navyTolerance) / _navyFeather) * 255).round();
      cut.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha);

      // Só pixels bem opacos definem o enquadramento: a franja antialiasada da
      // borda do card sobrevive fraca ao recorte e, se contasse, puxaria o
      // bounding box e descentralizaria o glyph.
      if (alpha >= _bboxMinAlpha) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) {
    stderr.writeln('Não sobrou glyph após remover o fundo — confira a arte.');
    exitCode = 1;
    return;
  }

  // Recorta num quadrado centrado no glyph, para não distorcer ao redimensionar.
  final side = (maxX - minX + 1) > (maxY - minY + 1)
      ? (maxX - minX + 1)
      : (maxY - minY + 1);
  final cx = (minX + maxX) ~/ 2;
  final cy = (minY + maxY) ~/ 2;
  final glyph = copyCrop(
    cut,
    x: cx - side ~/ 2,
    y: cy - side ~/ 2,
    width: side,
    height: side,
  );
  stdout.writeln('glyph recortado: ${side}x$side');

  final inner = (_size * _foregroundScale).round();
  final canvas = Image(width: _size, height: _size, numChannels: 4);
  compositeImage(
    canvas,
    copyResize(
      glyph,
      width: inner,
      height: inner,
      interpolation: Interpolation.cubic,
    ),
    dstX: (_size - inner) ~/ 2,
    dstY: (_size - inner) ~/ 2,
  );

  _save('icon_foreground.png', canvas);
}

String _hex(ColorRgb8 c) =>
    '#${c.r.toInt().toRadixString(16).padLeft(2, '0')}'
    '${c.g.toInt().toRadixString(16).padLeft(2, '0')}'
    '${c.b.toInt().toRadixString(16).padLeft(2, '0')}';

void _save(String name, Image img) {
  final file = File('tool/icon/$name')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(encodePng(img));
  stdout.writeln('✔ ${file.path} (${file.lengthSync()} bytes)');
}
