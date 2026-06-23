import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/network/access_token_store.dart';
import 'core/network/auth_interceptor.dart';
import 'core/network/token_refresh_service.dart';
import 'core/storage/secure_token_store.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/auth/presentation/session_state.dart';
import 'features/billing/data/billing_repository_impl.dart';
import 'features/billing/domain/billing_repository.dart';
import 'features/customers/data/customers_repository_impl.dart';
import 'features/customers/domain/customers_repository.dart';
import 'features/dashboard/data/dashboard_repository_impl.dart';
import 'features/dashboard/presentation/dashboard_providers.dart';
import 'features/inventory/data/inventory_repository_impl.dart';
import 'features/inventory/presentation/inventory_providers.dart';
import 'features/messages/data/messages_repository_impl.dart';
import 'features/messages/presentation/messages_providers.dart';
import 'features/notifications/data/notifications_repository_impl.dart';
import 'features/notifications/presentation/notifications_providers.dart';
import 'features/os/data/os_repository_impl.dart';
import 'features/os/presentation/os_providers.dart';
import 'features/team/data/team_repository_impl.dart';
import 'features/team/domain/team_repository.dart';
import 'features/settings/data/settings_repository_impl.dart';
import 'features/settings/domain/settings_models.dart';
import 'features/settings/domain/settings_repository.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/tracking/data/tracking_repository_impl.dart';
import 'features/tracking/domain/tracking_repository.dart';

/// Composition root. Wires building blocks into providers. Tests override the
/// repository providers with fakes; everything downstream stays untouched.

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    );

final secureTokenStoreProvider =
    Provider<SecureTokenStore>((ref) => SecureTokenStore());

final accessTokenStoreProvider =
    Provider<AccessTokenStore>((ref) => AccessTokenStore());

/// Bare dio with NO interceptors — used only by the refresh service so the
/// refresh call can never recurse into the 401 handler.
final bareDioProvider = Provider<Dio>((ref) => Dio(_baseOptions()));

final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  return TokenRefreshService(
    bareDio: ref.read(bareDioProvider),
    accessStore: ref.read(accessTokenStoreProvider),
    secureStore: ref.read(secureTokenStoreProvider),
  );
});

/// The app dio: attaches the bearer and does single-flight refresh-and-retry.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      accessStore: ref.read(accessTokenStoreProvider),
      refreshService: ref.read(tokenRefreshServiceProvider),
      onSessionExpired: () {
        ref.read(sessionControllerProvider.notifier).expire();
      },
    ),
  );
  return dio;
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl(ref.read(dioProvider)));

final billingRepositoryProvider = Provider<BillingRepository>(
    (ref) => BillingRepositoryImpl(ref.read(dioProvider)));

final teamRepositoryProvider = Provider<TeamRepository>(
    (ref) => TeamRepositoryImpl(ref.read(dioProvider)));

final customersRepositoryProvider = Provider<CustomersRepository>(
    (ref) => CustomersRepositoryImpl(ref.read(dioProvider)));

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepositoryImpl(ref.read(dioProvider)));

/// Acompanhamento público: Dio LIMPO (sem bearer/refresh) — endpoints `@Public`.
final trackingRepositoryProvider =
    Provider<TrackingRepository>((ref) => TrackingRepositoryImpl());

/// Overrides do composition root — passados ao `ProviderScope` em main.dart.
/// O `inventoryRepositoryProvider` é declarado em `inventory_providers.dart`
/// (lança por padrão) e ganha a impl real (dio) aqui, espelhando os demais repos.
final diOverrides = [
  inventoryRepositoryProvider.overrideWith(
    (ref) => InventoryRepositoryImpl(ref.read(dioProvider)),
  ),
  osRepositoryProvider.overrideWith(
    (ref) => OsRepositoryImpl(ref.read(dioProvider)),
  ),
  messagesRepositoryProvider.overrideWith(
    (ref) => MessagesRepositoryImpl(ref.read(dioProvider)),
  ),
  notificationsRepositoryProvider.overrideWith(
    (ref) => NotificationsRepositoryImpl(ref.read(dioProvider)),
  ),
  dashboardRepositoryProvider.overrideWith(
    (ref) => DashboardRepositoryImpl(ref.read(dioProvider)),
  ),
];

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsBundle>(
  SettingsController.new,
);
