import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/moments.dart';
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

  /// When this technician last ended the field day on the phone since
  /// [fromUtc], or null. Everyone was clocked out at that moment.
  Future<DateTime?> latestEndFieldDay(
    String technicianId,
    DateTime fromUtc,
  ) async {
    final rows =
        await (select(localEvents)
              ..where(
                (row) =>
                    row.technicianId.equals(technicianId) &
                    row.endedAt.isBiggerOrEqualValue(fromUtc),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.endedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.endedAt.toUtc();
  }

  /// Workers this phone has clocked in and not out since [fromUtc] (the start
  /// of the Philippine day), counting only scans after the last End field day.
  /// An odd number of scans means the worker is still clocked in.
  ///
  /// [takenOver] maps a worker ID to the moment up to which this phone's scans
  /// of that worker no longer count, because another technician took the worker
  /// over (see `takeoverCutoff`).
  Future<int> clockedInCount(
    String technicianId,
    DateTime fromUtc, {
    Map<String, DateTime> takenOver = const {},
  }) async {
    final cutoff = await latestEndFieldDay(technicianId, fromUtc);
    final rows =
        await (select(localScans)..where(
              (row) =>
                  row.technicianId.equals(technicianId) &
                  row.scannedAt.isBiggerOrEqualValue(fromUtc) &
                  row.uploadState.equals('rejected').not(),
            ))
            .get();
    final perWorker = <String, int>{};
    for (final row in rows) {
      final skipUntil = laterOf(cutoff, takenOver[row.workerId]);
      if (skipUntil != null && !row.scannedAt.toUtc().isAfter(skipUntil)) {
        continue;
      }
      perWorker.update(row.workerId, (count) => count + 1, ifAbsent: () => 1);
    }
    return perWorker.values.where((count) => count.isOdd).length;
  }

  // The "pending" queries take the technician whose phone session this is.
  // After a log out another technician can log in on the same phone, and
  // their uploads must never carry the earlier technician's waiting scans.
  // Without an ID they return everything.

  Future<int> pendingCount({String? technicianId}) async {
    final scans = await pendingScanCount(technicianId: technicianId);
    final events =
        await (select(localEvents)..where(
              (row) =>
                  row.uploadState.equals('pending') &
                  _eventOwner(row, technicianId),
            ))
            .get();
    return scans + events.length;
  }

  Future<int> pendingScanCount({String? technicianId}) async =>
      (select(localScans)..where(
            (row) =>
                row.uploadState.equals('pending') &
                _scanOwner(row, technicianId),
          ))
          .get()
          .then((rows) => rows.length);

  Expression<bool> _scanOwner($LocalScansTable row, String? technicianId) =>
      technicianId == null
      ? const Constant(true)
      : row.technicianId.equals(technicianId);

  Expression<bool> _eventOwner($LocalEventsTable row, String? technicianId) =>
      technicianId == null
      ? const Constant(true)
      : row.technicianId.equals(technicianId);

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

  Future<List<LocalScan>> pendingScans({
    int limit = 50,
    String? technicianId,
  }) =>
      (select(localScans)
            ..where(
              (row) =>
                  row.uploadState.equals('pending') &
                  _scanOwner(row, technicianId),
            )
            ..orderBy([(row) => OrderingTerm(expression: row.scannedAt)])
            ..limit(limit))
          .get();

  Future<List<LocalEvent>> pendingEvents({String? technicianId}) =>
      (select(localEvents)
            ..where(
              (row) =>
                  row.uploadState.equals('pending') &
                  _eventOwner(row, technicianId),
            )
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
