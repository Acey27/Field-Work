import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../auth/data/device_service.dart';
import '../data/scan_repository.dart';
import '../data/sync_service.dart';
import '../domain/qr_payload.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _database = AppDatabase.defaults();
  final _scannerController = MobileScannerController();
  late final ScanRepository _repository;
  late final SyncService _syncService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ScanContext? _scanContext;
  String _status = 'offline';
  bool _busy = false;
  int _pendingCount = 0;
  int _clockedInCount = 0;

  @override
  void initState() {
    super.initState();
    _repository = ScanRepository(_database);
    _syncService = SyncService(database: _database);
    _loadContext();
    _refreshPendingCount();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) _sync();
      if (mounted) setState(() => _status = online ? 'online' : 'offline');
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scannerController.dispose();
    _database.close();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final response = await DeviceService().context();
      final profile = response['profile'];
      final field = response['field'];
      if (!mounted || profile is! Map || field is! Map) return;
      setState(() {
        _scanContext = ScanContext(
          technicianId: profile['id'] as String,
          fieldId: field['id'] as String,
        );
      });
      await _sync();
    } catch (_) {
      if (mounted) setState(() => _status = 'offline');
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await _database.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _sync() async {
    if (_busy || _scanContext == null) return;
    if (mounted) setState(() => _status = 'syncing');
    try {
      await _syncService.sync();
      try {
        _clockedInCount = await _syncService.fetchClockedInCount();
      } catch (_) {
        // A successful scan sync is still useful if the field-day read is unavailable.
      }
      await _refreshPendingCount();
      if (mounted) setState(() => _status = 'online');
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _status = 'offline');
        _showMessage(error.code ?? error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'offline');
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _scanContext == null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final payload = QrPayload.parse(raw);
    if (payload == null) {
      _showMessage(AppLocalizations.of(context).invalidQr);
      return;
    }
    final worker = await _repository.findWorker(payload.workerId);
    if (!mounted) return;
    if (worker == null) {
      _showMessage(AppLocalizations.of(context).workerNotCached);
      return;
    }
    setState(() {
      _busy = true;
    });
    await _scannerController.stop();
    final confirmed = await _confirmWorker(worker);
    if (confirmed && _scanContext != null) {
      Position? position;
      try {
        if (await Geolocator.checkPermission() != LocationPermission.denied) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}
      await _repository.saveScan(
        context: _scanContext!,
        workerId: payload.workerId,
        qrCheck: payload.qrCheck,
        scannedAt: DateTime.now().toUtc(),
        position: position,
      );
      await _refreshPendingCount();
      if (mounted) _showMessage(AppLocalizations.of(context).scanSaved);
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
      await _scannerController.start();
    }
  }

  Future<bool> _confirmWorker(WorkerCacheData worker) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(worker.name),
        content: Text(worker.active ? worker.id : 'Worker inactive'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: worker.active
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _endFieldDay() async {
    final count = _status == 'online'
        ? _clockedInCount
        : await _database.pendingScanCount();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endFieldDay),
        content: Text(l10n.endFieldDayConfirmation(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || _scanContext == null || !mounted) return;
    await _repository.saveEndFieldDay(
      context: _scanContext!,
      endedAt: DateTime.now().toUtc(),
    );
    await _refreshPendingCount();
    await _sync();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (_status) {
      'syncing' => l10n.syncing,
      'online' => l10n.online,
      _ => l10n.offlineWithPending(_pendingCount),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scan),
        actions: [LanguageToggle(onChanged: widget.onLocaleChanged)],
      ),
      body: Column(
        children: [
          ListTile(
            leading: Icon(
              _status == 'online' ? Icons.cloud_done : Icons.cloud_off,
            ),
            title: Text(status),
            trailing: IconButton(
              onPressed: _sync,
              icon: const Icon(Icons.sync),
            ),
          ),
          Expanded(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),
          Text(l10n.workersStillClockedIn(_clockedInCount)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _endFieldDay,
                child: Text(l10n.endFieldDay),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
