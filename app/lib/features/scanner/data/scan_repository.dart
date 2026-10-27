import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local/app_database.dart';

class ScanContext {
  const ScanContext({required this.technicianId, required this.fieldId});

  final String technicianId;
  final String fieldId;
}

class ScanRepository {
  ScanRepository(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<WorkerCacheData?> findWorker(String workerId) =>
      database.findWorker(workerId);

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
