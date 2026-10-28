import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/admin_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.onLocaleChanged,
    required this.onWorkers,
    required this.onFields,
    required this.onTechnicians,
    required this.onAdminTools,
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onWorkers;
  final VoidCallback onFields;
  final VoidCallback onTechnicians;
  final VoidCallback onAdminTools;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _service = AdminService();
  late Future<_AdminData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      _service.todayFieldDays(),
      _service.statistics(),
      _service.flaggedScans(),
    ]);
    return _AdminData(
      fieldDays: results[0] as List<Map<String, dynamic>>,
      statistics: results[1] as Map<String, dynamic>,
      flags: results[2] as List<Map<String, dynamic>>,
    );
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
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
                _StatsGrid(statistics: data.statistics),
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.todayFieldDays),
                ...data.fieldDays.map(
                  (row) => _FieldDayTile(
                    row: row,
                    onEnd: row['status'] == 'working'
                        ? () => _endFieldDay(row)
                        : null,
                  ),
                ),
                if (data.fieldDays.isEmpty)
                  _EmptyState(message: l10n.noFieldDays),
                const SizedBox(height: 24),
                _SectionTitle(title: l10n.flaggedActivity),
                ...data.flags.map((row) => _FlagTile(row: row)),
                if (data.flags.isEmpty)
                  _EmptyState(message: l10n.noFlaggedActivity),
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
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.manualEndFieldDay),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.reason),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    try {
      await _service.endFieldDay(
        fieldDayId: row['field_day_id'] as String,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.fieldDayEnded)));
        _refresh();
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authError(error.message))));
      }
    }
  }
}

class _AdminData {
  const _AdminData({
    required this.fieldDays,
    required this.statistics,
    required this.flags,
  });
  final List<Map<String, dynamic>> fieldDays;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> flags;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.statistics});
  final Map<String, dynamic> statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = [
      (l10n.workersPresent, statistics['workers_present'] ?? 0, Icons.groups),
      (l10n.totalMinutes, statistics['total_minutes'] ?? 0, Icons.schedule),
      (l10n.fieldDays, statistics['field_days'] ?? 0, Icons.landscape),
      (l10n.notEnded, statistics['not_ended'] ?? 0, Icons.warning_amber),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: values
          .map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$3),
                    const Spacer(),
                    Text(
                      '${item.$2}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(item.$1),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FieldDayTile extends StatelessWidget {
  const _FieldDayTile({required this.row, required this.onEnd});
  final Map<String, dynamic> row;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ended = row['status'] == 'ended';
    return Card(
      child: ListTile(
        leading: Icon(
          ended ? Icons.check_circle : Icons.warning,
          color: ended
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
        ),
        title: Text(
          '${row['full_name'] ?? ''} (${row['technician_code'] ?? ''})',
        ),
        subtitle: Text(
          '${row['field_name'] ?? l10n.noField} · '
          '${row['open_workers'] ?? 0} ${l10n.openWorkers}',
        ),
        trailing: onEnd == null
            ? Text(ended ? l10n.ended : l10n.working)
            : TextButton(onPressed: onEnd, child: Text(l10n.endFieldDay)),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        title: Text('${row['worker_name'] ?? ''} · ${row['result'] ?? ''}'),
        subtitle: Text(
          '${row['technician_name'] ?? ''} · ${row['field_name'] ?? ''}\n'
          '${(row['flags'] as List?)?.join(', ') ?? ''}',
        ),
      ),
    );
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
