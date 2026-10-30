import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/device_service.dart';
import '../../notifications/data/notification_service.dart';
import '../../notifications/domain/notification_message.dart';
import '../data/scan_repository.dart';
import '../data/sync_service.dart';
import '../domain/clocked_out_notice.dart';
import '../domain/scan_decision.dart';
import '../domain/scan_readiness.dart';
import '../domain/sync_schedule.dart';
import 'scan_feedback.dart';
import 'scanner_banners.dart';

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

  /// How often the phone asks the server whether it is reachable (and looks
  /// for notices): often while offline, so it comes back quickly.
  static const _heartbeatOnline = Duration(seconds: 30);
  static const _heartbeatOffline = Duration(seconds: 10);

  /// A new network link needs a moment before the server can be reached.
  static const _linkSettle = Duration(seconds: 2);
  static const _reachTimeout = Duration(seconds: 5);

  final _database = AppDatabase.defaults();
  final _scannerController = MobileScannerController(autoStart: false);
  final _notificationService = NotificationService();
  final _devices = DeviceService();
  late final ScanRepository _repository;
  late final SyncService _syncService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _feedbackTimer;
  Timer? _retryTimer;
  Timer? _heartbeat;
  Timer? _linkTimer;
  bool _checking = false;

  /// Set once the technician has been logged out (by themselves or because
  /// the admin turned the account or this phone off). Nothing runs after that.
  bool _leaving = false;
  final _throttle = SyncThrottle();
  List<AppNotification> _notices = const [];
  final _dismissedNotices = <String>{};

  /// Workers another technician took over, with the moment up to which this
  /// phone's own scans of them no longer count (migration 019): the next scan
  /// of such a worker is a clock in, never a clock out.
  Map<String, DateTime> _takenOver = const {};

  /// One line for each scan the server refused, until the technician closes it.
  List<String> _refused = const [];
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
      final linked = results.any((result) => result != ConnectivityResult.none);
      if (!linked) {
        if (mounted) setState(() => _status = 'offline');
        return;
      }
      // A wifi or mobile link exists, which does not mean the internet works.
      // Ask the server before saying Online.
      _linkTimer?.cancel();
      _linkTimer = Timer(_linkSettle, () {
        if (mounted) unawaited(_checkConnection(fullSync: true));
      });
    });
    _scheduleHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _retryTimer?.cancel();
    _heartbeat?.cancel();
    _linkTimer?.cancel();
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
      unawaited(_checkConnection());
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
    if (_leaving ||
        (_readiness == ScanReadiness.loading && _contextRequested)) {
      return;
    }
    _contextRequested = true;
    if (mounted) setState(() => _readiness = ScanReadiness.loading);
    try {
      await _devices.register(label: _deviceLabel());
      final response = await _devices.context();
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
        // Show this phone's own count at once; the sync replaces it with the
        // server's when it can.
        unawaited(_refreshClockedIn());
        await _sync();
      } else {
        setState(() {
          _scanContext = null;
          _readiness = readiness;
        });
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;
      if (endsSession(error.message)) {
        unawaited(_leave(notice: error.message));
        return;
      }
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
    final count = await _pendingForMe();
    if (mounted) setState(() => _pendingCount = count);
  }

  /// Scans and events of the signed-in technician waiting to upload.
  Future<int> _pendingForMe() => _database.pendingCount(technicianId: _myId);

  /// The signed-in technician (the profile ID is the sign-in ID).
  String? get _myId =>
      _scanContext?.technicianId ??
      Supabase.instance.client.auth.currentUser?.id;

  /// The sync button: load the field first if the app does not have it yet.
  /// A tap on the button always syncs now; automatic calls are spaced out.
  Future<void> _syncOrLoad({bool force = false}) =>
      _scanContext == null ? _loadContext() : _sync(force: force);

  void _scheduleHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer(
      _status == 'offline' ? _heartbeatOffline : _heartbeatOnline,
      () async {
        await _checkConnection();
        if (mounted && !_leaving) _scheduleHeartbeat();
      },
    );
  }

  /// Logs the technician out and returns to the login page. [notice] is the
  /// reason the login page shows (the admin turned the account or this phone
  /// off); null when the technician chose to log out. Scans still waiting to
  /// upload stay in the phone's database.
  Future<void> _leave({String? notice}) async {
    if (_leaving) return;
    _leaving = true;
    _retryTimer?.cancel();
    _heartbeat?.cancel();
    _linkTimer?.cancel();
    _feedbackTimer?.cancel();
    if (mounted) setState(() => _scanContext = null);
    try {
      await _scannerController.stop();
    } on Object {
      // Already stopped.
    }
    await AuthService().signOut(notice: notice);
    if (mounted) context.go('/login');
  }

  /// The log-out button. Waiting scans are not lost, but say so first.
  Future<void> _logOut() async {
    final waiting = await _pendingForMe();
    if (!mounted) return;
    if (waiting > 0) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.logOutWithPending(waiting)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.logOut),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _leave();
  }

  /// Asks the server whether this technician and this phone are still allowed.
  /// The admin can turn either off while the technician is logged in; the
  /// answer is an error code (see [endsSession]). Returns false when scanning
  /// must stop. An unreachable server says nothing, so scanning goes on.
  Future<bool> _checkAccess() async {
    try {
      final response = await _devices.context().timeout(_reachTimeout);
      final readiness = readinessFromContext(response);
      if (readiness == ScanReadiness.ready || !mounted) return true;
      setState(() {
        _scanContext = null;
        _readiness = readiness;
      });
      return false;
    } on PostgrestException catch (error) {
      if (!mounted) return false;
      if (endsSession(error.message)) {
        unawaited(_leave(notice: error.message));
        return false;
      }
      final readiness = readinessFromCode(error.message);
      if (readiness == ScanReadiness.offline) return true;
      setState(() {
        _scanContext = null;
        _readiness = readiness;
      });
      return false;
    } on Object {
      return true;
    }
  }

  /// Asks the server for a real answer. A wifi or mobile link only says the
  /// phone is connected to a network, not that the internet works. An error
  /// answer from the server still means it was reached.
  Future<bool> _reachServer() async {
    try {
      await Supabase.instance.client
          .rpc<dynamic>('ping')
          .timeout(_reachTimeout);
      return true;
    } on PostgrestException {
      return true;
    } on Object {
      return false;
    }
  }

  /// Decides Online or Offline from a real request, then does what is due:
  /// load the field if it is missing, upload waiting scans, or just look for
  /// notices. [fullSync] also refreshes the worker list (a network came back).
  Future<void> _checkConnection({bool fullSync = false}) async {
    if (_checking || _syncing || _leaving) return;
    _checking = true;
    try {
      final reachable = await _reachServer();
      if (!mounted) return;
      if (!reachable) {
        setState(() => _status = 'offline');
        return;
      }
      if (_status == 'offline') setState(() => _status = 'online');
      // Not ready (a phone waiting for approval, no field, a failed first
      // load): look again, so it recovers once the admin has fixed it.
      if (_scanContext == null) {
        if (_readiness != ScanReadiness.loading) await _loadContext();
        return;
      }
      // The admin may have turned this account or phone off meanwhile.
      if (!await _checkAccess()) return;
      if (fullSync || await _pendingForMe() > 0) {
        await _sync();
      } else {
        await _checkNotices();
      }
    } finally {
      _checking = false;
    }
  }

  /// Another technician's scan can clock out a worker who is clocked in on this
  /// phone (SPEC.md section 2). The database leaves a notice; show it here
  /// until the technician closes it, and fix the clocked-in count.
  Future<void> _checkNotices() async {
    if (_scanContext == null) return;
    try {
      final all = await _notificationService.list(limit: 20);
      final shown = unreadClockedOutNotices(all, dismissed: _dismissedNotices);
      // Read notices count too: a worker taken over stays with the other
      // technician after this one has closed the banner.
      final takenOver = takenOverCutoffs(all);
      if (!mounted) return;
      final isNew = shown.any((n) => !_notices.any((old) => old.id == n.id));
      final changed = !mapEquals(takenOver, _takenOver);
      setState(() {
        _notices = shown;
        _takenOver = takenOver;
      });
      if (isNew || changed) await _updateClockedIn();
    } on Object {
      // Offline or not ready: the next check tries again.
    }
  }

  /// The server refused these scans after the phone had shown them as saved
  /// (for example a worker another technician holds). Say so, with the
  /// worker's name, until the technician closes the message.
  Future<void> _showRefused(List<RefusedScan> refused) async {
    if (refused.isEmpty || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final lines = <String>[];
    for (final scan in refused) {
      final worker = await _database.findWorker(scan.workerId);
      lines.add(l10n.scanRefused(worker?.name ?? scan.workerId, scan.result));
    }
    if (mounted) setState(() => _refused = [..._refused, ...lines]);
  }

  Future<void> _dismissNotices() async {
    final closing = _notices;
    setState(() {
      _dismissedNotices.addAll(closing.map((n) => n.id));
      _notices = const [];
    });
    for (final notice in closing) {
      try {
        await _notificationService.markRead(notice.id);
      } on Object {
        // Still hidden on this phone; the next dismissal marks it read.
      }
    }
  }

  /// The number of workers still clocked in. The server knows about workers
  /// closed on another phone, so ask it when nothing is waiting to upload.
  /// With scans waiting, or no connection, count this phone's own scans.
  Future<int> _updateClockedIn() async {
    if (_scanContext != null && await _pendingForMe() == 0) {
      try {
        final count = await _syncService.fetchClockedInCount().timeout(
          _reachTimeout,
        );
        if (mounted) setState(() => _clockedInCount = count);
        return count;
      } on Object {
        // Fall back to the local count below.
      }
    }
    await _refreshClockedIn();
    return _clockedInCount;
  }

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
      takenOver: _takenOver,
    );
    if (mounted) setState(() => _clockedInCount = count);
  }

  /// Uploads waiting scans (CONTRACT.md section 8). Automatic runs are at
  /// least [minSyncInterval] apart, and a failed run is retried after
  /// 30 s, 1 min, 2 min, then every 5 min while something is waiting.
  Future<void> _sync({bool force = false}) async {
    if (_syncing || _scanContext == null || _leaving) return;
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
      final summary = await _syncService.sync();
      _syncFailures = 0;
      await _showRefused(summary.refused);
      await _refreshPendingCount();
      await _updateClockedIn();
      if (mounted) setState(() => _status = 'online');
      unawaited(_checkNotices());
    } on PostgrestException catch (error) {
      if (!mounted) return;
      if (isBatchLevelError(error.message)) {
        // The server answered, so the phone is online. Stop the loop and tell
        // the technician why (CONTRACT.md section 8).
        _syncFailures = 0;
        if (endsSession(error.message)) {
          // The admin turned this account or this phone off: log out, so no
          // further scan is taken.
          unawaited(_leave(notice: error.message));
          return;
        }
        // Waiting for approval and the like: scanning stops, and the heartbeat
        // looks again until the admin has fixed it.
        setState(() {
          _status = 'online';
          _scanContext = null;
          _readiness = readinessFromCode(error.message);
        });
      } else {
        setState(() => _status = 'offline');
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

  /// Tries again after a failed run, even when nothing is waiting: the worker
  /// list and the notices also need the server, and a phone that failed once
  /// must not stay Offline until the technician scans.
  Future<void> _scheduleRetry() async {
    _syncFailures++;
    await _refreshPendingCount();
    _scheduleSync(retryDelay(_syncFailures));
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
    if (_busy || !_cameraOn || _leaving) return;
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
        takenOver: _takenOver,
      );
      if (!mounted) return;
      _setFeedback(_feedbackFor(result, AppLocalizations.of(context)));
      if (result.outcome == ScanOutcome.saved) {
        await _refreshPendingCount();
        await _refreshClockedIn();
        // Upload soon, but not more than once every 30 seconds.
        unawaited(_sync());
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
    // Ask the server when it can answer: a worker clocked out on another phone
    // is no longer counted, which this phone's own scans cannot know.
    final count = await _updateClockedIn();
    final waiting = await _database.pendingScanCount(technicianId: _myId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final time = formatPhTime(DateTime.now().toUtc());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endFieldDay),
        content: SingleChildScrollView(
          child: Column(
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
        actions: [
          LanguageToggle(onChanged: widget.onLocaleChanged),
          IconButton(
            tooltip: l10n.workerLookup,
            onPressed: () => context.push('/technician/worker-lookup'),
            icon: const Icon(Icons.person_search),
          ),
          IconButton(
            tooltip: l10n.logOut,
            onPressed: _logOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ScannerLayout(
        status: ListTile(
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
        banners: ScannerBanners(
          closeLabel: l10n.close,
          retryLabel: l10n.retry,
          readinessMessage: notReady && _readiness != ScanReadiness.loading
              ? feedbackForReadiness(l10n, _readiness).message
              : null,
          onRetry: _loadContext,
          refused: _refused,
          onCloseRefused: () => setState(() => _refused = const []),
          notices: [
            for (final notice in _notices)
              notificationText(l10n, notice.type, notice.params),
          ],
          onCloseNotices: _dismissNotices,
        ),
        camera: Stack(
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
        footer: [
          ScanFeedbackBanner(feedback: feedback),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cameraOn ? _closeCamera : _openCamera,
                icon: Icon(_cameraOn ? Icons.videocam_off : Icons.videocam),
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
