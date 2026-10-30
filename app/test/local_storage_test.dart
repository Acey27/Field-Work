import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/local/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('saves a scan before it is uploaded', () async {
    final scannedAt = DateTime.utc(2026, 10, 28, 1, 2);
    await database.replaceWorkers([
      WorkerCacheCompanion.insert(
        id: 'W-00001',
        name: 'Juan Dela Cruz',
        active: true,
        qrCheck: 'abc',
        updatedAt: scannedAt,
      ),
    ]);
    await database.addScan(
      scanId: 'scan-1',
      workerId: 'W-00001',
      qrCheck: 'abc',
      technicianId: 'tech-1',
      fieldId: 'field-1',
      scannedAt: scannedAt,
    );

    expect(await database.pendingScanCount(), 1);
    expect((await database.pendingScans()).single.scanId, 'scan-1');
  });

  test('waiting scans and events can be limited to one technician', () async {
    Future<void> scan(String id, String technician) => database.addScan(
      scanId: id,
      workerId: 'W-00001',
      qrCheck: 'abc',
      technicianId: technician,
      fieldId: 'field-1',
      scannedAt: DateTime.utc(2026, 10, 28),
    );
    await scan('a-1', 'tech-a');
    await scan('a-2', 'tech-a');
    await scan('b-1', 'tech-b');
    await database.addEndFieldDay(
      technicianId: 'tech-b',
      fieldId: 'field-1',
      endedAt: DateTime.utc(2026, 10, 28, 9),
    );

    expect(await database.pendingScanCount(technicianId: 'tech-a'), 2);
    expect(await database.pendingScanCount(technicianId: 'tech-b'), 1);
    expect(await database.pendingCount(technicianId: 'tech-a'), 2);
    expect(await database.pendingCount(technicianId: 'tech-b'), 2);
    expect(await database.pendingCount(), 4);
    expect(
      (await database.pendingScans(technicianId: 'tech-a'))
          .map((s) => s.scanId),
      ['a-1', 'a-2'],
    );
    expect(await database.pendingEvents(technicianId: 'tech-a'), isEmpty);
    expect(await database.pendingEvents(technicianId: 'tech-b'), hasLength(1));
  });

  test(
    'retains the original scan id when marking a duplicate response',
    () async {
      await database.addScan(
        scanId: 'scan-1',
        workerId: 'W-00001',
        qrCheck: 'abc',
        technicianId: 'tech-1',
        fieldId: 'field-1',
        scannedAt: DateTime.utc(2026, 10, 28),
      );
      await database.markScanUploaded('scan-1', {
        'scan_id': 'scan-1',
        'result': 'clocked_in',
        'duplicate': true,
      });

      final row = await (database.select(
        database.localScans,
      )..where((scan) => scan.scanId.equals('scan-1'))).getSingle();
      expect(row.scanId, 'scan-1');
      expect(row.uploadState, 'uploaded');
      expect(row.serverResult, contains('"duplicate":true'));
    },
  );

  test('queues end field day after local scan storage', () async {
    final endedAt = DateTime.utc(2026, 10, 28, 8);
    await database.addScan(
      scanId: 'scan-1',
      workerId: 'W-00001',
      qrCheck: 'abc',
      technicianId: 'tech-1',
      fieldId: 'field-1',
      scannedAt: endedAt,
    );
    await database.addEndFieldDay(
      technicianId: 'tech-1',
      fieldId: 'field-1',
      endedAt: endedAt,
    );

    expect(await database.pendingScanCount(), 1);
    expect((await database.pendingEvents()).single.eventType, 'end_field_day');
  });
}
