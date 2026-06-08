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
import 'features/team/data/team_repository_impl.dart';
import 'features/team/domain/team_repository.dart';
import 'features/tracking/data/fake_tracking_repository.dart';
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

final trackingRepositoryProvider =
    Provider<TrackingRepository>((ref) => const FakeTrackingRepository());

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
