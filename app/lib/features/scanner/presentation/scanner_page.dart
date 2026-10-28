import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../auth/data/device_service.dart';
import '../data/scan_repository.dart';
import '../data/sync_service.dart';
import '../domain/scan_decision.dart';
import '../domain/scan_readiness.dart';
import 'scan_feedback.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  /// The same unreadable or repeated text is not handled again for this long,
  /// so the screen does not flash on every camera frame.
  static const _frameCooldown = Duration(seconds: 2);
  static const _feedbackDuration = Duration(seconds: 4);

  final _database = AppDatabase.defaults();
  final _scannerController = MobileScannerController(autoStart: false);
  late final ScanRepository _repository;
  late final SyncService _syncService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _feedbackTimer;
  ScanContext? _scanContext;
  ScanReadiness _readiness = ScanReadiness.loading;
  bool _contextRequested = false;
  String _status = 'offline';
  bool _busy = false;
  bool _syncing = false;
  bool _cameraOn = false;
  bool _askedForLocation = false;
  String? _lastRaw;
  DateTime? _lastRawAt;
  ScanFeedback _feedback = const ScanFeedback.idle();
  int _pendingCount = 0;
  int _clockedInCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = ScanRepository(_database);
    _syncService = SyncService(database: _database);
    _loadContext();
    _refreshPendingCount();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) _syncOrLoad();
      if (mounted) setState(() => _status = online ? 'online' : 'offline');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _connectivitySubscription?.cancel();
    _scannerController.dispose();
    _database.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Free the camera while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      if (_cameraOn) _startController();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _scannerController.stop();
    }
  }

  Future<void> _openCamera() async {
    if (!mounted) return;
    setState(() => _cameraOn = true);
    await _startController();
  }

  Future<void> _closeCamera() async {
    setState(() {
      _cameraOn = false;
      _feedback = const ScanFeedback.idle();
    });
    _feedbackTimer?.cancel();
    try {
      await _scannerController.stop();
    } on Object {
      // Already stopped.
    }
  }

  Future<void> _startController() async {
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // The camera panel shows the error from the controller state.
      if (mounted) setState(() {});
    } on Object {
      if (mounted) setState(() {});
    }
  }

  /// Registers this phone (first phone is approved at once, CONTRACT.md 4.2),
  /// then loads the technician and field. Any problem is shown to the
  /// technician instead of being ignored.
  Future<void> _loadContext() async {
    if (_readiness == ScanReadiness.loading && _contextRequested) return;
    _contextRequested = true;
    if (mounted) setState(() => _readiness = ScanReadiness.loading);
    try {
      final devices = DeviceService();
      await devices.register(label: _deviceLabel());
      final response = await devices.context();
      if (!mounted) return;
      final readiness = readinessFromContext(response);
      if (readiness == ScanReadiness.ready) {
        final profile = response['profile'] as Map;
        final field = response['field'] as Map;
        setState(() {
          _scanContext = ScanContext(
            technicianId: profile['id'] as String,
            fieldId: field['id'] as String,
          );
          _readiness = readiness;
        });
        await _sync();
      } else {
        setState(() {
          _scanContext = null;
          _readiness = readiness;
        });
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _scanContext = null;
        _readiness = readinessFromCode(error.message);
        _status = 'offline';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanContext = null;
        _readiness = ScanReadiness.offline;
        _status = 'offline';
      });
    } finally {
      _contextRequested = false;
    }
  }

  String _deviceLabel() =>
      kIsWeb ? 'Web browser' : '${defaultTargetPlatform.name} phone';

  Future<void> _refreshPendingCount() async {
    final count = await _database.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  /// The sync button: load the field first if the app does not have it yet.
  Future<void> _syncOrLoad() => _scanContext == null ? _loadContext() : _sync();

  Future<void> _sync() async {
    if (_syncing || _scanContext == null) return;
    _syncing = true;
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
    } finally {
      _syncing = false;
    }
  }

  Future<Position?> _position() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !_askedForLocation) {
        _askedForLocation = true;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 3),
        ),
      );
    } on Object {
      // Scanning never stops because location is missing (SPEC section 17).
      return null;
    }
  }

  void _setFeedback(ScanFeedback feedback, {bool autoClear = true}) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() => _feedback = feedback);
    if (autoClear) {
      _feedbackTimer = Timer(_feedbackDuration, () {
        if (mounted) setState(() => _feedback = const ScanFeedback.idle());
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Set at once, before any await, so two camera frames cannot both run.
    if (_busy || !_cameraOn) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final now = DateTime.now().toUtc();
    final lastAt = _lastRawAt;
    if (raw == _lastRaw &&
        lastAt != null &&
        now.difference(lastAt) < _frameCooldown) {
      return;
    }
    _busy = true;
    _lastRaw = raw;
    _lastRawAt = now;
    final l10n = AppLocalizations.of(context);
    try {
      _setFeedback(
        ScanFeedback(ScanFeedbackKind.detected, l10n.scanDetected),
        autoClear: false,
      );
      final scanContext = _scanContext;
      if (scanContext == null) {
        // Say why scanning is not ready instead of a generic message.
        _setFeedback(feedbackForReadiness(l10n, _readiness));
        return;
      }
      final result = await _repository.processScan(
        context: scanContext,
        rawValue: raw,
        now: now,
        position: _position,
      );
      if (!mounted) return;
      _setFeedback(_feedbackFor(result, AppLocalizations.of(context)));
      if (result.outcome == ScanOutcome.saved) {
        await _refreshPendingCount();
      } else if (result.outcome == ScanOutcome.badCard) {
        // The worker list may be out of date after a reissued card.
        unawaited(_sync());
      }
    } finally {
      _busy = false;
    }
  }

  ScanFeedback _feedbackFor(ScanResult result, AppLocalizations l10n) {
    final name = result.worker?.name ?? '';
    return switch (result.outcome) {
      ScanOutcome.saved => ScanFeedback(
        ScanFeedbackKind.success,
        result.direction == LocalDirection.clockOut
            ? l10n.clockedOutAt(name, formatPhTime(result.at!))
            : l10n.clockedInAt(name, formatPhTime(result.at!)),
      ),
      ScanOutcome.repeat => ScanFeedback(
        ScanFeedbackKind.attention,
        l10n.scanRepeat,
      ),
      ScanOutcome.invalid => ScanFeedback(
        ScanFeedbackKind.error,
        l10n.invalidQr,
      ),
      ScanOutcome.workerNotCached => ScanFeedback(
        ScanFeedbackKind.error,
        l10n.workerNotCached,
      ),
      ScanOutcome.badCard => ScanFeedback(
        ScanFeedbackKind.error,
        l10n.scanBadCard,
      ),
      ScanOutcome.inactive => ScanFeedback(
        ScanFeedbackKind.error,
        l10n.scanInactive,
      ),
    };
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
    final notReady = _readiness != ScanReadiness.ready;
    final ScanFeedback feedback;
    if (!_cameraOn) {
      feedback = ScanFeedback(ScanFeedbackKind.idle, l10n.cameraOff);
    } else if (_feedback.kind != ScanFeedbackKind.idle) {
      feedback = _feedback;
    } else if (notReady) {
      // Never say "Looking for a QR code" while scanning cannot work.
      feedback = feedbackForReadiness(l10n, _readiness);
    } else {
      feedback = ScanFeedback(ScanFeedbackKind.idle, l10n.scanLooking);
    }
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
              tooltip: l10n.syncing,
              onPressed: _syncOrLoad,
              icon: const Icon(Icons.sync),
            ),
          ),
          if (notReady && _readiness != ScanReadiness.loading)
            MaterialBanner(
              content: Text(feedbackForReadiness(l10n, _readiness).message),
              actions: [
                TextButton(onPressed: _loadContext, child: Text(l10n.retry)),
              ],
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) =>
                      CameraErrorPanel(onRetry: _startController),
                ),
                if (!_cameraOn) const CameraOffPanel(),
                if (_cameraOn) ScanFrame(kind: feedback.kind),
              ],
            ),
          ),
          ScanFeedbackBanner(feedback: feedback),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cameraOn ? _closeCamera : _openCamera,
                icon: Icon(
                  _cameraOn ? Icons.videocam_off : Icons.videocam,
                ),
                label: Text(_cameraOn ? l10n.cameraClose : l10n.cameraOpen),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.workersStillClockedIn(_clockedInCount)),
          ),
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
