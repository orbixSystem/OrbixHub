import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('loads the persisted theme_mode into state', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Trigger build (which kicks off the async _load), then let it settle.
    container.read(themeControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(themeControllerProvider), ThemeMode.dark);
  });

  test('set updates state and persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(themeControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await notifier.set(ThemeMode.light);

    expect(container.read(themeControllerProvider), ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
  });
}
