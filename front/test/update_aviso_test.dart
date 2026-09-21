import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/update/domain/update_models.dart';
import 'package:orbixhub_front/features/update/presentation/update_controller.dart';
import 'package:orbixhub_front/features/update/presentation/update_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O gap: quem entra no app e FICA (o balcão que não desliga a máquina nem faz
/// logout) nunca era consultado de novo — `updateStatusProvider` é um future
/// cacheado, avaliado uma vez. E o "Depois" do banner era estado do widget:
/// morria no primeiro rebuild, então o aviso voltava a interromper e a palavra
/// não significava nada.
///
/// O que estes testes fixam: "Depois" sobrevive à sessão, manda o aviso para o
/// sino (sem esquecê-lo) e vale só para AQUELA versão.

const _nova = AppUpdate(
  enabled: true,
  platform: 'windows',
  version: '1.0.0',
  buildNumber: 14,
  url: 'https://objects.example/setup.exe',
  notes: 'Correções no caixa',
);

/// Espera o notifier terminar de LER as preferências (canal assíncrono). Sem
/// isto o teste leria o estado inicial (`null`) e passaria por acidente,
/// afirmando "banner" antes de o "depois" chegar do disco.
Future<void> _esperarCarga(ProviderContainer c, String esperado) async {
  for (var i = 0; i < 50; i++) {
    if (c.read(atualizacaoAdiadaProvider) == esperado) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('o "depois" gravado ($esperado) não foi carregado das preferências');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Sobrescreve o resultado da consulta ao servidor — o provider real depende
  /// de plataforma instalável (Windows/Android) e de rede. Função LOCAL porque
  /// o tipo da lista (`Override`) não é exportado pelo riverpod.
  overrides(UpdateStatus status, [AppUpdate update = _nova]) => [
        updateStatusProvider.overrideWith(
          (ref) async => (status: status, update: update),
        ),
      ];

  group('onde o aviso aparece (com persistência de verdade)', () {
    test('disponível: banner. Depois de adiar: sino', () async {
      final c = ProviderContainer(
        overrides: overrides(UpdateStatus.disponivel),
      );
      addTearDown(c.dispose);
      await c.read(updateStatusProvider.future);

      expect(c.read(avisoAtualizacaoProvider).onde, AvisoAtualizacao.banner);

      await c.read(atualizacaoAdiadaProvider.notifier).adiar('1.0.0+14');

      // Sai do caminho, mas NÃO é esquecido — é o ponto do pedido.
      expect(c.read(avisoAtualizacaoProvider).onde, AvisoAtualizacao.sino);
    });

    test('o "depois" sobrevive a reiniciar o app', () async {
      final primeiro = ProviderContainer(
        overrides: overrides(UpdateStatus.disponivel),
      );
      await primeiro.read(updateStatusProvider.future);
      await primeiro.read(atualizacaoAdiadaProvider.notifier).adiar('1.0.0+14');
      primeiro.dispose();

      // Outro container = outra execução do app, mesmas preferências.
      final segundo = ProviderContainer(
        overrides: overrides(UpdateStatus.disponivel),
      );
      addTearDown(segundo.dispose);
      await segundo.read(updateStatusProvider.future);
      await _esperarCarga(segundo, '1.0.0+14');

      expect(
        segundo.read(avisoAtualizacaoProvider).onde,
        AvisoAtualizacao.sino,
        reason: 'antes o "Depois" morria com o widget e o banner voltava',
      );
    });

    test('versão NOVA volta a avisar, mesmo tendo adiado a anterior', () async {
      SharedPreferences.setMockInitialValues({
        'update_adiada_versao': '1.0.0+13',
      });
      final c = ProviderContainer(
        overrides: overrides(UpdateStatus.disponivel),
      );
      addTearDown(c.dispose);
      await c.read(updateStatusProvider.future);
      await _esperarCarga(c, '1.0.0+13');

      // Dispensar uma versão não pode silenciar o app para sempre.
      expect(c.read(avisoAtualizacaoProvider).onde, AvisoAtualizacao.banner);
    });

    test('obrigatória bloqueia mesmo com "depois" gravado', () async {
      SharedPreferences.setMockInitialValues({
        'update_adiada_versao': '1.0.0+14',
      });
      final c = ProviderContainer(
        overrides: overrides(UpdateStatus.obrigatoria),
      );
      addTearDown(c.dispose);
      await c.read(updateStatusProvider.future);
      await _esperarCarga(c, '1.0.0+14');

      // Aqui seguir usando daria erro a cada ação: não há "depois" a respeitar.
      expect(c.read(avisoAtualizacaoProvider).onde, AvisoAtualizacao.bloqueio);
    });
  });

  group('UpdateWatcher', () {
    Future<void> montar(WidgetTester t, UpdateStatus status) async {
      await t.pumpWidget(ProviderScope(
        overrides: overrides(status),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: UpdateWatcher()),
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('mostra a faixa quando há versão nova', (t) async {
      await montar(t, UpdateStatus.disponivel);

      expect(find.text('Versão 1.0.0 disponível.'), findsOneWidget);
      expect(find.text('Depois'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
    });

    testWidgets('"Depois" tira a faixa do caminho', (t) async {
      await montar(t, UpdateStatus.disponivel);

      await t.tap(find.text('Depois'));
      await t.pumpAndSettle();

      // A faixa sai; o aviso continua existindo, agora no sino (coberto pelos
      // testes de provider acima).
      expect(find.text('Versão 1.0.0 disponível.'), findsNothing);
    });

    testWidgets('em dia não desenha nada', (t) async {
      await montar(t, UpdateStatus.emDia);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.textContaining('disponível'), findsNothing);
    });

    testWidgets('obrigatória não vira faixa — quem bloqueia é o shell',
        (t) async {
      await montar(t, UpdateStatus.obrigatoria);
      // Uma faixa adiável ao lado de um bloqueio de tela seria o app dizendo
      // duas coisas diferentes sobre a mesma versão.
      expect(find.text('Depois'), findsNothing);
    });
  });
}
