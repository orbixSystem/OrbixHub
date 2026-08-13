import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/ui/neu_tokens.dart';
import 'package:orbixhub_front/features/os/presentation/os_status.dart';

/// Piso de acessibilidade do padrão SysOne, travado em teste.
///
/// Duas regras que o produto já violava em massa e que voltam sozinhas se
/// ninguém vigiar:
///  - **nenhum texto abaixo de 12px** (chegava a 7,5px);
///  - **texto normal em 4,5:1** de contraste (havia cor de texto em 1,7:1,
///    praticamente invisível).
///
/// O teste de tamanho lê o CÓDIGO porque a violação é textual e espalhada —
/// não há como flagrá-la montando uma tela. O de contraste calcula a razão de
/// verdade, sobre os tokens reais dos dois temas.

/// Luminância relativa (WCAG 2.1).
double _luminancia(Color c) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double razao(Color a, Color b) {
  final la = _luminancia(a), lb = _luminancia(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('nenhum texto de tela abaixo de 12px', () {
    // Geradores de PDF ficam de fora: papel é outro meio e a auditoria é
    // explicitamente sobre tela.
    final violacoes = <String>[];
    final regex = RegExp(r'fontSize:\s*([0-9.]+)');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) continue;
      if (f.path.contains('_pdf')) continue;
      final linhas = f.readAsLinesSync();
      for (var i = 0; i < linhas.length; i++) {
        for (final m in regex.allMatches(linhas[i])) {
          final v = double.parse(m.group(1)!);
          if (v < 12) violacoes.add('${f.path}:${i + 1} -> ${v}px');
        }
      }
    }
    expect(
      violacoes,
      isEmpty,
      reason: 'padrão SysOne: nunca usar texto abaixo de 12px.\n'
          '${violacoes.join('\n')}',
    );
  });

  group('contraste mínimo dos tokens (4,5:1 para texto normal)', () {
    void checarTema(String nome, NeuTokens t) {
      final fundos = <String, Color>{
        'base': t.base,
        'surface': t.surface,
        'surfaceHi': t.surfaceHi,
      };
      // Cores usadas como TEXTO sobre o canvas.
      final textos = <String, Color>{
        'ink': t.ink,
        'inkMuted': t.inkMuted,
        'inkFaint': t.inkFaint,
        'success': t.success,
        'danger': t.danger,
        'warning': t.warning,
        'info': t.info,
        'accent': t.accent,
        'navy': t.navy,
      };
      for (final e in textos.entries) {
        for (final f in fundos.entries) {
          final r = razao(e.value, f.value);
          expect(
            r,
            greaterThanOrEqualTo(4.5),
            reason: '$nome: ${e.key} sobre ${f.key} = '
                '${r.toStringAsFixed(2)}:1 (mínimo 4,5:1 para texto normal)',
          );
        }
      }
      // O rótulo do botão primário é texto sobre a cor de ação.
      final rotulo = razao(t.onNavy, t.navy);
      expect(
        rotulo,
        greaterThanOrEqualTo(4.5),
        reason: '$nome: rótulo do botão primário (onNavy sobre navy) = '
            '${rotulo.toStringAsFixed(2)}:1',
      );
    }

    test('tema claro', () => checarTema('claro', NeuTokens.light()));
    test('tema escuro', () => checarTema('escuro', NeuTokens.dark()));

    test('cores de status da OS usadas como texto', () {
      // A paleta gráfica do status (osStatusColor) não serve de texto — o
      // âmbar dá 2,3:1 com branco. osStatusInk é a variante que serve, e é
      // ela que precisa continuar servindo.
      for (final s in osStatuses) {
        for (final b in Brightness.values) {
          final claro = b == Brightness.light;
          final t = claro ? NeuTokens.light() : NeuTokens.dark();
          final ink = osStatusInk(s, b);
          for (final fundo in [t.base, t.surface, t.surfaceHi]) {
            expect(
              razao(ink, fundo),
              greaterThanOrEqualTo(4.5),
              reason: 'osStatusInk("$s", $b) sobre o canvas = '
                  '${razao(ink, fundo).toStringAsFixed(2)}:1',
            );
          }
        }
        // A variante clara também é fundo de chip sólido com rótulo branco.
        final r = razao(const Color(0xFFFFFFFF), osStatusInk(s, Brightness.light));
        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason: 'rótulo branco sobre o chip sólido de "$s" = '
              '${r.toStringAsFixed(2)}:1',
        );
      }
    });

    test('tema monocromático (seed acromática)', () {
      const cinza = Color(0xFF808080);
      checarTema('mono claro', NeuTokens.forSeed(cinza, Brightness.light));
      checarTema('mono escuro', NeuTokens.forSeed(cinza, Brightness.dark));
    });

    test('todas as paletas por cor-semente', () {
      // A paleta é gerada de uma cor-semente: corrigir só a Lavanda deixaria as
      // demais reprovando. Varre o círculo de matizes.
      for (var h = 0; h < 360; h += 30) {
        final seed = HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.5).toColor();
        checarTema('seed h=$h (claro)', NeuTokens.forSeed(seed, Brightness.light));
        checarTema('seed h=$h (escuro)', NeuTokens.forSeed(seed, Brightness.dark));
      }
    });
  });
}
