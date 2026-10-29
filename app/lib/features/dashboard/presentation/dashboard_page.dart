import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
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
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onWorkers;
  final VoidCallback onFields;
  final VoidCallback onTechnicians;
  final VoidCallback onAdminTools;
  final VoidCallback onNotifications;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _service = AdminService();
  final _notifications = NotificationService();
  late Future<_AdminData> _data;
  Timer? _unreadTimer;
  int _unread = 0;
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    _data = _load();
    _loadUnread();
    // New reminders arrive while the page is open (the job runs every 5 min).
    _unreadTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadUnread(),
    );
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _notifications.unreadCount();
      if (mounted) setState(() => _unread = count);
    } on Object {
      // The bell just keeps its last number.
    }
  }

  Future<_AdminData> _load() async {
    return _AdminData(fieldDays: await _service.todayFieldDays());
  }

  /// Reloads the field days, and rebuilds the statistics and flagged
  /// sections (a new key makes them fetch again).
  void _refresh() => setState(() {
    _refreshCount++;
    _data = _load();
  });

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
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () {
              _refresh();
              _loadUnread();
            },
            icon: const Icon(Icons.refresh),
          ),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      body: FutureBuilder<_AdminData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorPanel(message: l10n.adminLoadError, onRetry: _refresh);
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
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
                StatsSection(
                  key: ValueKey('stats-$_refreshCount'),
                  service: _service,
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.todayFieldDays),
                ...data.fieldDays.map(
                  (row) => _FieldDayTile(
                    row: row,
                    onEnd: row['status'] == 'ended'
                        ? null
                        : () => _endFieldDay(row),
                  ),
                ),
                if (data.fieldDays.isEmpty)
                  _EmptyState(message: l10n.noFieldDays),
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.flaggedActivity),
                FlaggedSection(
                  key: ValueKey('flagged-$_refreshCount'),
                  service: _service,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.login),
                ),
              ],
            ),
          );
        },
      ),
    );
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

class _AdminData {
  const _AdminData({required this.fieldDays});
  final List<Map<String, dynamic>> fieldDays;
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
        endedAt == null
            ? l10n.ended
            : '${l10n.ended} ${formatPhTime(endedAt)}',
      ),
      'not_ended' => (Icons.warning, colors.error, l10n.notEnded),
      _ => (Icons.work, colors.secondary, l10n.working),
    };
    final count = status == 'ended'
        ? l10n.workedCount(worked)
        : l10n.clockedInCount(clockedIn);
    final sync = lastSync == null
        ? l10n.neverSynced
        : _syncLabel(lastSync, row['work_date'] as String?);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          '${row['technician_name'] ?? ''} (${row['technician_code'] ?? ''})',
        ),
        subtitle: Text(
          '${row['field_name'] ?? l10n.noField} · $label\n'
          '$count · ${l10n.lastSync}: $sync',
        ),
        isThreeLine: true,
        trailing: onEnd == null
            ? null
            : TextButton(onPressed: onEnd, child: Text(l10n.endFieldDay)),
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
