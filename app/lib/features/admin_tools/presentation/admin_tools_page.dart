import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/admin_tools_service.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  final _service = AdminToolsService();
  List<Map<String, dynamic>> _masterlist = [];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTools),
        actions: [LanguageToggle(onChanged: widget.onLocaleChanged)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.settings, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _SettingButton(
            label: l10n.scanHoursStart,
            onPressed: () => _setTime('scan_hours_start', l10n),
          ),
          _SettingButton(
            label: l10n.scanHoursEnd,
            onPressed: () => _setTime('scan_hours_end', l10n),
          ),
          _SettingButton(
            label: l10n.reminderTime,
            onPressed: () => _setTime('reminder_time', l10n),
          ),
          const Divider(height: 32),
          Text(
            l10n.manualTimeRecord,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.manualTimeRecordHint),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _showManualRecord(l10n),
            icon: const Icon(Icons.edit_calendar),
            label: Text(l10n.addTimeRecord),
          ),
          const Divider(height: 32),
          Text(
            l10n.weeklyMasterlist,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadMasterlist,
            icon: const Icon(Icons.download),
            label: Text(l10n.loadMasterlist),
          ),
          for (final row in _masterlist)
            ListTile(
              dense: true,
              title: Text('${row['worker_name']} • ${row['work_date']}'),
              subtitle: Text(
                '${row['technician_name']} / ${row['field_name']} • '
                '${row['minutes']} min',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setTime(String key, AppLocalizations l10n) async {
    final controller = TextEditingController(text: '17:00');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.timeFormat),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return;
    try {
      await _service.setSetting(key, value);
    } on Object {
      if (mounted) _showError(l10n);
    }
  }

  Future<void> _loadMasterlist() async {
    setState(() => _busy = true);
    try {
      final rows = await _service.weeklyMasterlist();
      if (mounted) setState(() => _masterlist = rows);
    } on Object {
      if (mounted) _showError(AppLocalizations.of(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showManualRecord(AppLocalizations l10n) async {
    final worker = TextEditingController();
    final field = TextEditingController();
    final technician = TextEditingController();
    final date = TextEditingController(text: '2026-10-28');
    final timeIn = TextEditingController(text: '08:00');
    final timeOut = TextEditingController(text: '17:00');
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addTimeRecord),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (final entry in {
                l10n.workerId: worker,
                l10n.fieldId: field,
                l10n.technicianId: technician,
                l10n.workDate: date,
                l10n.timeIn: timeIn,
                l10n.timeOut: timeOut,
                l10n.reason: reason,
              }.entries)
                TextField(
                  controller: entry.value,
                  decoration: InputDecoration(labelText: entry.key),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final dateValue = DateTime.parse(date.text);
                final inValue = _parseTime(dateValue, timeIn.text);
                final outValue = _parseTime(dateValue, timeOut.text);
                await _service.addTimeRecord(
                  workerId: worker.text.trim(),
                  fieldId: field.text.trim(),
                  technicianId: technician.text.trim(),
                  workDate: dateValue,
                  timeIn: inValue,
                  timeOut: outValue,
                  reason: reason.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } on Object {
                if (context.mounted) _showError(l10n);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    for (final controller in [
      worker,
      field,
      technician,
      date,
      timeIn,
      timeOut,
      reason,
    ]) {
      controller.dispose();
    }
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.saved)));
    }
  }

  DateTime _parseTime(DateTime date, String value) {
    final parts = value.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void _showError(AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.adminToolsOperationFailed)));
  }
}

class _SettingButton extends StatelessWidget {
  const _SettingButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: IconButton(onPressed: onPressed, icon: const Icon(Icons.edit)),
    );
  }
}
