import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/worker_week_service.dart';

class WorkerLookupPage extends StatefulWidget {
  const WorkerLookupPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<WorkerLookupPage> createState() => _WorkerLookupPageState();
}

class _WorkerLookupPageState extends State<WorkerLookupPage> {
  final _workerId = TextEditingController();
  final _service = WorkerWeekService();
  WorkerWeek? _week;
  bool _busy = false;

  @override
  void dispose() {
    _workerId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final week = _week;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workerLookup),
        actions: [LanguageToggle(onChanged: widget.onLocaleChanged)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _workerId,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l10n.lookupWorkerId),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.search),
            label: Text(l10n.loadWorkerWeek),
          ),
          if (week != null) ...[
            const SizedBox(height: 24),
            Text(
              '${week.name} (${week.workerId})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${week.weekStart} - ${week.weekEnd}'),
            const SizedBox(height: 12),
            for (final day in week.days)
              ListTile(
                title: Text(
                  MaterialLocalizations.of(context).formatFullDate(day.date),
                ),
                trailing: Text(
                  workerWeekDayLabel(day.date, day.minutes, l10n.notEndedCell),
                ),
              ),
            const Divider(),
            ListTile(
              title: Text(l10n.totalMinutes),
              trailing: Text(formatMinutes(week.totalMinutes)),
            ),
            ListTile(
              title: Text(l10n.workedCount(week.presentDays)),
              trailing: Text('${week.presentDays}'),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(l10n.noWorkerWeek),
            ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    if (_workerId.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _week = null;
    });
    try {
      final week = await _service.load(_workerId.text);
      if (mounted) setState(() => _week = week);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.authError(error.message))));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminToolsOperationFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
