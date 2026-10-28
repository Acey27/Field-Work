import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

class WorkerCache extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get active => boolean()();
  TextColumn get qrCheck => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalScans extends Table {
  TextColumn get scanId => text()();
  TextColumn get workerId => text()();
  TextColumn get qrCheck => text()();
  TextColumn get technicianId => text()();
  TextColumn get fieldId => text()();
  DateTimeColumn get scannedAt => dateTime()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  TextColumn get uploadState => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get serverResult => text().nullable()();
  TextColumn get serverError => text().nullable()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scanId};
}

class LocalEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get eventType => text()();
  TextColumn get technicianId => text()();
  TextColumn get fieldId => text()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get uploadState => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get serverResult => text().nullable()();
  TextColumn get serverError => text().nullable()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

@DriftDatabase(tables: [WorkerCache, LocalScans, LocalEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> replaceWorkers(List<WorkerCacheCompanion> workers) async {
    await transaction(() async {
      for (final worker in workers) {
        await into(workerCache).insertOnConflictUpdate(worker);
      }
    });
  }

  Future<WorkerCacheData?> findWorker(String workerId) => (select(
    workerCache,
  )..where((row) => row.id.equals(workerId))).getSingleOrNull();

  /// Times (UTC) of this worker's scans on the phone since [fromUtc], not
  /// counting scans the server rejected.
  Future<List<DateTime>> workerScanTimes(String workerId, DateTime fromUtc) async {
    final rows =
        await (select(localScans)..where(
              (row) =>
                  row.workerId.equals(workerId) &
                  row.scannedAt.isBiggerOrEqualValue(fromUtc) &
                  row.uploadState.equals('rejected').not(),
            ))
            .get();
    return rows.map((row) => row.scannedAt.toUtc()).toList();
  }

  Future<int> pendingCount() async {
    final scans = await (select(
      localScans,
    )..where((row) => row.uploadState.equals('pending'))).get();
    final events = await (select(
      localEvents,
    )..where((row) => row.uploadState.equals('pending'))).get();
    return scans.length + events.length;
  }

  Future<int> pendingScanCount() async =>
      (select(localScans)..where((row) => row.uploadState.equals('pending')))
          .get()
          .then((rows) => rows.length);

  Future<void> addScan({
    required String scanId,
    required String workerId,
    required String qrCheck,
    required String technicianId,
    required String fieldId,
    required DateTime scannedAt,
    double? lat,
    double? lng,
  }) async {
    await into(localScans).insert(
      LocalScansCompanion.insert(
        scanId: scanId,
        workerId: workerId,
        qrCheck: qrCheck,
        technicianId: technicianId,
        fieldId: fieldId,
        scannedAt: scannedAt.toUtc(),
        lat: Value(lat),
        lng: Value(lng),
      ),
    );
  }

  Future<void> addEndFieldDay({
    required String technicianId,
    required String fieldId,
    required DateTime endedAt,
  }) async {
    await into(localEvents).insert(
      LocalEventsCompanion.insert(
        eventId: const Uuid().v4(),
        eventType: 'end_field_day',
        technicianId: technicianId,
        fieldId: fieldId,
        endedAt: endedAt.toUtc(),
      ),
    );
  }

  Future<List<LocalScan>> pendingScans({int limit = 50}) =>
      (select(localScans)
            ..where((row) => row.uploadState.equals('pending'))
            ..orderBy([(row) => OrderingTerm(expression: row.scannedAt)])
            ..limit(limit))
          .get();

  Future<List<LocalEvent>> pendingEvents() =>
      (select(localEvents)
            ..where((row) => row.uploadState.equals('pending'))
            ..orderBy([(row) => OrderingTerm(expression: row.endedAt)]))
          .get();

  Future<void> markScanUploaded(String scanId, Map<String, dynamic> result) =>
      (update(localScans)..where((row) => row.scanId.equals(scanId))).write(
        LocalScansCompanion(
          uploadState: const Value('uploaded'),
          serverResult: Value(jsonEncode(result)),
          uploadedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markScanRejected(String scanId, Map<String, dynamic> result) =>
      (update(localScans)..where((row) => row.scanId.equals(scanId))).write(
        LocalScansCompanion(
          uploadState: const Value('rejected'),
          serverResult: Value(jsonEncode(result)),
          uploadedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markScanRetry(String scanId, int attempts, String error) =>
      (update(localScans)..where((row) => row.scanId.equals(scanId))).write(
        LocalScansCompanion(
          attempts: Value(attempts + 1),
          serverError: Value(error),
        ),
      );

  Future<void> markEventUploaded(String eventId, Map<String, dynamic> result) =>
      (update(localEvents)..where((row) => row.eventId.equals(eventId))).write(
        LocalEventsCompanion(
          uploadState: const Value('uploaded'),
          serverResult: Value(jsonEncode(result)),
          uploadedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markEventRetry(String eventId, int attempts, String error) =>
      (update(localEvents)..where((row) => row.eventId.equals(eventId))).write(
        LocalEventsCompanion(
          attempts: Value(attempts + 1),
          serverError: Value(error),
        ),
      );
}

QueryExecutor _openConnection() {
  return LazyDatabase(openDatabaseConnection);
}
