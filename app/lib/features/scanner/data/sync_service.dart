import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/app_database.dart';
import '../../../core/utils/ph_time.dart';
import '../../auth/data/device_service.dart';

class SyncService {
  SyncService({
    required this.database,
    DeviceService? deviceService,
    SupabaseClient? client,
  }) : _deviceService = deviceService ?? DeviceService(),
       _client = client ?? Supabase.instance.client;

  final AppDatabase database;
  final DeviceService _deviceService;
  final SupabaseClient _client;

  Future<void> refreshWorkerCache({DateTime? since}) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_worker_cache',
      params: {'p_since': since?.toUtc().toIso8601String()},
    );
    final rows = response
        .map((row) => row is Map ? Map<String, dynamic>.from(row) : null)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => WorkerCacheCompanion.insert(
            id: row['id'] as String,
            name: row['name'] as String,
            active: row['active'] as bool,
            qrCheck: row['qr_check'] as String,
            updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
          ),
        )
        .toList();
    await database.replaceWorkers(rows);
  }

  Future<SyncSummary> sync() async {
    await refreshWorkerCache();
    final deviceUuid = await _deviceService.deviceUuid();
    var uploadedScans = 0;
    final refused = <RefusedScan>[];
    // Only the signed-in technician's scans: another technician may have used
    // this phone before and left scans waiting.
    final technicianId = _client.auth.currentUser?.id;
    while (true) {
      final scans = await database.pendingScans(
        limit: 50,
        technicianId: technicianId,
      );
      if (scans.isEmpty) break;
      try {
        final response = await _client.rpc<Map<String, dynamic>>(
          'ingest_scans',
          params: {
            'p_device_uuid': deviceUuid,
            'p_device_time': DateTime.now().toUtc().toIso8601String(),
            'p_scans': scans.map(_scanJson).toList(),
          },
        );
        final mapped = await _mapScanResults(response['results'], {
          for (final scan in scans) scan.scanId: scan.workerId,
        }, refused);
        if (mapped == 0) {
          throw StateError('ingest_scans returned no scan results');
        }

        uploadedScans += scans.length;
      } catch (error) {
        for (final scan in scans) {
          await database.markScanRetry(scan.scanId, scan.attempts, '$error');
        }
        rethrow;
      }
    }

    final events = await database.pendingEvents(technicianId: technicianId);
    var uploadedEvents = 0;
    for (final event in events) {
      try {
        final response = await _client.rpc<Map<String, dynamic>>(
          'end_field_day',
          params: {
            'p_device_uuid': deviceUuid,
            'p_work_date': _workDate(event.endedAt),
            'p_ended_at': event.endedAt.toUtc().toIso8601String(),
          },
        );
        await database.markEventUploaded(event.eventId, response);
        uploadedEvents++;
      } catch (error) {
        await database.markEventRetry(event.eventId, event.attempts, '$error');
        rethrow;
      }
    }
    return SyncSummary(
      uploadedScans: uploadedScans,
      uploadedEvents: uploadedEvents,
      refused: refused,
    );
  }

  Future<int> fetchClockedInCount() async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'get_my_field_day',
      params: {'p_work_date': _workDate(DateTime.now().toUtc())},
    );
    return response['clocked_in_count'] as int? ?? 0;
  }

  Map<String, dynamic> _scanJson(LocalScan scan) => {
    'scan_id': scan.scanId,
    'worker_id': scan.workerId,
    'qr_check': scan.qrCheck,
    'field_id': scan.fieldId,
    'scanned_at': scan.scannedAt.toUtc().toIso8601String(),
    'lat': scan.lat,
    'lng': scan.lng,
  };

  /// Stores each result. A refused scan (`blocked_*`) is added to [refused]
  /// with the worker it was for ([workers] maps scan ID to worker ID), so the
  /// technician can be told it was not saved.
  Future<int> _mapScanResults(
    Object? rawResults,
    Map<String, String> workers,
    List<RefusedScan> refused,
  ) async {
    if (rawResults is! List) return 0;
    var mapped = 0;
    for (final raw in rawResults) {
      if (raw is! Map || raw['scan_id'] is! String) continue;
      final result = Map<String, dynamic>.from(raw);
      final scanId = result['scan_id'] as String;
      final name = result['result'] as String?;
      if (name != null && scanUploadState(name) == 'rejected') {
        await database.markScanRejected(scanId, result);
        refused.add(RefusedScan(workerId: workers[scanId] ?? '', result: name));
      } else {
        await database.markScanUploaded(scanId, result);
      }
      mapped++;
    }
    return mapped;
  }

  String _workDate(DateTime timestamp) {
    final date = phDateOf(timestamp);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

/// A scan the server refused (a `blocked_*` result, CONTRACT.md section 13).
/// It is not saved, so the technician is told which worker it was for.
class RefusedScan {
  const RefusedScan({required this.workerId, required this.result});

  final String workerId;
  final String result;
}

class SyncSummary {
  const SyncSummary({
    required this.uploadedScans,
    required this.uploadedEvents,
    this.refused = const [],
  });

  final int uploadedScans;
  final int uploadedEvents;

  /// Scans refused during this run.
  final List<RefusedScan> refused;
}

String encodeServerResult(Map<String, dynamic> result) => jsonEncode(result);

List<List<T>> splitIntoBatches<T>(List<T> items, {int size = 50}) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  final batches = <List<T>>[];
  for (var index = 0; index < items.length; index += size) {
    final end = (index + size < items.length) ? index + size : items.length;
    batches.add(items.sublist(index, end));
  }
  return batches;
}

String scanUploadState(String result) =>
    result.startsWith('blocked_') ? 'rejected' : 'uploaded';
