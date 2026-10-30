import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../core/utils/refresh_group.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../shared/widgets/refresh_button.dart';
import '../../auth/data/auth_service.dart';
import '../../notifications/data/notification_service.dart';
import '../data/admin_service.dart';
import 'end_field_day_dialog.dart';
import 'flagged_section.dart';
import 'stats_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.onLocaleChanged,
    required this.onWorkers,
    required this.onFields,
    required this.onTechnicians,
    required this.onAdminTools,
    required this.onNotifications,
    this.service,
    super.key,
  });

  /// Only tests pass one; the app talks to Supabase.
  final AdminService? service;

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onWorkers;
  final VoidCallback onFields;
  final VoidCallback onTechnicians;
  final VoidCallback onAdminTools;
  final VoidCallback onNotifications;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  /// Technicians sync their scans all day, so the numbers are fetched again
  /// this often while the page is on screen.
  static const _pollEvery = Duration(seconds: 15);

  late final AdminService _service = widget.service ?? AdminService();
  final _notifications = NotificationService();
  List<Map<String, dynamic>>? _fieldDays;
  bool _loadFailed = false;
  Timer? _poll;
  int _unread = 0;

  /// Tells the statistics and flagged sections to fetch again, without
  /// rebuilding them (so Daily / Weekly and the dates stay as they are).
  final _sections = RefreshGroup();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadUnread();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On the web this follows the browser tab: no fetching while it is hidden,
    // and an immediate refresh when the admin comes back to it. A window that
    // only lost focus (inactive) keeps updating: the admin may be watching it
    // next to a phone.
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPolling();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollEvery, (_) => _refresh());
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _notifications.unreadCount();
      if (mounted) setState(() => _unread = count);
    } on Object {
      // The bell just keeps its last number.
    }
  }

  /// A failed fetch keeps the rows already on screen; the error panel only
  /// shows when there is nothing to show.
  Future<void> _load() async {
    try {
      final rows = await _service.todayFieldDays();
      if (mounted) {
        setState(() {
          _fieldDays = rows;
          _loadFailed = false;
        });
      }
    } on Object {
      if (mounted && _fieldDays == null) setState(() => _loadFailed = true);
    }
  }

  /// Fetches everything again without clearing the screen first. Completes
  /// when all of it has arrived (the refresh button turns until then).
  Future<void> _refresh() =>
      Future.wait<void>([_sections.run(), _loadUnread(), _load()]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          IconButton(
            tooltip: l10n.notifications,
            onPressed: widget.onNotifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications),
            ),
          ),
          RefreshButton(tooltip: l10n.refresh, onRefresh: _refresh),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      body: _body(l10n),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final fieldDays = _fieldDays;
    final today = formatPhDate(phDateOf(DateTime.now()));
    if (fieldDays == null) {
      return _loadFailed
          ? _ErrorPanel(message: l10n.adminLoadError, onRetry: _refresh)
          : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: widget.onWorkers,
            icon: const Icon(Icons.groups),
            label: Text(l10n.manageWorkers),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onFields,
            icon: const Icon(Icons.location_on),
            label: Text(l10n.manageFields),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onTechnicians,
            icon: const Icon(Icons.badge),
            label: Text(l10n.manageTechnicians),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onAdminTools,
            icon: const Icon(Icons.admin_panel_settings),
            label: Text(l10n.adminTools),
          ),
          const SizedBox(height: 16),
          StatsSection(service: _service, refresh: _sections),
          const SizedBox(height: 24),
          _SectionTitle(title: l10n.todayFieldDays),
          if (fieldDays.any((row) => row['work_date'] != today))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.oldFieldDaysHint),
            ),
          ...fieldDays.map(
            (row) => _FieldDayTile(
              row: row,
              onEnd: row['status'] == 'ended' ? null : () => _endFieldDay(row),
            ),
          ),
          if (fieldDays.isEmpty) _EmptyState(message: l10n.noFieldDays),
          const SizedBox(height: 24),
          _SectionTitle(title: l10n.flaggedActivity),
          FlaggedSection(service: _service, refresh: _sections),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logOut,
            icon: const Icon(Icons.logout),
            label: Text(l10n.logOut),
          ),
        ],
      ),
    );
  }

  Future<void> _logOut() async {
    await AuthService().signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _endFieldDay(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final technicianId = row['technician_id'] as String;
    final workDate = row['work_date'] as String;
    try {
      final suggested = await _service.suggestEndTime(
        technicianId: technicianId,
        workDate: workDate,
      );
      if (!mounted) return;
      final choice = await showDialog<EndFieldDayChoice>(
        context: context,
        builder: (context) => EndFieldDayDialog(
          workDate: DateTime.parse('${workDate}T00:00:00Z'),
          suggested: suggested,
        ),
      );
      if (choice == null || !mounted) return;
      await _service.endFieldDay(
        technicianId: technicianId,
        workDate: workDate,
        endedAt: choice.endedAt,
        reason: choice.reason,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.fieldDayEnded)));
      if (mounted) _refresh();
    } on PostgrestException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminError(error.message))),
      );
    } on AuthException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.authError(error.message))),
      );
    }
  }
}

class _FieldDayTile extends StatelessWidget {
  const _FieldDayTile({required this.row, required this.onEnd});
  final Map<String, dynamic> row;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = row['status'] as String? ?? 'working';
    final colors = Theme.of(context).colorScheme;
    final endedAt = DateTime.tryParse('${row['ended_at'] ?? ''}');
    final lastSync = DateTime.tryParse('${row['last_sync_at'] ?? ''}');
    final clockedIn = (row['clocked_in_count'] as num?)?.toInt() ?? 0;
    final worked = (row['worked_count'] as num?)?.toInt() ?? 0;
    final (icon, color, label) = switch (status) {
      'ended' => (
        Icons.check_circle,
        colors.primary,
        endedAt == null ? l10n.ended : '${l10n.ended} ${formatPhTime(endedAt)}',
      ),
      'not_ended' => (Icons.warning, colors.error, l10n.notEnded),
      _ => (Icons.work, colors.secondary, l10n.working),
    };
    final count = status == 'ended'
        ? l10n.workedCount(worked)
        : l10n.clockedInCount(clockedIn);
    final workDate = row['work_date'] as String?;
    final isOld =
        workDate != null && workDate != formatPhDate(phDateOf(DateTime.now()));
    final sync = lastSync == null
        ? l10n.neverSynced
        : _syncLabel(lastSync, row['work_date'] as String?);
    final theme = Theme.of(context);
    // Laid out by hand rather than as a ListTile: the End field day button as
    // the tile's trailing widget took the whole width on a 320 px screen with
    // larger text, which Flutter refuses to lay out.
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['technician_name'] ?? ''} '
                        '(${row['technician_code'] ?? ''})',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // An earlier day that was never ended says which day
                        // it was.
                        '${isOld ? '$workDate · ' : ''}'
                        '${row['field_name'] ?? l10n.noField} · $label\n'
                        '$count · ${l10n.lastSync}: $sync',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onEnd != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onEnd,
                  child: Text(l10n.endFieldDay),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Time for today's syncs, date and time for older ones.
  String _syncLabel(DateTime syncUtc, String? workDate) {
    final time = formatPhTime(syncUtc);
    final syncDate = formatPhDate(phDateOf(syncUtc));
    return syncDate == workDate ? time : '$syncDate $time';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    ),
  );
}
