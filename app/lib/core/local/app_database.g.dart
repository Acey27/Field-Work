// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkerCacheTable extends WorkerCache
    with TableInfo<$WorkerCacheTable, WorkerCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkerCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _qrCheckMeta = const VerificationMeta(
    'qrCheck',
  );
  @override
  late final GeneratedColumn<String> qrCheck = GeneratedColumn<String>(
    'qr_check',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, active, qrCheck, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worker_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkerCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    if (data.containsKey('qr_check')) {
      context.handle(
        _qrCheckMeta,
        qrCheck.isAcceptableOrUnknown(data['qr_check']!, _qrCheckMeta),
      );
    } else if (isInserting) {
      context.missing(_qrCheckMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkerCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkerCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      qrCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_check'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WorkerCacheTable createAlias(String alias) {
    return $WorkerCacheTable(attachedDatabase, alias);
  }
}

class WorkerCacheData extends DataClass implements Insertable<WorkerCacheData> {
  final String id;
  final String name;
  final bool active;
  final String qrCheck;
  final DateTime updatedAt;
  const WorkerCacheData({
    required this.id,
    required this.name,
    required this.active,
    required this.qrCheck,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['active'] = Variable<bool>(active);
    map['qr_check'] = Variable<String>(qrCheck);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkerCacheCompanion toCompanion(bool nullToAbsent) {
    return WorkerCacheCompanion(
      id: Value(id),
      name: Value(name),
      active: Value(active),
      qrCheck: Value(qrCheck),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkerCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkerCacheData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      active: serializer.fromJson<bool>(json['active']),
      qrCheck: serializer.fromJson<String>(json['qrCheck']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'active': serializer.toJson<bool>(active),
      'qrCheck': serializer.toJson<String>(qrCheck),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkerCacheData copyWith({
    String? id,
    String? name,
    bool? active,
    String? qrCheck,
    DateTime? updatedAt,
  }) => WorkerCacheData(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
    qrCheck: qrCheck ?? this.qrCheck,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkerCacheData copyWithCompanion(WorkerCacheCompanion data) {
    return WorkerCacheData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      active: data.active.present ? data.active.value : this.active,
      qrCheck: data.qrCheck.present ? data.qrCheck.value : this.qrCheck,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkerCacheData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('qrCheck: $qrCheck, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, active, qrCheck, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkerCacheData &&
          other.id == this.id &&
          other.name == this.name &&
          other.active == this.active &&
          other.qrCheck == this.qrCheck &&
          other.updatedAt == this.updatedAt);
}

class WorkerCacheCompanion extends UpdateCompanion<WorkerCacheData> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> active;
  final Value<String> qrCheck;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkerCacheCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.active = const Value.absent(),
    this.qrCheck = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkerCacheCompanion.insert({
    required String id,
    required String name,
    required bool active,
    required String qrCheck,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       active = Value(active),
       qrCheck = Value(qrCheck),
       updatedAt = Value(updatedAt);
  static Insertable<WorkerCacheData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? active,
    Expression<String>? qrCheck,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (active != null) 'active': active,
      if (qrCheck != null) 'qr_check': qrCheck,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkerCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? active,
    Value<String>? qrCheck,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkerCacheCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      qrCheck: qrCheck ?? this.qrCheck,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (qrCheck.present) {
      map['qr_check'] = Variable<String>(qrCheck.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkerCacheCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('qrCheck: $qrCheck, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalScansTable extends LocalScans
    with TableInfo<$LocalScansTable, LocalScan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workerIdMeta = const VerificationMeta(
    'workerId',
  );
  @override
  late final GeneratedColumn<String> workerId = GeneratedColumn<String>(
    'worker_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qrCheckMeta = const VerificationMeta(
    'qrCheck',
  );
  @override
  late final GeneratedColumn<String> qrCheck = GeneratedColumn<String>(
    'qr_check',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _technicianIdMeta = const VerificationMeta(
    'technicianId',
  );
  @override
  late final GeneratedColumn<String> technicianId = GeneratedColumn<String>(
    'technician_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldIdMeta = const VerificationMeta(
    'fieldId',
  );
  @override
  late final GeneratedColumn<String> fieldId = GeneratedColumn<String>(
    'field_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta(
    'scannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverResultMeta = const VerificationMeta(
    'serverResult',
  );
  @override
  late final GeneratedColumn<String> serverResult = GeneratedColumn<String>(
    'server_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverErrorMeta = const VerificationMeta(
    'serverError',
  );
  @override
  late final GeneratedColumn<String> serverError = GeneratedColumn<String>(
    'server_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> uploadedAt = GeneratedColumn<DateTime>(
    'uploaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scanId,
    workerId,
    qrCheck,
    technicianId,
    fieldId,
    scannedAt,
    lat,
    lng,
    uploadState,
    attempts,
    serverResult,
    serverError,
    uploadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalScan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('worker_id')) {
      context.handle(
        _workerIdMeta,
        workerId.isAcceptableOrUnknown(data['worker_id']!, _workerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workerIdMeta);
    }
    if (data.containsKey('qr_check')) {
      context.handle(
        _qrCheckMeta,
        qrCheck.isAcceptableOrUnknown(data['qr_check']!, _qrCheckMeta),
      );
    } else if (isInserting) {
      context.missing(_qrCheckMeta);
    }
    if (data.containsKey('technician_id')) {
      context.handle(
        _technicianIdMeta,
        technicianId.isAcceptableOrUnknown(
          data['technician_id']!,
          _technicianIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_technicianIdMeta);
    }
    if (data.containsKey('field_id')) {
      context.handle(
        _fieldIdMeta,
        fieldId.isAcceptableOrUnknown(data['field_id']!, _fieldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldIdMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(
        _scannedAtMeta,
        scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_scannedAtMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('server_result')) {
      context.handle(
        _serverResultMeta,
        serverResult.isAcceptableOrUnknown(
          data['server_result']!,
          _serverResultMeta,
        ),
      );
    }
    if (data.containsKey('server_error')) {
      context.handle(
        _serverErrorMeta,
        serverError.isAcceptableOrUnknown(
          data['server_error']!,
          _serverErrorMeta,
        ),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scanId};
  @override
  LocalScan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalScan(
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      workerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worker_id'],
      )!,
      qrCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_check'],
      )!,
      technicianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}technician_id'],
      )!,
      fieldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_id'],
      )!,
      scannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scanned_at'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      serverResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_result'],
      ),
      serverError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_error'],
      ),
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}uploaded_at'],
      ),
    );
  }

  @override
  $LocalScansTable createAlias(String alias) {
    return $LocalScansTable(attachedDatabase, alias);
  }
}

class LocalScan extends DataClass implements Insertable<LocalScan> {
  final String scanId;
  final String workerId;
  final String qrCheck;
  final String technicianId;
  final String fieldId;
  final DateTime scannedAt;
  final double? lat;
  final double? lng;
  final String uploadState;
  final int attempts;
  final String? serverResult;
  final String? serverError;
  final DateTime? uploadedAt;
  const LocalScan({
    required this.scanId,
    required this.workerId,
    required this.qrCheck,
    required this.technicianId,
    required this.fieldId,
    required this.scannedAt,
    this.lat,
    this.lng,
    required this.uploadState,
    required this.attempts,
    this.serverResult,
    this.serverError,
    this.uploadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scan_id'] = Variable<String>(scanId);
    map['worker_id'] = Variable<String>(workerId);
    map['qr_check'] = Variable<String>(qrCheck);
    map['technician_id'] = Variable<String>(technicianId);
    map['field_id'] = Variable<String>(fieldId);
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    map['upload_state'] = Variable<String>(uploadState);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || serverResult != null) {
      map['server_result'] = Variable<String>(serverResult);
    }
    if (!nullToAbsent || serverError != null) {
      map['server_error'] = Variable<String>(serverError);
    }
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt);
    }
    return map;
  }

  LocalScansCompanion toCompanion(bool nullToAbsent) {
    return LocalScansCompanion(
      scanId: Value(scanId),
      workerId: Value(workerId),
      qrCheck: Value(qrCheck),
      technicianId: Value(technicianId),
      fieldId: Value(fieldId),
      scannedAt: Value(scannedAt),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      uploadState: Value(uploadState),
      attempts: Value(attempts),
      serverResult: serverResult == null && nullToAbsent
          ? const Value.absent()
          : Value(serverResult),
      serverError: serverError == null && nullToAbsent
          ? const Value.absent()
          : Value(serverError),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
    );
  }

  factory LocalScan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalScan(
      scanId: serializer.fromJson<String>(json['scanId']),
      workerId: serializer.fromJson<String>(json['workerId']),
      qrCheck: serializer.fromJson<String>(json['qrCheck']),
      technicianId: serializer.fromJson<String>(json['technicianId']),
      fieldId: serializer.fromJson<String>(json['fieldId']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      attempts: serializer.fromJson<int>(json['attempts']),
      serverResult: serializer.fromJson<String?>(json['serverResult']),
      serverError: serializer.fromJson<String?>(json['serverError']),
      uploadedAt: serializer.fromJson<DateTime?>(json['uploadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scanId': serializer.toJson<String>(scanId),
      'workerId': serializer.toJson<String>(workerId),
      'qrCheck': serializer.toJson<String>(qrCheck),
      'technicianId': serializer.toJson<String>(technicianId),
      'fieldId': serializer.toJson<String>(fieldId),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'uploadState': serializer.toJson<String>(uploadState),
      'attempts': serializer.toJson<int>(attempts),
      'serverResult': serializer.toJson<String?>(serverResult),
      'serverError': serializer.toJson<String?>(serverError),
      'uploadedAt': serializer.toJson<DateTime?>(uploadedAt),
    };
  }

  LocalScan copyWith({
    String? scanId,
    String? workerId,
    String? qrCheck,
    String? technicianId,
    String? fieldId,
    DateTime? scannedAt,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    String? uploadState,
    int? attempts,
    Value<String?> serverResult = const Value.absent(),
    Value<String?> serverError = const Value.absent(),
    Value<DateTime?> uploadedAt = const Value.absent(),
  }) => LocalScan(
    scanId: scanId ?? this.scanId,
    workerId: workerId ?? this.workerId,
    qrCheck: qrCheck ?? this.qrCheck,
    technicianId: technicianId ?? this.technicianId,
    fieldId: fieldId ?? this.fieldId,
    scannedAt: scannedAt ?? this.scannedAt,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    uploadState: uploadState ?? this.uploadState,
    attempts: attempts ?? this.attempts,
    serverResult: serverResult.present ? serverResult.value : this.serverResult,
    serverError: serverError.present ? serverError.value : this.serverError,
    uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
  );
  LocalScan copyWithCompanion(LocalScansCompanion data) {
    return LocalScan(
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      workerId: data.workerId.present ? data.workerId.value : this.workerId,
      qrCheck: data.qrCheck.present ? data.qrCheck.value : this.qrCheck,
      technicianId: data.technicianId.present
          ? data.technicianId.value
          : this.technicianId,
      fieldId: data.fieldId.present ? data.fieldId.value : this.fieldId,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      serverResult: data.serverResult.present
          ? data.serverResult.value
          : this.serverResult,
      serverError: data.serverError.present
          ? data.serverError.value
          : this.serverError,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalScan(')
          ..write('scanId: $scanId, ')
          ..write('workerId: $workerId, ')
          ..write('qrCheck: $qrCheck, ')
          ..write('technicianId: $technicianId, ')
          ..write('fieldId: $fieldId, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('uploadState: $uploadState, ')
          ..write('attempts: $attempts, ')
          ..write('serverResult: $serverResult, ')
          ..write('serverError: $serverError, ')
          ..write('uploadedAt: $uploadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scanId,
    workerId,
    qrCheck,
    technicianId,
    fieldId,
    scannedAt,
    lat,
    lng,
    uploadState,
    attempts,
    serverResult,
    serverError,
    uploadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalScan &&
          other.scanId == this.scanId &&
          other.workerId == this.workerId &&
          other.qrCheck == this.qrCheck &&
          other.technicianId == this.technicianId &&
          other.fieldId == this.fieldId &&
          other.scannedAt == this.scannedAt &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.uploadState == this.uploadState &&
          other.attempts == this.attempts &&
          other.serverResult == this.serverResult &&
          other.serverError == this.serverError &&
          other.uploadedAt == this.uploadedAt);
}

class LocalScansCompanion extends UpdateCompanion<LocalScan> {
  final Value<String> scanId;
  final Value<String> workerId;
  final Value<String> qrCheck;
  final Value<String> technicianId;
  final Value<String> fieldId;
  final Value<DateTime> scannedAt;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String> uploadState;
  final Value<int> attempts;
  final Value<String?> serverResult;
  final Value<String?> serverError;
  final Value<DateTime?> uploadedAt;
  final Value<int> rowid;
  const LocalScansCompanion({
    this.scanId = const Value.absent(),
    this.workerId = const Value.absent(),
    this.qrCheck = const Value.absent(),
    this.technicianId = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.serverResult = const Value.absent(),
    this.serverError = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalScansCompanion.insert({
    required String scanId,
    required String workerId,
    required String qrCheck,
    required String technicianId,
    required String fieldId,
    required DateTime scannedAt,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.serverResult = const Value.absent(),
    this.serverError = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scanId = Value(scanId),
       workerId = Value(workerId),
       qrCheck = Value(qrCheck),
       technicianId = Value(technicianId),
       fieldId = Value(fieldId),
       scannedAt = Value(scannedAt);
  static Insertable<LocalScan> custom({
    Expression<String>? scanId,
    Expression<String>? workerId,
    Expression<String>? qrCheck,
    Expression<String>? technicianId,
    Expression<String>? fieldId,
    Expression<DateTime>? scannedAt,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? uploadState,
    Expression<int>? attempts,
    Expression<String>? serverResult,
    Expression<String>? serverError,
    Expression<DateTime>? uploadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scanId != null) 'scan_id': scanId,
      if (workerId != null) 'worker_id': workerId,
      if (qrCheck != null) 'qr_check': qrCheck,
      if (technicianId != null) 'technician_id': technicianId,
      if (fieldId != null) 'field_id': fieldId,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (uploadState != null) 'upload_state': uploadState,
      if (attempts != null) 'attempts': attempts,
      if (serverResult != null) 'server_result': serverResult,
      if (serverError != null) 'server_error': serverError,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalScansCompanion copyWith({
    Value<String>? scanId,
    Value<String>? workerId,
    Value<String>? qrCheck,
    Value<String>? technicianId,
    Value<String>? fieldId,
    Value<DateTime>? scannedAt,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<String>? uploadState,
    Value<int>? attempts,
    Value<String?>? serverResult,
    Value<String?>? serverError,
    Value<DateTime?>? uploadedAt,
    Value<int>? rowid,
  }) {
    return LocalScansCompanion(
      scanId: scanId ?? this.scanId,
      workerId: workerId ?? this.workerId,
      qrCheck: qrCheck ?? this.qrCheck,
      technicianId: technicianId ?? this.technicianId,
      fieldId: fieldId ?? this.fieldId,
      scannedAt: scannedAt ?? this.scannedAt,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      uploadState: uploadState ?? this.uploadState,
      attempts: attempts ?? this.attempts,
      serverResult: serverResult ?? this.serverResult,
      serverError: serverError ?? this.serverError,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (workerId.present) {
      map['worker_id'] = Variable<String>(workerId.value);
    }
    if (qrCheck.present) {
      map['qr_check'] = Variable<String>(qrCheck.value);
    }
    if (technicianId.present) {
      map['technician_id'] = Variable<String>(technicianId.value);
    }
    if (fieldId.present) {
      map['field_id'] = Variable<String>(fieldId.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (serverResult.present) {
      map['server_result'] = Variable<String>(serverResult.value);
    }
    if (serverError.present) {
      map['server_error'] = Variable<String>(serverError.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalScansCompanion(')
          ..write('scanId: $scanId, ')
          ..write('workerId: $workerId, ')
          ..write('qrCheck: $qrCheck, ')
          ..write('technicianId: $technicianId, ')
          ..write('fieldId: $fieldId, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('uploadState: $uploadState, ')
          ..write('attempts: $attempts, ')
          ..write('serverResult: $serverResult, ')
          ..write('serverError: $serverError, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _technicianIdMeta = const VerificationMeta(
    'technicianId',
  );
  @override
  late final GeneratedColumn<String> technicianId = GeneratedColumn<String>(
    'technician_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldIdMeta = const VerificationMeta(
    'fieldId',
  );
  @override
  late final GeneratedColumn<String> fieldId = GeneratedColumn<String>(
    'field_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverResultMeta = const VerificationMeta(
    'serverResult',
  );
  @override
  late final GeneratedColumn<String> serverResult = GeneratedColumn<String>(
    'server_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverErrorMeta = const VerificationMeta(
    'serverError',
  );
  @override
  late final GeneratedColumn<String> serverError = GeneratedColumn<String>(
    'server_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> uploadedAt = GeneratedColumn<DateTime>(
    'uploaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    eventType,
    technicianId,
    fieldId,
    endedAt,
    uploadState,
    attempts,
    serverResult,
    serverError,
    uploadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('technician_id')) {
      context.handle(
        _technicianIdMeta,
        technicianId.isAcceptableOrUnknown(
          data['technician_id']!,
          _technicianIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_technicianIdMeta);
    }
    if (data.containsKey('field_id')) {
      context.handle(
        _fieldIdMeta,
        fieldId.isAcceptableOrUnknown(data['field_id']!, _fieldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldIdMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('server_result')) {
      context.handle(
        _serverResultMeta,
        serverResult.isAcceptableOrUnknown(
          data['server_result']!,
          _serverResultMeta,
        ),
      );
    }
    if (data.containsKey('server_error')) {
      context.handle(
        _serverErrorMeta,
        serverError.isAcceptableOrUnknown(
          data['server_error']!,
          _serverErrorMeta,
        ),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      technicianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}technician_id'],
      )!,
      fieldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_id'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      serverResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_result'],
      ),
      serverError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_error'],
      ),
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}uploaded_at'],
      ),
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final String eventId;
  final String eventType;
  final String technicianId;
  final String fieldId;
  final DateTime endedAt;
  final String uploadState;
  final int attempts;
  final String? serverResult;
  final String? serverError;
  final DateTime? uploadedAt;
  const LocalEvent({
    required this.eventId,
    required this.eventType,
    required this.technicianId,
    required this.fieldId,
    required this.endedAt,
    required this.uploadState,
    required this.attempts,
    this.serverResult,
    this.serverError,
    this.uploadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['event_type'] = Variable<String>(eventType);
    map['technician_id'] = Variable<String>(technicianId);
    map['field_id'] = Variable<String>(fieldId);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['upload_state'] = Variable<String>(uploadState);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || serverResult != null) {
      map['server_result'] = Variable<String>(serverResult);
    }
    if (!nullToAbsent || serverError != null) {
      map['server_error'] = Variable<String>(serverError);
    }
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt);
    }
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      eventId: Value(eventId),
      eventType: Value(eventType),
      technicianId: Value(technicianId),
      fieldId: Value(fieldId),
      endedAt: Value(endedAt),
      uploadState: Value(uploadState),
      attempts: Value(attempts),
      serverResult: serverResult == null && nullToAbsent
          ? const Value.absent()
          : Value(serverResult),
      serverError: serverError == null && nullToAbsent
          ? const Value.absent()
          : Value(serverError),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
    );
  }

  factory LocalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      technicianId: serializer.fromJson<String>(json['technicianId']),
      fieldId: serializer.fromJson<String>(json['fieldId']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      attempts: serializer.fromJson<int>(json['attempts']),
      serverResult: serializer.fromJson<String?>(json['serverResult']),
      serverError: serializer.fromJson<String?>(json['serverError']),
      uploadedAt: serializer.fromJson<DateTime?>(json['uploadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'eventType': serializer.toJson<String>(eventType),
      'technicianId': serializer.toJson<String>(technicianId),
      'fieldId': serializer.toJson<String>(fieldId),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'uploadState': serializer.toJson<String>(uploadState),
      'attempts': serializer.toJson<int>(attempts),
      'serverResult': serializer.toJson<String?>(serverResult),
      'serverError': serializer.toJson<String?>(serverError),
      'uploadedAt': serializer.toJson<DateTime?>(uploadedAt),
    };
  }

  LocalEvent copyWith({
    String? eventId,
    String? eventType,
    String? technicianId,
    String? fieldId,
    DateTime? endedAt,
    String? uploadState,
    int? attempts,
    Value<String?> serverResult = const Value.absent(),
    Value<String?> serverError = const Value.absent(),
    Value<DateTime?> uploadedAt = const Value.absent(),
  }) => LocalEvent(
    eventId: eventId ?? this.eventId,
    eventType: eventType ?? this.eventType,
    technicianId: technicianId ?? this.technicianId,
    fieldId: fieldId ?? this.fieldId,
    endedAt: endedAt ?? this.endedAt,
    uploadState: uploadState ?? this.uploadState,
    attempts: attempts ?? this.attempts,
    serverResult: serverResult.present ? serverResult.value : this.serverResult,
    serverError: serverError.present ? serverError.value : this.serverError,
    uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
  );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      technicianId: data.technicianId.present
          ? data.technicianId.value
          : this.technicianId,
      fieldId: data.fieldId.present ? data.fieldId.value : this.fieldId,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      serverResult: data.serverResult.present
          ? data.serverResult.value
          : this.serverResult,
      serverError: data.serverError.present
          ? data.serverError.value
          : this.serverError,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('eventId: $eventId, ')
          ..write('eventType: $eventType, ')
          ..write('technicianId: $technicianId, ')
          ..write('fieldId: $fieldId, ')
          ..write('endedAt: $endedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('attempts: $attempts, ')
          ..write('serverResult: $serverResult, ')
          ..write('serverError: $serverError, ')
          ..write('uploadedAt: $uploadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    eventType,
    technicianId,
    fieldId,
    endedAt,
    uploadState,
    attempts,
    serverResult,
    serverError,
    uploadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.eventId == this.eventId &&
          other.eventType == this.eventType &&
          other.technicianId == this.technicianId &&
          other.fieldId == this.fieldId &&
          other.endedAt == this.endedAt &&
          other.uploadState == this.uploadState &&
          other.attempts == this.attempts &&
          other.serverResult == this.serverResult &&
          other.serverError == this.serverError &&
          other.uploadedAt == this.uploadedAt);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<String> eventId;
  final Value<String> eventType;
  final Value<String> technicianId;
  final Value<String> fieldId;
  final Value<DateTime> endedAt;
  final Value<String> uploadState;
  final Value<int> attempts;
  final Value<String?> serverResult;
  final Value<String?> serverError;
  final Value<DateTime?> uploadedAt;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.eventId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.technicianId = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.serverResult = const Value.absent(),
    this.serverError = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String eventId,
    required String eventType,
    required String technicianId,
    required String fieldId,
    required DateTime endedAt,
    this.uploadState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.serverResult = const Value.absent(),
    this.serverError = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       eventType = Value(eventType),
       technicianId = Value(technicianId),
       fieldId = Value(fieldId),
       endedAt = Value(endedAt);
  static Insertable<LocalEvent> custom({
    Expression<String>? eventId,
    Expression<String>? eventType,
    Expression<String>? technicianId,
    Expression<String>? fieldId,
    Expression<DateTime>? endedAt,
    Expression<String>? uploadState,
    Expression<int>? attempts,
    Expression<String>? serverResult,
    Expression<String>? serverError,
    Expression<DateTime>? uploadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (eventType != null) 'event_type': eventType,
      if (technicianId != null) 'technician_id': technicianId,
      if (fieldId != null) 'field_id': fieldId,
      if (endedAt != null) 'ended_at': endedAt,
      if (uploadState != null) 'upload_state': uploadState,
      if (attempts != null) 'attempts': attempts,
      if (serverResult != null) 'server_result': serverResult,
      if (serverError != null) 'server_error': serverError,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? eventType,
    Value<String>? technicianId,
    Value<String>? fieldId,
    Value<DateTime>? endedAt,
    Value<String>? uploadState,
    Value<int>? attempts,
    Value<String?>? serverResult,
    Value<String?>? serverError,
    Value<DateTime?>? uploadedAt,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      eventId: eventId ?? this.eventId,
      eventType: eventType ?? this.eventType,
      technicianId: technicianId ?? this.technicianId,
      fieldId: fieldId ?? this.fieldId,
      endedAt: endedAt ?? this.endedAt,
      uploadState: uploadState ?? this.uploadState,
      attempts: attempts ?? this.attempts,
      serverResult: serverResult ?? this.serverResult,
      serverError: serverError ?? this.serverError,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (technicianId.present) {
      map['technician_id'] = Variable<String>(technicianId.value);
    }
    if (fieldId.present) {
      map['field_id'] = Variable<String>(fieldId.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (serverResult.present) {
      map['server_result'] = Variable<String>(serverResult.value);
    }
    if (serverError.present) {
      map['server_error'] = Variable<String>(serverError.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('eventType: $eventType, ')
          ..write('technicianId: $technicianId, ')
          ..write('fieldId: $fieldId, ')
          ..write('endedAt: $endedAt, ')
          ..write('uploadState: $uploadState, ')
          ..write('attempts: $attempts, ')
          ..write('serverResult: $serverResult, ')
          ..write('serverError: $serverError, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkerCacheTable workerCache = $WorkerCacheTable(this);
  late final $LocalScansTable localScans = $LocalScansTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workerCache,
    localScans,
    localEvents,
  ];
}

typedef $$WorkerCacheTableCreateCompanionBuilder =
    WorkerCacheCompanion Function({
      required String id,
      required String name,
      required bool active,
      required String qrCheck,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WorkerCacheTableUpdateCompanionBuilder =
    WorkerCacheCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> active,
      Value<String> qrCheck,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$WorkerCacheTableFilterComposer
    extends Composer<_$AppDatabase, $WorkerCacheTable> {
  $$WorkerCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrCheck => $composableBuilder(
    column: $table.qrCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkerCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkerCacheTable> {
  $$WorkerCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrCheck => $composableBuilder(
    column: $table.qrCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkerCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkerCacheTable> {
  $$WorkerCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<String> get qrCheck =>
      $composableBuilder(column: $table.qrCheck, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkerCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkerCacheTable,
          WorkerCacheData,
          $$WorkerCacheTableFilterComposer,
          $$WorkerCacheTableOrderingComposer,
          $$WorkerCacheTableAnnotationComposer,
          $$WorkerCacheTableCreateCompanionBuilder,
          $$WorkerCacheTableUpdateCompanionBuilder,
          (
            WorkerCacheData,
            BaseReferences<_$AppDatabase, $WorkerCacheTable, WorkerCacheData>,
          ),
          WorkerCacheData,
          PrefetchHooks Function()
        > {
  $$WorkerCacheTableTableManager(_$AppDatabase db, $WorkerCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkerCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkerCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkerCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<String> qrCheck = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkerCacheCompanion(
                id: id,
                name: name,
                active: active,
                qrCheck: qrCheck,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required bool active,
                required String qrCheck,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkerCacheCompanion.insert(
                id: id,
                name: name,
                active: active,
                qrCheck: qrCheck,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkerCacheTable, WorkerCacheData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkerCacheTable,
                    WorkerCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkerCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkerCacheTable,
      WorkerCacheData,
      $$WorkerCacheTableFilterComposer,
      $$WorkerCacheTableOrderingComposer,
      $$WorkerCacheTableAnnotationComposer,
      $$WorkerCacheTableCreateCompanionBuilder,
      $$WorkerCacheTableUpdateCompanionBuilder,
      (
        WorkerCacheData,
        BaseReferences<_$AppDatabase, $WorkerCacheTable, WorkerCacheData>,
      ),
      WorkerCacheData,
      PrefetchHooks Function()
    >;
typedef $$LocalScansTableCreateCompanionBuilder = LocalScansCompanion Function({
  required String scanId,
  required String workerId,
  required String qrCheck,
  required String technicianId,
  required String fieldId,
  required DateTime scannedAt,
  Value<double?> lat,
  Value<double?> lng,
  Value<String> uploadState,
  Value<int> attempts,
  Value<String?> serverResult,
  Value<String?> serverError,
  Value<DateTime?> uploadedAt,
  Value<int> rowid,
});
typedef $$LocalScansTableUpdateCompanionBuilder = LocalScansCompanion Function({
  Value<String> scanId,
  Value<String> workerId,
  Value<String> qrCheck,
  Value<String> technicianId,
  Value<String> fieldId,
  Value<DateTime> scannedAt,
  Value<double?> lat,
  Value<double?> lng,
  Value<String> uploadState,
  Value<int> attempts,
  Value<String?> serverResult,
  Value<String?> serverError,
  Value<DateTime?> uploadedAt,
  Value<int> rowid,
});

class $$LocalScansTableFilterComposer
    extends Composer<_$AppDatabase, $LocalScansTable> {
  $$LocalScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scanId => $composableBuilder(
    column: $table.scanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workerId => $composableBuilder(
    column: $table.workerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrCheck => $composableBuilder(
    column: $table.qrCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalScansTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalScansTable> {
  $$LocalScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scanId => $composableBuilder(
    column: $table.scanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workerId => $composableBuilder(
    column: $table.workerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrCheck => $composableBuilder(
    column: $table.qrCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
    column: $table.scannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalScansTable> {
  $$LocalScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scanId =>
      $composableBuilder(column: $table.scanId, builder: (column) => column);

  GeneratedColumn<String> get workerId =>
      $composableBuilder(column: $table.workerId, builder: (column) => column);

  GeneratedColumn<String> get qrCheck =>
      $composableBuilder(column: $table.qrCheck, builder: (column) => column);

  GeneratedColumn<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldId =>
      $composableBuilder(column: $table.fieldId, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );
}

class $$LocalScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalScansTable,
          LocalScan,
          $$LocalScansTableFilterComposer,
          $$LocalScansTableOrderingComposer,
          $$LocalScansTableAnnotationComposer,
          $$LocalScansTableCreateCompanionBuilder,
          $$LocalScansTableUpdateCompanionBuilder,
          (
            LocalScan,
            BaseReferences<_$AppDatabase, $LocalScansTable, LocalScan>,
          ),
          LocalScan,
          PrefetchHooks Function()
        > {
  $$LocalScansTableTableManager(_$AppDatabase db, $LocalScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scanId = const Value.absent(),
                Value<String> workerId = const Value.absent(),
                Value<String> qrCheck = const Value.absent(),
                Value<String> technicianId = const Value.absent(),
                Value<String> fieldId = const Value.absent(),
                Value<DateTime> scannedAt = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> serverResult = const Value.absent(),
                Value<String?> serverError = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalScansCompanion(
                scanId: scanId,
                workerId: workerId,
                qrCheck: qrCheck,
                technicianId: technicianId,
                fieldId: fieldId,
                scannedAt: scannedAt,
                lat: lat,
                lng: lng,
                uploadState: uploadState,
                attempts: attempts,
                serverResult: serverResult,
                serverError: serverError,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scanId,
                required String workerId,
                required String qrCheck,
                required String technicianId,
                required String fieldId,
                required DateTime scannedAt,
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> serverResult = const Value.absent(),
                Value<String?> serverError = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalScansCompanion.insert(
                scanId: scanId,
                workerId: workerId,
                qrCheck: qrCheck,
                technicianId: technicianId,
                fieldId: fieldId,
                scannedAt: scannedAt,
                lat: lat,
                lng: lng,
                uploadState: uploadState,
                attempts: attempts,
                serverResult: serverResult,
                serverError: serverError,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalScansTable, LocalScan>(table),
                  BaseReferences<_$AppDatabase, $LocalScansTable, LocalScan>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalScansTable,
      LocalScan,
      $$LocalScansTableFilterComposer,
      $$LocalScansTableOrderingComposer,
      $$LocalScansTableAnnotationComposer,
      $$LocalScansTableCreateCompanionBuilder,
      $$LocalScansTableUpdateCompanionBuilder,
      (LocalScan, BaseReferences<_$AppDatabase, $LocalScansTable, LocalScan>),
      LocalScan,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      required String eventId,
      required String eventType,
      required String technicianId,
      required String fieldId,
      required DateTime endedAt,
      Value<String> uploadState,
      Value<int> attempts,
      Value<String?> serverResult,
      Value<String?> serverError,
      Value<DateTime?> uploadedAt,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> eventId,
      Value<String> eventType,
      Value<String> technicianId,
      Value<String> fieldId,
      Value<DateTime> endedAt,
      Value<String> uploadState,
      Value<int> attempts,
      Value<String?> serverResult,
      Value<String?> serverError,
      Value<DateTime?> uploadedAt,
      Value<int> rowid,
    });

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldId => $composableBuilder(
    column: $table.fieldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get technicianId => $composableBuilder(
    column: $table.technicianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldId =>
      $composableBuilder(column: $table.fieldId, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get serverResult => $composableBuilder(
    column: $table.serverResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverError => $composableBuilder(
    column: $table.serverError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEventsTable,
          LocalEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (
            LocalEvent,
            BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
          ),
          LocalEvent,
          PrefetchHooks Function()
        > {
  $$LocalEventsTableTableManager(_$AppDatabase db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> technicianId = const Value.absent(),
                Value<String> fieldId = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> serverResult = const Value.absent(),
                Value<String?> serverError = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                eventId: eventId,
                eventType: eventType,
                technicianId: technicianId,
                fieldId: fieldId,
                endedAt: endedAt,
                uploadState: uploadState,
                attempts: attempts,
                serverResult: serverResult,
                serverError: serverError,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String eventType,
                required String technicianId,
                required String fieldId,
                required DateTime endedAt,
                Value<String> uploadState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> serverResult = const Value.absent(),
                Value<String?> serverError = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                eventId: eventId,
                eventType: eventType,
                technicianId: technicianId,
                fieldId: fieldId,
                endedAt: endedAt,
                uploadState: uploadState,
                attempts: attempts,
                serverResult: serverResult,
                serverError: serverError,
                uploadedAt: uploadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEventsTable, LocalEvent>(table),
                  BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEventsTable,
      LocalEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (
        LocalEvent,
        BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
      ),
      LocalEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkerCacheTableTableManager get workerCache =>
      $$WorkerCacheTableTableManager(_db, _db.workerCache);
  $$LocalScansTableTableManager get localScans =>
      $$LocalScansTableTableManager(_db, _db.localScans);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
}
