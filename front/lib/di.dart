import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/network/access_token_store.dart';
import 'core/network/refresh_token_store.dart';
import 'core/network/server_time.dart';
import 'core/offline/connectivity_controller.dart';
import 'core/offline/db/local_db.dart';
import 'core/offline/device_identity.dart';
import 'core/offline/offline_credentials.dart';
import 'core/offline/password_hasher.dart';
import 'core/offline/sync_api.dart';
import 'core/offline/sync_engine.dart';
import 'core/offline/trusted_clock.dart';
import 'core/platform/app_reloader.dart';
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
import 'features/cashier/data/cashier_repository_impl.dart';
import 'features/cashier/presentation/cashier_providers.dart';
import 'features/customers/data/customers_repository_impl.dart';
import 'features/customers/data/local_first_customers_repository.dart';
import 'features/customers/domain/customers_repository.dart';
import 'features/invoice/data/invoice_repository_impl.dart';
import 'features/invoice/domain/invoice_repository.dart';
import 'features/dashboard/data/dashboard_repository_impl.dart';
import 'features/dashboard/presentation/dashboard_providers.dart';
import 'features/inventory/data/inventory_repository_impl.dart';
import 'features/inventory/data/local_first_inventory_repository.dart';
import 'features/inventory/presentation/inventory_providers.dart';
import 'features/messages/data/messages_repository_impl.dart';
import 'features/messages/presentation/messages_providers.dart';
import 'features/notifications/data/notifications_repository_impl.dart';
import 'features/notifications/presentation/notifications_providers.dart';
import 'features/os/data/os_repository_impl.dart';
import 'features/os/presentation/os_providers.dart';
import 'features/report/data/report_repository_impl.dart';
import 'features/report/presentation/report_providers.dart';
import 'features/sale/data/sale_repository_impl.dart';
import 'features/sale/presentation/sale_providers.dart';
import 'features/team/data/team_repository_impl.dart';
import 'features/team/domain/team_repository.dart';
import 'features/settings/data/external_lookups_repository_impl.dart';
import 'features/settings/data/settings_repository_impl.dart';
import 'features/settings/domain/external_lookups_repository.dart';
import 'features/settings/domain/settings_models.dart';
import 'features/settings/domain/settings_repository.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/schedule/data/schedule_repository_impl.dart';
import 'features/schedule/presentation/schedule_providers.dart';
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

/// In-memory refresh token for the session (+ the "remember" persistence flag).
final refreshTokenStoreProvider =
    Provider<RefreshTokenStore>((ref) => RefreshTokenStore());

/// Bare dio with NO interceptors — used only by the refresh service so the
/// refresh call can never recurse into the 401 handler.
final bareDioProvider = Provider<Dio>((ref) => Dio(_baseOptions()));

final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  return TokenRefreshService(
    bareDio: ref.read(bareDioProvider),
    accessStore: ref.read(accessTokenStoreProvider),
    refreshStore: ref.read(refreshTokenStoreProvider),
    secureStore: ref.read(secureTokenStoreProvider),
  );
});

/// Hora do SERVIDOR (header `Date` das respostas) — base de `lastOnlineLoginAt`
/// no login offline (B6). O relógio do device não é confiável para isso.
final serverTimeStoreProvider = Provider<ServerTimeStore>(
  (ref) => ServerTimeStore(),
);

/// The app dio: attaches the bearer and does single-flight refresh-and-retry.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(ServerTimeInterceptor(ref.read(serverTimeStoreProvider)));
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

/// B8 — dependências comuns dos repositórios LocalFirst (decorators sobre a impl
/// dio). `null` na web ou sem sessão/tenant: os repos ficam online-only (a impl
/// dio pura), exatamente como antes do offline.
({
  LocalDb db,
  TrustedClock clock,
  bool Function() isOnline,
  String? Function() currentUserId,
  void Function() onWrite,
})? _localFirstDeps(Ref ref) {
  if (kIsWeb) return null;
  final db = ref.watch(localDbProvider);
  if (db == null) return null;
  return (
    db: db,
    clock: ref.read(trustedClockProvider),
    // `syncing` é uma rodada em andamento — a rede está lá; só `offline` desvia
    // para o caminho local.
    isOnline: () =>
        ref.read(connectivityControllerProvider).status != ConnStatus.offline,
    currentUserId: () => ref.read(sessionControllerProvider).meOrNull?.user.id,
    onWrite: () => ref.read(syncEngineProvider)?.nudge(),
  );
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  final inner = CustomersRepositoryImpl(ref.read(dioProvider));
  final deps = _localFirstDeps(ref);
  if (deps == null) return inner;
  return LocalFirstCustomersRepository(
    inner: inner,
    db: deps.db,
    clock: deps.clock,
    isOnline: deps.isOnline,
    currentUserId: deps.currentUserId,
    onWrite: deps.onWrite,
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
    (ref) => InvoiceRepositoryImpl(ref.read(dioProvider)));

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepositoryImpl(ref.read(dioProvider)));

/// Consultas a APIs públicas externas (IBGE CNAE, ViaCEP). Dio próprio, sem
/// bearer — a UI consome via este repo em vez de instanciar dio na tela.
final externalLookupsRepositoryProvider = Provider<ExternalLookupsRepository>(
    (ref) => ExternalLookupsRepositoryImpl());

/// Acompanhamento público: Dio LIMPO (sem bearer/refresh) — endpoints `@Public`.
final trackingRepositoryProvider =
    Provider<TrackingRepository>((ref) => TrackingRepositoryImpl());

/// Overrides do composition root — passados ao `ProviderScope` em main.dart.
/// O `inventoryRepositoryProvider` é declarado em `inventory_providers.dart`
/// (lança por padrão) e ganha a impl real (dio) aqui, espelhando os demais repos.
final diOverrides = [
  inventoryRepositoryProvider.overrideWith((ref) {
    final inner = InventoryRepositoryImpl(ref.read(dioProvider));
    final deps = _localFirstDeps(ref);
    if (deps == null) return inner;
    return LocalFirstInventoryRepository(
      inner: inner,
      db: deps.db,
      clock: deps.clock,
      isOnline: deps.isOnline,
      currentUserId: deps.currentUserId,
      onWrite: deps.onWrite,
    );
  }),
  cashierRepositoryProvider.overrideWith(
    (ref) => CashierRepositoryImpl(
      ref.read(dioProvider),
      () => ref.read(deviceIdProvider.future),
    ),
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
  reportRepositoryProvider.overrideWith(
    (ref) => ReportRepositoryImpl(ref.read(dioProvider)),
  ),
  scheduleRepositoryProvider.overrideWith(
    (ref) => ScheduleRepositoryImpl(ref.read(dioProvider)),
  ),
  saleRepositoryProvider.overrideWith(
    (ref) => SaleRepositoryImpl(ref.read(dioProvider)),
  ),
];

/// Reset total do app no logout/expire (reload na web, no-op fora).
final appReloaderProvider = Provider<AppReloader>((ref) => AppReloader());

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Aviso offline mostrado na tela de login (B6) — ex.: cold-start sem rede com
/// credencial offline disponível. `null` = sem aviso.
final offlineNoticeProvider =
    NotifierProvider<OfflineNotice, String?>(OfflineNotice.new);

/// S4 — hasher argon2id (64 MB / 3 iterações) do login offline.
final passwordHasherProvider =
    Provider<PasswordHasher>((ref) => const PasswordHasher());

/// B6 — credenciais offline DO DISPOSITIVO (`orbix_device.db`, cifrado): todos
/// os usuários que já logaram online aqui. `null` na web (online-only) — o que
/// desliga por completo o caminho de login offline.
final offlineCredentialsStoreProvider =
    Provider<OfflineCredentialsStore?>((ref) {
  if (kIsWeb) return null;
  final store = DriftOfflineCredentialsStore(DeviceDb.open());
  ref.onDispose(store.close);
  return store;
});

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsBundle>(
  SettingsController.new,
);

/// Offline-first (S1-S10): id estável do device (uuid v4 persistido), o
/// relógio confiável (S3, anti clock-rollback) e o indicador global de
/// conectividade/sync — usados pelo futuro outbox/SyncEngine (B3+).
final deviceIdProvider =
    FutureProvider<String>((ref) => const DeviceIdentity().getOrCreate());

/// Relógio confiável (S3). O carregamento do `max_seen_ts` persistido começa
/// aqui, mas é assíncrono: consumidores de segurança (B6, login offline)
/// DEVEM `await ref.read(trustedClockProvider).ready` antes de confiar em
/// `clockRolledBack` — antes disso um rollback real pode passar despercebido.
final trustedClockProvider = Provider<TrustedClock>((ref) {
  final clock = TrustedClock();
  // fire-and-forget: `ready` expõe este mesmo Future memoizado. O `catchError`
  // evita que uma falha de storage vire erro assíncrono não tratado — quem
  // depende do valor (`await ready` no login offline) trata a falha lá.
  clock.load().catchError((Object _) {});
  return clock;
});

final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, ConnState>(
  ConnectivityController.new,
);

/// Offline (B5): `LocalDb` do tenant ATIVO — arquivo cifrado por tenant, aberto
/// e cacheado sob demanda. `null` na web (online-only) ou quando não há sessão.
/// Vale para sessão ONLINE e OFFLINE (B6) — offline é justamente quando mais se
/// lê daqui. Observa o tenant ativo em `/me`: ao trocar de oficina, o provider
/// reabre o banco do novo tenant. Os repositórios LocalFirst (B8) leem o
/// `LocalDb` daqui — nunca abrem banco por conta própria.
final localDbProvider = Provider<LocalDb?>((ref) {
  if (kIsWeb) return null;
  final tenantId = ref.watch(
    sessionControllerProvider.select((s) => s.meOrNull?.activeTenant?.id),
  );
  if (tenantId == null) return null;
  return LocalDb.forTenant(tenantId);
});

/// B7 — motor de sincronização (push → fotos → pull) do tenant/usuário ativos.
/// `null` na web (online-only) ou sem sessão. Segue o ciclo de vida da sessão:
/// o provider é reconstruído quando o tenant ativo muda (via [localDbProvider])
/// e o engine anterior é parado no `onDispose`. Os repositórios LocalFirst (B8)
/// chamam `nudge()` depois de cada escrita local.
///
/// Precisa de alguém que o OBSERVE para existir — `OrbixApp` faz o `watch` na
/// raiz, de modo que o engine vive enquanto o app estiver de pé.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  if (kIsWeb) return null;
  final db = ref.watch(localDbProvider);
  if (db == null) return null;

  final engine = SyncEngine(
    api: DioSyncApi(ref.read(dioProvider)),
    db: db,
    conn: ref.read(connectivityControllerProvider.notifier),
    clock: ref.read(trustedClockProvider),
    uploadPhoto: ({
      required String orderId,
      required List<int> bytes,
      required String filename,
      required String contentType,
      String? caption,
    }) async {
      await ref.read(osRepositoryProvider).addPhoto(
            orderId,
            bytes: bytes,
            filename: filename,
            contentType: contentType,
            caption: caption,
          );
    },
    currentUserId: () =>
        ref.read(sessionControllerProvider).meOrNull?.user.id,
  );

  // Voltou a ficar online (ou terminou um sync) → tenta esvaziar a fila.
  ref.listen<ConnStatus>(
    connectivityControllerProvider.select((s) => s.status),
    (prev, next) {
      // SÓ na transição offline → online. `syncing → online` é o próprio engine
      // terminando uma rodada (markSynced) — realimentar aqui seria loop infinito.
      if (next == ConnStatus.online && prev == ConnStatus.offline) {
        engine.nudge();
      }
    },
  );

  ref.onDispose(() => unawaited(engine.stop()));
  engine.start();
  return engine;
});
