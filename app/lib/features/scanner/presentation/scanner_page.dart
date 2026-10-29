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
import '../domain/sync_schedule.dart';
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
  Timer? _retryTimer;
  final _throttle = SyncThrottle();
  int _syncFailures = 0;
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
    _retryTimer?.cancel();
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
  /// A tap on the button always syncs now; automatic calls are spaced out.
  Future<void> _syncOrLoad({bool force = false}) =>
      _scanContext == null ? _loadContext() : _sync(force: force);

  void _scheduleSync(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (mounted) _sync();
    });
  }

  /// Workers still clocked in on this phone today, after the last End field
  /// day. Used offline and while scans are waiting to upload.
  Future<void> _refreshClockedIn() async {
    final scanContext = _scanContext;
    if (scanContext == null) return;
    final dayStart = phTimeToUtc(phDateOf(DateTime.now()), 0, 0);
    final count = await _database.clockedInCount(
      scanContext.technicianId,
      dayStart,
    );
    if (mounted) setState(() => _clockedInCount = count);
  }

  /// Uploads waiting scans (CONTRACT.md section 8). Automatic runs are at
  /// least [minSyncInterval] apart, and a failed run is retried after
  /// 30 s, 1 min, 2 min, then every 5 min while something is waiting.
  Future<void> _sync({bool force = false}) async {
    if (_syncing || _scanContext == null) return;
    if (!force) {
      final wait = _throttle.remaining(DateTime.now());
      if (wait > Duration.zero) {
        _scheduleSync(wait);
        return;
      }
    }
    _retryTimer?.cancel();
    _syncing = true;
    _throttle.markStarted(DateTime.now());
    if (mounted) setState(() => _status = 'syncing');
    try {
      await _syncService.sync();
      _syncFailures = 0;
      await _refreshPendingCount();
      if (_pendingCount == 0) {
        try {
          final serverCount = await _syncService.fetchClockedInCount();
          if (mounted) setState(() => _clockedInCount = serverCount);
        } catch (_) {
          await _refreshClockedIn();
        }
      } else {
        await _refreshClockedIn();
      }
      if (mounted) setState(() => _status = 'online');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'offline');
      if (isBatchLevelError(error.message)) {
        // Stop the loop and tell the technician why (CONTRACT.md section 8).
        _syncFailures = 0;
        setState(() => _readiness = readinessFromCode(error.message));
      } else {
        await _scheduleRetry();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'offline');
      await _scheduleRetry();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _scheduleRetry() async {
    _syncFailures++;
    await _refreshPendingCount();
    if (_pendingCount > 0) _scheduleSync(retryDelay(_syncFailures));
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
        await _refreshClockedIn();
        // Upload soon, but not more than once every 30 seconds.
        if (_status != 'offline') unawaited(_sync());
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

  /// "Clock out 5 workers at 4:52 PM?" with a warning, that does not block,
  /// when scans are still waiting to upload (SPEC.md section 7).
  Future<void> _endFieldDay() async {
    await _refreshClockedIn();
    final waiting = await _database.pendingScanCount();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final count = _clockedInCount;
    final time = formatPhTime(DateTime.now().toUtc());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endFieldDay),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                color: colors.secondary,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.scansNotUploaded(waiting))),
                  ],
                ),
              ),
            Text(l10n.endFieldDayConfirm(count, time)),
          ],
        ),
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
    await _refreshClockedIn();
    await _sync(force: true);
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
              onPressed: () => _syncOrLoad(force: true),
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
