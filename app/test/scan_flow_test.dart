import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/local/app_database.dart';
import 'package:fieldwork_attendance/core/utils/moments.dart';
import 'package:fieldwork_attendance/features/scanner/data/scan_repository.dart';
import 'package:fieldwork_attendance/features/scanner/domain/scan_decision.dart';

void main() {
  group('decideScan', () {
    final now = DateTime.utc(2026, 10, 19, 1, 0, 0);

    test('first scan of the day is a clock in', () {
      final decision = decideScan(todaysScans: [], now: now);
      expect(decision.isRepeat, isFalse);
      expect(decision.direction, LocalDirection.clockIn);
    });

    test('second scan is a clock out, third is a clock in again', () {
      final out = decideScan(
        todaysScans: [now.subtract(const Duration(hours: 3))],
        now: now,
      );
      expect(out.direction, LocalDirection.clockOut);
      final again = decideScan(
        todaysScans: [
          now.subtract(const Duration(hours: 5)),
          now.subtract(const Duration(hours: 3)),
        ],
        now: now,
      );
      expect(again.direction, LocalDirection.clockIn);
    });

    test('ignores the same card inside 30 seconds', () {
      final decision = decideScan(
        todaysScans: [now.subtract(const Duration(seconds: 29))],
        now: now,
      );
      expect(decision.isRepeat, isTrue);
    });

    test('accepts the card again at exactly 30 seconds', () {
      final decision = decideScan(
        todaysScans: [now.subtract(const Duration(seconds: 30))],
        now: now,
      );
      expect(decision.isRepeat, isFalse);
    });
  });

  group('AppDatabase.clockedInCount', () {
    final dayStart = DateTime.utc(2026, 10, 18, 16); // 12:00 AM on the 19th, PH
    late AppDatabase database;

    Future<void> scan(String worker, DateTime at, {String tech = 'tech-1'}) =>
        database.addScan(
          scanId: '$worker-${at.toIso8601String()}-$tech',
          workerId: worker,
          qrCheck: 'abc',
          technicianId: tech,
          fieldId: 'field-1',
          scannedAt: at,
        );

    setUp(() => database = AppDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    test('counts workers with an odd number of scans', () async {
      await scan('W-00001', DateTime.utc(2026, 10, 19, 1));
      await scan('W-00002', DateTime.utc(2026, 10, 19, 1));
      await scan('W-00002', DateTime.utc(2026, 10, 19, 5)); // clocked out
      await scan('W-00003', DateTime.utc(2026, 10, 19, 2));
      expect(await database.clockedInCount('tech-1', dayStart), 2);
    });

    test('is zero after End field day', () async {
      await scan('W-00001', DateTime.utc(2026, 10, 19, 1));
      await scan('W-00002', DateTime.utc(2026, 10, 19, 2));
      await database.addEndFieldDay(
        technicianId: 'tech-1',
        fieldId: 'field-1',
        endedAt: DateTime.utc(2026, 10, 19, 8),
      );
      expect(await database.clockedInCount('tech-1', dayStart), 0);
      await scan('W-00001', DateTime.utc(2026, 10, 19, 9));
      expect(await database.clockedInCount('tech-1', dayStart), 1);
    });

    test('ignores other technicians and earlier days', () async {
      await scan('W-00001', DateTime.utc(2026, 10, 19, 1), tech: 'tech-2');
      await scan('W-00002', DateTime.utc(2026, 10, 18, 5)); // yesterday
      expect(await database.clockedInCount('tech-1', dayStart), 0);
    });

    test('ignores scans the server rejected', () async {
      await scan('W-00001', DateTime.utc(2026, 10, 19, 1));
      await database.markScanRejected(
        'W-00001-${DateTime.utc(2026, 10, 19, 1).toIso8601String()}-tech-1',
        {'result': 'blocked_bad_qr'},
      );
      expect(await database.clockedInCount('tech-1', dayStart), 0);
    });

    test(
      'ignores a scan refused because another technician holds the worker',
      () async {
        final at = DateTime.utc(2026, 10, 19, 3);
        await scan('W-00001', at);
        await database.markScanRejected(
          'W-00001-${at.toIso8601String()}-tech-1',
          {'result': 'blocked_held_elsewhere'},
        );
        expect(await database.clockedInCount('tech-1', dayStart), 0);
      },
    );

    test('does not count a worker another technician took over', () async {
      await scan('W-00001', DateTime.utc(2026, 10, 19, 1));
      await scan('W-00002', DateTime.utc(2026, 10, 19, 1));
      // Technician 2 took W-00001 over at 02:00.
      final takenOver = {
        'W-00001': takeoverCutoff(DateTime.utc(2026, 10, 19, 2)),
      };
      expect(
        await database.clockedInCount('tech-1', dayStart, takenOver: takenOver),
        1,
      );
      // A later clock in by this technician counts again.
      await scan('W-00001', DateTime.utc(2026, 10, 19, 6));
      expect(
        await database.clockedInCount('tech-1', dayStart, takenOver: takenOver),
        2,
      );
    });
  });

  group('takeoverCutoff and laterOf', () {
    test('a scan in the same minute as the takeover counts as before it', () {
      final cutoff = takeoverCutoff(DateTime.utc(2026, 10, 19, 2));
      expect(cutoff, DateTime.utc(2026, 10, 19, 2, 1));
      expect(DateTime.utc(2026, 10, 19, 2, 0, 59).isAfter(cutoff), isFalse);
      expect(DateTime.utc(2026, 10, 19, 2, 2).isAfter(cutoff), isTrue);
    });

    test('laterOf picks the later moment and copes with nulls', () {
      final early = DateTime.utc(2026, 10, 19, 1);
      final late = DateTime.utc(2026, 10, 19, 5);
      expect(laterOf(early, late), late);
      expect(laterOf(late, early), late);
      expect(laterOf(null, early), early);
      expect(laterOf(early, null), early);
      expect(laterOf(null, null), isNull);
    });
  });

  group('ScanRepository.processScan', () {
    const context = ScanContext(technicianId: 'tech-1', fieldId: 'field-1');
    late AppDatabase database;
    late ScanRepository repository;

    Future<void> addWorker({
      String id = 'W-00001',
      String qrCheck = 'abc',
      bool active = true,
    }) => database.replaceWorkers([
      WorkerCacheCompanion.insert(
        id: id,
        name: 'Juan Dela Cruz',
        active: active,
        qrCheck: qrCheck,
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    ]);

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = ScanRepository(database);
    });

    tearDown(() => database.close());

    test('rejects text that is not a worker QR code', () async {
      final result = await repository.processScan(
        context: context,
        rawValue: 'hello',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      expect(result.outcome, ScanOutcome.invalid);
      expect(await database.pendingScanCount(), 0);
    });

    test('reports a worker that is not in the phone list', () async {
      final result = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      expect(result.outcome, ScanOutcome.workerNotCached);
    });

    test('rejects an old or copied card with a different check code', () async {
      await addWorker(qrCheck: 'new');
      final result = await repository.processScan(
        context: context,
        rawValue: 'W-00001.old',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      expect(result.outcome, ScanOutcome.badCard);
      expect(await database.pendingScanCount(), 0);
    });

    test('blocks an inactive worker without saving', () async {
      await addWorker(active: false);
      final result = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      expect(result.outcome, ScanOutcome.inactive);
      expect(await database.pendingScanCount(), 0);
    });

    test('saves the scan on the phone and reports clock in then out', () async {
      await addWorker();
      final first = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      expect(first.outcome, ScanOutcome.saved);
      expect(first.direction, LocalDirection.clockIn);
      expect(await database.pendingScanCount(), 1);

      final second = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 9),
      );
      expect(second.direction, LocalDirection.clockOut);
      expect(await database.pendingScanCount(), 2);
    });

    test('ignores a second scan within 30 seconds and saves nothing', () async {
      await addWorker();
      final at = DateTime.utc(2026, 10, 19, 1);
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: at,
      );
      final repeat = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: at.add(const Duration(seconds: 10)),
      );
      expect(repeat.outcome, ScanOutcome.repeat);
      expect(await database.pendingScanCount(), 1);
    });

    test('a scan on a new Philippine date is a new clock in', () async {
      await addWorker();
      // 15:59 UTC is 11:59 PM on the 19th; 16:01 UTC is 12:01 AM on the 20th.
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 15, 59),
      );
      final next = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 16, 1),
      );
      expect(next.direction, LocalDirection.clockIn);
    });

    test('a scan after End field day is a clock in again', () async {
      await addWorker();
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      await database.addEndFieldDay(
        technicianId: 'tech-1',
        fieldId: 'field-1',
        endedAt: DateTime.utc(2026, 10, 19, 8),
      );
      final next = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 9),
      );
      expect(next.direction, LocalDirection.clockIn);
    });

    test('after another technician took the worker over, the next scan is a clock in', () async {
      await addWorker();
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      // Technician 2 took the worker over at 02:00. This phone's own scan at
      // 01:00 no longer counts, so a scan at 04:00 is a clock in, not the clock
      // out the phone used to show (the server then refuses it while
      // technician 2 holds the worker, or records the clock in).
      final next = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 4),
        takenOver: {'W-00001': takeoverCutoff(DateTime.utc(2026, 10, 19, 2))},
      );
      expect(next.outcome, ScanOutcome.saved);
      expect(next.direction, LocalDirection.clockIn);
    });

    test('without a takeover the same second scan is a clock out', () async {
      await addWorker();
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
      );
      final next = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 4),
      );
      expect(next.direction, LocalDirection.clockOut);
    });

    test('a takeover resets this worker only', () async {
      await database.replaceWorkers([
        WorkerCacheCompanion.insert(
          id: 'W-00001',
          name: 'Juan Dela Cruz',
          active: true,
          qrCheck: 'abc',
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        WorkerCacheCompanion.insert(
          id: 'W-00002',
          name: 'Maria Santos',
          active: true,
          qrCheck: 'abc',
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      ]);
      for (final id in ['W-00001', 'W-00002']) {
        await repository.processScan(
          context: context,
          rawValue: '$id.abc',
          now: DateTime.utc(2026, 10, 19, 1),
        );
      }
      final takenOver = {
        'W-00001': takeoverCutoff(DateTime.utc(2026, 10, 19, 2)),
      };
      final taken = await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 4),
        takenOver: takenOver,
      );
      final other = await repository.processScan(
        context: context,
        rawValue: 'W-00002.abc',
        now: DateTime.utc(2026, 10, 19, 4),
        takenOver: takenOver,
      );
      expect(taken.direction, LocalDirection.clockIn);
      expect(other.direction, LocalDirection.clockOut);
    });

    test('asks for the location only when a scan is saved', () async {
      await addWorker();
      var asked = 0;
      Future<Null> position() async {
        asked++;
        return null;
      }

      await repository.processScan(
        context: context,
        rawValue: 'bad',
        now: DateTime.utc(2026, 10, 19, 1),
        position: position,
      );
      expect(asked, 0);
      await repository.processScan(
        context: context,
        rawValue: 'W-00001.abc',
        now: DateTime.utc(2026, 10, 19, 1),
        position: position,
      );
      expect(asked, 1);
    });
  });
}
