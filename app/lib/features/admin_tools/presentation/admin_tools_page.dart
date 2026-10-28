import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
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
  Map<String, String> _times = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadTimes();
  }

  Future<void> _loadTimes() async {
    try {
      final times = await _service.timeSettings();
      if (mounted) setState(() => _times = times);
    } on Object {
      // The rows show "Not set"; editing still works.
    }
  }

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
            value: _timeLabel('scan_hours_start', l10n),
            onPressed: () => _setTime('scan_hours_start', l10n),
          ),
          _SettingButton(
            label: l10n.scanHoursEnd,
            value: _timeLabel('scan_hours_end', l10n),
            onPressed: () => _setTime('scan_hours_end', l10n),
          ),
          _SettingButton(
            label: l10n.reminderTime,
            value: _timeLabel('reminder_time', l10n),
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

  String _timeLabel(String key, AppLocalizations l10n) {
    final text = formatClock12(_times[key]);
    return text.isEmpty ? l10n.timeNotSet : text;
  }

  /// A 12-hour (AM/PM) time picker, whatever the phone's 24-hour setting is.
  Future<TimeOfDay?> _pickTime(
    AppLocalizations l10n,
    TimeOfDay initial,
  ) {
    return showTimePicker(
      context: context,
      helpText: l10n.pickTime,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
  }

  Future<void> _setTime(String key, AppLocalizations l10n) async {
    final current = parseClock24(_times[key]);
    final picked = await _pickTime(
      l10n,
      current == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    final value = formatClock24(picked.hour, picked.minute);
    try {
      await _service.setSetting(key, value);
      // Read it back: "Saved" is shown only if the database really has it.
      final stored = await _service.timeSettings();
      if (!mounted) return;
      setState(() => _times = stored.isEmpty ? {..._times, key: value} : stored);
      if (stored.isNotEmpty && stored[key] != value) {
        _showError(l10n);
        return;
      }
      _showMessage(l10n.saved);
    } on PostgrestException catch (error) {
      debugPrint('admin_set_setting $key failed: ${error.message}');
      if (mounted) _showMessage(l10n.adminError(error.message));
    } on Object catch (error) {
      debugPrint('admin_set_setting $key failed: $error');
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
    final date = TextEditingController(
      text: formatPhDate(phDateOf(DateTime.now())),
    );
    final reason = TextEditingController();
    var timeIn = const TimeOfDay(hour: 8, minute: 0);
    var timeOut = const TimeOfDay(hour: 17, minute: 0);
    String label(TimeOfDay time) =>
        formatClock12(formatClock24(time.hour, time.minute));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addTimeRecord),
          content: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in {
                  l10n.workerId: worker,
                  l10n.fieldId: field,
                  l10n.technicianId: technician,
                  l10n.workDate: date,
                }.entries)
                  TextField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: entry.key),
                  ),
                ListTile(
                  title: Text(l10n.timeIn),
                  subtitle: Text(label(timeIn)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickTime(l10n, timeIn);
                    if (picked != null) setDialogState(() => timeIn = picked);
                  },
                ),
                ListTile(
                  title: Text(l10n.timeOut),
                  subtitle: Text(label(timeOut)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickTime(l10n, timeOut);
                    if (picked != null) setDialogState(() => timeOut = picked);
                  },
                ),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(labelText: l10n.reason),
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
                  final dateValue = _parseDate(date.text);
                  await _service.addTimeRecord(
                    workerId: worker.text.trim(),
                    fieldId: field.text.trim(),
                    technicianId: technician.text.trim(),
                    workDate: dateValue,
                    timeIn: phTimeToUtc(dateValue, timeIn.hour, timeIn.minute),
                    timeOut: phTimeToUtc(
                      dateValue,
                      timeOut.hour,
                      timeOut.minute,
                    ),
                    reason: reason.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } on PostgrestException catch (error) {
                  if (mounted) _showMessage(l10n.adminError(error.message));
                } on Object {
                  if (mounted) _showError(l10n);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    for (final controller in [worker, field, technician, date, reason]) {
      controller.dispose();
    }
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.saved)));
    }
  }

  /// `YYYY-MM-DD` as a date-only UTC value (a Philippine calendar date).
  DateTime _parseDate(String value) {
    final parts = value.trim().split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  void _showError(AppLocalizations l10n) =>
      _showMessage(l10n.adminToolsOperationFailed);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingButton extends StatelessWidget {
  const _SettingButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
      onTap: onPressed,
      trailing: IconButton(
        tooltip: AppLocalizations.of(context).pickTime,
        onPressed: onPressed,
        icon: const Icon(Icons.edit),
      ),
    );
  }
}
