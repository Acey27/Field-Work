import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local/app_database.dart';
import '../../../core/utils/ph_time.dart';
import '../domain/qr_payload.dart';
import '../domain/scan_decision.dart';

class ScanContext {
  const ScanContext({required this.technicianId, required this.fieldId});

  final String technicianId;
  final String fieldId;
}

enum ScanOutcome {
  /// The text is not a worker QR code.
  invalid,

  /// The worker is not in the phone's worker list yet.
  workerNotCached,

  /// The card's check code differs from the list (old or copied card).
  badCard,

  /// The worker is turned off.
  inactive,

  /// Same card scanned again within the repeat window. Nothing saved.
  repeat,

  /// Saved on the phone, ready to upload.
  saved,
}

class ScanResult {
  const ScanResult(this.outcome, {this.worker, this.direction, this.at});

  final ScanOutcome outcome;
  final WorkerCacheData? worker;
  final LocalDirection? direction;
  final DateTime? at;
}

class ScanRepository {
  ScanRepository(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<WorkerCacheData?> findWorker(String workerId) =>
      database.findWorker(workerId);

  /// The whole phone-side scan: check the card, apply the 30-second repeat
  /// rule, work out in or out, and save the scan before anything is shown
  /// (CONTRACT.md section 6). [position] is only asked for when a scan is saved.
  Future<ScanResult> processScan({
    required ScanContext context,
    required String? rawValue,
    required DateTime now,
    Future<Position?> Function()? position,
  }) async {
    final payload = QrPayload.parse(rawValue);
    if (payload == null) return const ScanResult(ScanOutcome.invalid);
    final worker = await findWorker(payload.workerId);
    if (worker == null) return const ScanResult(ScanOutcome.workerNotCached);
    if (worker.qrCheck != payload.qrCheck) {
      return ScanResult(ScanOutcome.badCard, worker: worker);
    }
    if (!worker.active) {
      return ScanResult(ScanOutcome.inactive, worker: worker);
    }
    final dayStart = phTimeToUtc(phDateOf(now), 0, 0);
    final allToday = await database.workerScanTimes(worker.id, dayStart);
    // After End field day everyone is clocked out, so the next scan is a
    // clock in again, whatever happened before.
    final resetAt = await database.latestEndFieldDay(
      context.technicianId,
      dayStart,
    );
    final sinceReset = resetAt == null
        ? allToday
        : allToday.where((time) => time.isAfter(resetAt)).toList();
    final decision = decideScan(
      todaysScans: sinceReset,
      recentScans: allToday,
      now: now,
    );
    if (decision.isRepeat) {
      return ScanResult(ScanOutcome.repeat, worker: worker);
    }
    await saveScan(
      context: context,
      workerId: worker.id,
      qrCheck: payload.qrCheck,
      scannedAt: now,
      position: await position?.call(),
    );
    return ScanResult(
      ScanOutcome.saved,
      worker: worker,
      direction: decision.direction,
      at: now,
    );
  }

  Future<String> saveScan({
    required ScanContext context,
    required String workerId,
    required String qrCheck,
    required DateTime scannedAt,
    Position? position,
  }) async {
    final scanId = _uuid.v4();
    await database.addScan(
      scanId: scanId,
      workerId: workerId,
      qrCheck: qrCheck,
      technicianId: context.technicianId,
      fieldId: context.fieldId,
      scannedAt: scannedAt,
      lat: position?.latitude,
      lng: position?.longitude,
    );
    return scanId;
  }

  Future<void> saveEndFieldDay({
    required ScanContext context,
    required DateTime endedAt,
  }) => database.addEndFieldDay(
    technicianId: context.technicianId,
    fieldId: context.fieldId,
    endedAt: endedAt,
  );
}
