// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_credentials.dart';

// ignore_for_file: type=lint
class $OfflineCredentialRowsTable extends OfflineCredentialRows
    with TableInfo<$OfflineCredentialRowsTable, OfflineCredentialRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineCredentialRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meSnapshotMeta = const VerificationMeta(
    'meSnapshot',
  );
  @override
  late final GeneratedColumn<String> meSnapshot = GeneratedColumn<String>(
    'me_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOnlineLoginAtMeta = const VerificationMeta(
    'lastOnlineLoginAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOnlineLoginAt =
      GeneratedColumn<DateTime>(
        'last_online_login_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta(
    'lockedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> lockedUntil = GeneratedColumn<DateTime>(
    'locked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    email,
    userId,
    tenantId,
    passwordHash,
    meSnapshot,
    lastOnlineLoginAt,
    failedAttempts,
    lockedUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_credential_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineCredentialRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('me_snapshot')) {
      context.handle(
        _meSnapshotMeta,
        meSnapshot.isAcceptableOrUnknown(data['me_snapshot']!, _meSnapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_meSnapshotMeta);
    }
    if (data.containsKey('last_online_login_at')) {
      context.handle(
        _lastOnlineLoginAtMeta,
        lastOnlineLoginAt.isAcceptableOrUnknown(
          data['last_online_login_at']!,
          _lastOnlineLoginAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOnlineLoginAtMeta);
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(
        _lockedUntilMeta,
        lockedUntil.isAcceptableOrUnknown(
          data['locked_until']!,
          _lockedUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {email};
  @override
  OfflineCredentialRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineCredentialRow(
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      meSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}me_snapshot'],
      )!,
      lastOnlineLoginAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_online_login_at'],
      )!,
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_until'],
      ),
    );
  }

  @override
  $OfflineCredentialRowsTable createAlias(String alias) {
    return $OfflineCredentialRowsTable(attachedDatabase, alias);
  }
}

class OfflineCredentialRow extends DataClass
    implements Insertable<OfflineCredentialRow> {
  final String email;
  final String userId;
  final String tenantId;
  final String passwordHash;
  final String meSnapshot;
  final DateTime lastOnlineLoginAt;
  final int failedAttempts;
  final DateTime? lockedUntil;
  const OfflineCredentialRow({
    required this.email,
    required this.userId,
    required this.tenantId,
    required this.passwordHash,
    required this.meSnapshot,
    required this.lastOnlineLoginAt,
    required this.failedAttempts,
    this.lockedUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['email'] = Variable<String>(email);
    map['user_id'] = Variable<String>(userId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['password_hash'] = Variable<String>(passwordHash);
    map['me_snapshot'] = Variable<String>(meSnapshot);
    map['last_online_login_at'] = Variable<DateTime>(lastOnlineLoginAt);
    map['failed_attempts'] = Variable<int>(failedAttempts);
    if (!nullToAbsent || lockedUntil != null) {
      map['locked_until'] = Variable<DateTime>(lockedUntil);
    }
    return map;
  }

  OfflineCredentialRowsCompanion toCompanion(bool nullToAbsent) {
    return OfflineCredentialRowsCompanion(
      email: Value(email),
      userId: Value(userId),
      tenantId: Value(tenantId),
      passwordHash: Value(passwordHash),
      meSnapshot: Value(meSnapshot),
      lastOnlineLoginAt: Value(lastOnlineLoginAt),
      failedAttempts: Value(failedAttempts),
      lockedUntil: lockedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedUntil),
    );
  }

  factory OfflineCredentialRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineCredentialRow(
      email: serializer.fromJson<String>(json['email']),
      userId: serializer.fromJson<String>(json['userId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      meSnapshot: serializer.fromJson<String>(json['meSnapshot']),
      lastOnlineLoginAt: serializer.fromJson<DateTime>(
        json['lastOnlineLoginAt'],
      ),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      lockedUntil: serializer.fromJson<DateTime?>(json['lockedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'email': serializer.toJson<String>(email),
      'userId': serializer.toJson<String>(userId),
      'tenantId': serializer.toJson<String>(tenantId),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'meSnapshot': serializer.toJson<String>(meSnapshot),
      'lastOnlineLoginAt': serializer.toJson<DateTime>(lastOnlineLoginAt),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'lockedUntil': serializer.toJson<DateTime?>(lockedUntil),
    };
  }

  OfflineCredentialRow copyWith({
    String? email,
    String? userId,
    String? tenantId,
    String? passwordHash,
    String? meSnapshot,
    DateTime? lastOnlineLoginAt,
    int? failedAttempts,
    Value<DateTime?> lockedUntil = const Value.absent(),
  }) => OfflineCredentialRow(
    email: email ?? this.email,
    userId: userId ?? this.userId,
    tenantId: tenantId ?? this.tenantId,
    passwordHash: passwordHash ?? this.passwordHash,
    meSnapshot: meSnapshot ?? this.meSnapshot,
    lastOnlineLoginAt: lastOnlineLoginAt ?? this.lastOnlineLoginAt,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil.present ? lockedUntil.value : this.lockedUntil,
  );
  OfflineCredentialRow copyWithCompanion(OfflineCredentialRowsCompanion data) {
    return OfflineCredentialRow(
      email: data.email.present ? data.email.value : this.email,
      userId: data.userId.present ? data.userId.value : this.userId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      meSnapshot: data.meSnapshot.present
          ? data.meSnapshot.value
          : this.meSnapshot,
      lastOnlineLoginAt: data.lastOnlineLoginAt.present
          ? data.lastOnlineLoginAt.value
          : this.lastOnlineLoginAt,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      lockedUntil: data.lockedUntil.present
          ? data.lockedUntil.value
          : this.lockedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineCredentialRow(')
          ..write('email: $email, ')
          ..write('userId: $userId, ')
          ..write('tenantId: $tenantId, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('meSnapshot: $meSnapshot, ')
          ..write('lastOnlineLoginAt: $lastOnlineLoginAt, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    email,
    userId,
    tenantId,
    passwordHash,
    meSnapshot,
    lastOnlineLoginAt,
    failedAttempts,
    lockedUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineCredentialRow &&
          other.email == this.email &&
          other.userId == this.userId &&
          other.tenantId == this.tenantId &&
          other.passwordHash == this.passwordHash &&
          other.meSnapshot == this.meSnapshot &&
          other.lastOnlineLoginAt == this.lastOnlineLoginAt &&
          other.failedAttempts == this.failedAttempts &&
          other.lockedUntil == this.lockedUntil);
}

class OfflineCredentialRowsCompanion
    extends UpdateCompanion<OfflineCredentialRow> {
  final Value<String> email;
  final Value<String> userId;
  final Value<String> tenantId;
  final Value<String> passwordHash;
  final Value<String> meSnapshot;
  final Value<DateTime> lastOnlineLoginAt;
  final Value<int> failedAttempts;
  final Value<DateTime?> lockedUntil;
  final Value<int> rowid;
  const OfflineCredentialRowsCompanion({
    this.email = const Value.absent(),
    this.userId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.meSnapshot = const Value.absent(),
    this.lastOnlineLoginAt = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineCredentialRowsCompanion.insert({
    required String email,
    required String userId,
    required String tenantId,
    required String passwordHash,
    required String meSnapshot,
    required DateTime lastOnlineLoginAt,
    this.failedAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : email = Value(email),
       userId = Value(userId),
       tenantId = Value(tenantId),
       passwordHash = Value(passwordHash),
       meSnapshot = Value(meSnapshot),
       lastOnlineLoginAt = Value(lastOnlineLoginAt);
  static Insertable<OfflineCredentialRow> custom({
    Expression<String>? email,
    Expression<String>? userId,
    Expression<String>? tenantId,
    Expression<String>? passwordHash,
    Expression<String>? meSnapshot,
    Expression<DateTime>? lastOnlineLoginAt,
    Expression<int>? failedAttempts,
    Expression<DateTime>? lockedUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (email != null) 'email': email,
      if (userId != null) 'user_id': userId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (meSnapshot != null) 'me_snapshot': meSnapshot,
      if (lastOnlineLoginAt != null) 'last_online_login_at': lastOnlineLoginAt,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineCredentialRowsCompanion copyWith({
    Value<String>? email,
    Value<String>? userId,
    Value<String>? tenantId,
    Value<String>? passwordHash,
    Value<String>? meSnapshot,
    Value<DateTime>? lastOnlineLoginAt,
    Value<int>? failedAttempts,
    Value<DateTime?>? lockedUntil,
    Value<int>? rowid,
  }) {
    return OfflineCredentialRowsCompanion(
      email: email ?? this.email,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      passwordHash: passwordHash ?? this.passwordHash,
      meSnapshot: meSnapshot ?? this.meSnapshot,
      lastOnlineLoginAt: lastOnlineLoginAt ?? this.lastOnlineLoginAt,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (meSnapshot.present) {
      map['me_snapshot'] = Variable<String>(meSnapshot.value);
    }
    if (lastOnlineLoginAt.present) {
      map['last_online_login_at'] = Variable<DateTime>(lastOnlineLoginAt.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<DateTime>(lockedUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineCredentialRowsCompanion(')
          ..write('email: $email, ')
          ..write('userId: $userId, ')
          ..write('tenantId: $tenantId, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('meSnapshot: $meSnapshot, ')
          ..write('lastOnlineLoginAt: $lastOnlineLoginAt, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DeviceDb extends GeneratedDatabase {
  _$DeviceDb(QueryExecutor e) : super(e);
  $DeviceDbManager get managers => $DeviceDbManager(this);
  late final $OfflineCredentialRowsTable offlineCredentialRows =
      $OfflineCredentialRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [offlineCredentialRows];
}

typedef $$OfflineCredentialRowsTableCreateCompanionBuilder =
    OfflineCredentialRowsCompanion Function({
      required String email,
      required String userId,
      required String tenantId,
      required String passwordHash,
      required String meSnapshot,
      required DateTime lastOnlineLoginAt,
      Value<int> failedAttempts,
      Value<DateTime?> lockedUntil,
      Value<int> rowid,
    });
typedef $$OfflineCredentialRowsTableUpdateCompanionBuilder =
    OfflineCredentialRowsCompanion Function({
      Value<String> email,
      Value<String> userId,
      Value<String> tenantId,
      Value<String> passwordHash,
      Value<String> meSnapshot,
      Value<DateTime> lastOnlineLoginAt,
      Value<int> failedAttempts,
      Value<DateTime?> lockedUntil,
      Value<int> rowid,
    });

class $$OfflineCredentialRowsTableFilterComposer
    extends Composer<_$DeviceDb, $OfflineCredentialRowsTable> {
  $$OfflineCredentialRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meSnapshot => $composableBuilder(
    column: $table.meSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOnlineLoginAt => $composableBuilder(
    column: $table.lastOnlineLoginAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineCredentialRowsTableOrderingComposer
    extends Composer<_$DeviceDb, $OfflineCredentialRowsTable> {
  $$OfflineCredentialRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meSnapshot => $composableBuilder(
    column: $table.meSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOnlineLoginAt => $composableBuilder(
    column: $table.lastOnlineLoginAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineCredentialRowsTableAnnotationComposer
    extends Composer<_$DeviceDb, $OfflineCredentialRowsTable> {
  $$OfflineCredentialRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meSnapshot => $composableBuilder(
    column: $table.meSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOnlineLoginAt => $composableBuilder(
    column: $table.lastOnlineLoginAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lockedUntil => $composableBuilder(
    column: $table.lockedUntil,
    builder: (column) => column,
  );
}

class $$OfflineCredentialRowsTableTableManager
    extends
        RootTableManager<
          _$DeviceDb,
          $OfflineCredentialRowsTable,
          OfflineCredentialRow,
          $$OfflineCredentialRowsTableFilterComposer,
          $$OfflineCredentialRowsTableOrderingComposer,
          $$OfflineCredentialRowsTableAnnotationComposer,
          $$OfflineCredentialRowsTableCreateCompanionBuilder,
          $$OfflineCredentialRowsTableUpdateCompanionBuilder,
          (
            OfflineCredentialRow,
            BaseReferences<
              _$DeviceDb,
              $OfflineCredentialRowsTable,
              OfflineCredentialRow
            >,
          ),
          OfflineCredentialRow,
          PrefetchHooks Function()
        > {
  $$OfflineCredentialRowsTableTableManager(
    _$DeviceDb db,
    $OfflineCredentialRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineCredentialRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineCredentialRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineCredentialRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> email = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String> meSnapshot = const Value.absent(),
                Value<DateTime> lastOnlineLoginAt = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineCredentialRowsCompanion(
                email: email,
                userId: userId,
                tenantId: tenantId,
                passwordHash: passwordHash,
                meSnapshot: meSnapshot,
                lastOnlineLoginAt: lastOnlineLoginAt,
                failedAttempts: failedAttempts,
                lockedUntil: lockedUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String email,
                required String userId,
                required String tenantId,
                required String passwordHash,
                required String meSnapshot,
                required DateTime lastOnlineLoginAt,
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineCredentialRowsCompanion.insert(
                email: email,
                userId: userId,
                tenantId: tenantId,
                passwordHash: passwordHash,
                meSnapshot: meSnapshot,
                lastOnlineLoginAt: lastOnlineLoginAt,
                failedAttempts: failedAttempts,
                lockedUntil: lockedUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineCredentialRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDb,
      $OfflineCredentialRowsTable,
      OfflineCredentialRow,
      $$OfflineCredentialRowsTableFilterComposer,
      $$OfflineCredentialRowsTableOrderingComposer,
      $$OfflineCredentialRowsTableAnnotationComposer,
      $$OfflineCredentialRowsTableCreateCompanionBuilder,
      $$OfflineCredentialRowsTableUpdateCompanionBuilder,
      (
        OfflineCredentialRow,
        BaseReferences<
          _$DeviceDb,
          $OfflineCredentialRowsTable,
          OfflineCredentialRow
        >,
      ),
      OfflineCredentialRow,
      PrefetchHooks Function()
    >;

class $DeviceDbManager {
  final _$DeviceDb _db;
  $DeviceDbManager(this._db);
  $$OfflineCredentialRowsTableTableManager get offlineCredentialRows =>
      $$OfflineCredentialRowsTableTableManager(_db, _db.offlineCredentialRows);
}
