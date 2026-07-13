import 'package:drift/drift.dart';

// Mesma abertura por plataforma do banco por tenant (SQLCipher no nativo; stub
// que lança na web — offline é `!kIsWeb`).
import 'db/db_stub.dart' if (dart.library.io) 'db/db_native.dart' as platform;

part 'offline_credentials.g.dart';

/// Pseudo-"tenant" do banco DE DISPOSITIVO: gera o arquivo `orbix_device.db`,
/// irmão dos `orbix_<tenantId>.db`. As credenciais offline são POR DISPOSITIVO
/// (vários usuários, possivelmente de tenants diferentes, já logaram aqui) e
/// portanto NÃO podem morar dentro do banco de um tenant — que, aliás, é
/// apagado no S5.
const deviceDbName = 'device';

/// Credenciais offline gravadas neste dispositivo (uma por usuário que já logou
/// online aqui). Fica no banco cifrado do device — o hash argon2id nunca sai
/// daqui e a senha em claro nunca é gravada.
class OfflineCredentialRows extends Table {
  TextColumn get email => text()(); // normalizado (trim + lowercase)
  TextColumn get userId => text()();
  TextColumn get tenantId => text()(); // tenant ativo no último login online
  TextColumn get passwordHash => text()(); // argon2id (PHC encoded)
  TextColumn get meSnapshot => text()(); // json cru do /me
  DateTimeColumn get lastOnlineLoginAt => dateTime()(); // hora do SERVIDOR
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {email};
}

/// Banco de DISPOSITIVO (`orbix_device.db`), cifrado como os de tenant. Hoje só
/// guarda as credenciais offline.
@DriftDatabase(tables: [OfflineCredentialRows])
class DeviceDb extends _$DeviceDb {
  DeviceDb(super.executor);

  /// Abre (lazy) o arquivo cifrado `orbix_device.db`. Na web lança — não chame.
  factory DeviceDb.open() => DeviceDb(platform.openTenantExecutor(deviceDbName));

  @override
  int get schemaVersion => 1;

  /// Timestamps como texto ISO-8601 UTC (mesma escolha do `LocalDb`): o
  /// round-trip preserva o instante em UTC — crítico para a janela de 7 dias.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

/// Uma credencial offline (registro imutável).
class OfflineCredential {
  OfflineCredential({
    required String email,
    required this.userId,
    required this.tenantId,
    required this.passwordHash,
    required this.meSnapshot,
    required this.lastOnlineLoginAt,
    this.failedAttempts = 0,
    this.lockedUntil,
  }) : email = normalizeEmail(email);

  /// E-mail normalizado (chave primária).
  final String email;
  final String userId;

  /// Tenant ativo no último login online — é o banco local (réplica) que o S5
  /// apaga quando a membership some.
  final String tenantId;

  /// Hash argon2id (PHC encoded). NUNCA sai do dispositivo.
  final String passwordHash;

  /// JSON cru do `/me` do último login online (dirige a UI no modo offline).
  final String meSnapshot;

  /// Hora do SERVIDOR no último login online (base da janela de 7 dias).
  final DateTime lastOnlineLoginAt;

  /// Tentativas offline erradas consecutivas (zera no acerto/login online).
  final int failedAttempts;

  /// Enquanto no futuro, o login offline deste e-mail está bloqueado (backoff).
  final DateTime? lockedUntil;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  OfflineCredential copyWith({
    String? email,
    String? userId,
    String? tenantId,
    String? passwordHash,
    String? meSnapshot,
    DateTime? lastOnlineLoginAt,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
  }) {
    return OfflineCredential(
      email: email ?? this.email,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      passwordHash: passwordHash ?? this.passwordHash,
      meSnapshot: meSnapshot ?? this.meSnapshot,
      lastOnlineLoginAt: lastOnlineLoginAt ?? this.lastOnlineLoginAt,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
    );
  }
}

/// Credenciais offline do dispositivo. Implementação real: [DriftOfflineCredentialsStore]
/// (arquivo cifrado `orbix_device.db`). Os testes injetam uma implementação em
/// memória por este contrato.
abstract class OfflineCredentialsStore {
  /// Credencial deste e-mail (normalizado), ou `null`.
  Future<OfflineCredential?> find(String email);

  /// Todos os usuários que já logaram online neste dispositivo.
  Future<List<OfflineCredential>> list();

  /// Insere/atualiza (upsert por e-mail).
  Future<void> save(OfflineCredential credential);

  /// Remove a credencial (logout definitivo / S5 — membership revogada).
  Future<void> remove(String email);

  /// Fecha o banco subjacente (testes/shutdown).
  Future<void> close();
}

/// Implementação drift sobre o [DeviceDb] cifrado.
class DriftOfflineCredentialsStore implements OfflineCredentialsStore {
  DriftOfflineCredentialsStore(this._db);

  final DeviceDb _db;

  @override
  Future<OfflineCredential?> find(String email) async {
    final row = await (_db.select(_db.offlineCredentialRows)
          ..where((t) => t.email.equals(OfflineCredential.normalizeEmail(email))))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<OfflineCredential>> list() async {
    final rows = await _db.select(_db.offlineCredentialRows).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> save(OfflineCredential c) async {
    await _db.into(_db.offlineCredentialRows).insertOnConflictUpdate(
          OfflineCredentialRowsCompanion.insert(
            email: c.email,
            userId: c.userId,
            tenantId: c.tenantId,
            passwordHash: c.passwordHash,
            meSnapshot: c.meSnapshot,
            lastOnlineLoginAt: c.lastOnlineLoginAt,
            failedAttempts: Value(c.failedAttempts),
            lockedUntil: Value(c.lockedUntil),
          ),
        );
  }

  @override
  Future<void> remove(String email) async {
    await (_db.delete(_db.offlineCredentialRows)
          ..where((t) => t.email.equals(OfflineCredential.normalizeEmail(email))))
        .go();
  }

  @override
  Future<void> close() => _db.close();

  OfflineCredential _toDomain(OfflineCredentialRow r) => OfflineCredential(
        email: r.email,
        userId: r.userId,
        tenantId: r.tenantId,
        passwordHash: r.passwordHash,
        meSnapshot: r.meSnapshot,
        lastOnlineLoginAt: r.lastOnlineLoginAt,
        failedAttempts: r.failedAttempts,
        lockedUntil: r.lockedUntil,
      );
}
