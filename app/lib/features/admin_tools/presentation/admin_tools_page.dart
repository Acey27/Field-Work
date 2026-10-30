import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../technicians/data/technician_service.dart';
import '../data/admin_tools_service.dart';
import '../data/paper_sheet.dart';
import '../../masterlist/data/masterlist.dart';
import '../../masterlist/data/masterlist_print.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  final _service = AdminToolsService();
  final _masterlistService = MasterlistService();
  List<MasterlistRow> _masterlist = [];
  List<UnendedFieldDay> _unended = [];
  bool _changedAfterExport = false;
  DateTime _masterlistWeek = phWeekStart(phDateOf(DateTime.now()));
  Map<String, String> _times = {};
  int? _repeatMinutes;
  bool _busy = false;
  List<Map<String, dynamic>> _technicians = [];
  String? _sheetTechnicianId;
  DateTime _sheetDate = phDateOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadTimes();
    _loadTechnicians();
  }

  Future<void> _loadTechnicians() async {
    try {
      final rows = await TechnicianService().listTechnicians();
      if (mounted) {
        setState(() {
          _technicians = rows.where((row) => row['active'] == true).toList();
        });
      }
    } on Object {
      // The paper sheet picker stays empty; the rest of the page still works.
    }
  }

  Future<void> _pickSheetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_sheetDate.year, _sheetDate.month, _sheetDate.day),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(
      () => _sheetDate = DateTime.utc(picked.year, picked.month, picked.day),
    );
  }

  /// Builds the sheet in the current language and opens the print dialog.
  Future<void> _printSheet(AppLocalizations l10n) async {
    final technicianId = _sheetTechnicianId;
    if (technicianId == null) return;
    setState(() => _busy = true);
    try {
      final sheet = await PaperSheetService().load(
        technicianId: technicianId,
        date: _sheetDate,
      );
      final bytes = await buildPaperSheetPdf(sheet, l10n);
      await Printing.layoutPdf(
        name: 'paper-sheet-${sheet.technicianCode}-${sheet.workDate}',
        onLayout: (_) async => bytes,
      );
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(l10n.adminError(error.message));
    } on Object {
      if (mounted) _showError(l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadTimes() async {
    try {
      final times = await _service.timeSettings();
      final repeat = await _service.reminderRepeatMinutes();
      if (mounted) {
        setState(() {
          _times = times;
          _repeatMinutes = repeat;
        });
      }
    } on Object {
      // The rows show "Not set"; editing still works.
    }
  }

  /// Minutes before the one repeat reminder (CONTRACT.md section 14: 5 to 120).
  Future<void> _setRepeatMinutes(AppLocalizations l10n) async {
    final controller = TextEditingController(text: '${_repeatMinutes ?? 30}');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reminderRepeatMinutes),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(helperText: '5 - 120'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text.trim());
              if (minutes == null || minutes < 5 || minutes > 120) return;
              Navigator.pop(context, minutes);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await _service.setSetting('reminder_repeat_minutes', value);
      final stored = await _service.reminderRepeatMinutes();
      if (!mounted) return;
      setState(() => _repeatMinutes = stored ?? value);
      if (stored != null && stored != value) {
        _showError(l10n);
        return;
      }
      _showMessage(l10n.saved);
    } on PostgrestException catch (error) {
      debugPrint('admin_set_setting reminder_repeat_minutes: ${error.message}');
      if (mounted) _showMessage(l10n.adminError(error.message));
    } on Object catch (error) {
      debugPrint('admin_set_setting reminder_repeat_minutes: $error');
      if (mounted) _showError(l10n);
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
          _SettingButton(
            label: l10n.reminderRepeatMinutes,
            value: _repeatMinutes == null
                ? l10n.timeNotSet
                : l10n.minutesValue(_repeatMinutes!),
            onPressed: () => _setRepeatMinutes(l10n),
          ),
          // The reminder never ends a field day by itself (SPEC.md section 8).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.reminderHint(l10n.endFieldDay),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_changedAfterExport)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.changedAfterExport,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
            onPressed: () => context.go('/admin/time-records'),
            icon: const Icon(Icons.edit_calendar),
            label: Text(l10n.openTimeRecords),
          ),
          const Divider(height: 32),
          Text(
            l10n.paperSheet,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.paperSheetHint),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sheetTechnicianId,
            decoration: InputDecoration(labelText: l10n.technician),
            items: [
              for (final t in _technicians)
                DropdownMenuItem(
                  value: t['id'] as String,
                  child: Text('${t['full_name']} (${t['code']})'),
                ),
            ],
            onChanged: (value) => setState(() => _sheetTechnicianId = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickSheetDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(formatPhDate(_sheetDate)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || _sheetTechnicianId == null
                ? null
                : () => _printSheet(l10n),
            icon: const Icon(Icons.print),
            label: Text(l10n.printSheet),
          ),
          const Divider(height: 32),
          Text(
            l10n.weeklyMasterlist,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickMasterlistWeek,
            icon: const Icon(Icons.calendar_today),
            label: Text(_weekLabel(_masterlistWeek)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadMasterlist,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.loadMasterlist),
          ),
          if (_unended.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.unendedWeekWarning(_unended.length),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || _masterlist.isEmpty
                      ? null
                      : () => _exportMasterlist(l10n),
                  icon: const Icon(Icons.file_download),
                  label: Text(l10n.exportMasterlist),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _masterlist.isEmpty
                      ? null
                      : () => _printMasterlist(l10n),
                  icon: const Icon(Icons.print),
                  label: Text(l10n.printMasterlist),
                ),
              ),
            ],
          ),
          if (_masterlist.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l10n.noMasterlistRows),
            )
          else
            for (final row in _masterlist)
              ListTile(
                dense: true,
                title: Text('${row.workerId} ${row.workerName}'),
                subtitle: Text(
                  '${row.technicianCode} / ${row.fieldLabel} • '
                  '${formatMinutes(row.totalMinutes)}',
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
  Future<TimeOfDay?> _pickTime(AppLocalizations l10n, TimeOfDay initial) {
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
      setState(
        () => _times = stored.isEmpty ? {..._times, key: value} : stored,
      );
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
      final rows = await _masterlistService.load(_masterlistWeek);
      final unended = await _masterlistService.loadUnended(_masterlistWeek);
      final changed = await _masterlistService.hasChangedAfterExport(
        _masterlistWeek,
      );
      if (mounted) {
        setState(() {
          _masterlist = rows;
          _unended = unended;
          _changedAfterExport = changed;
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        _showMessage(AppLocalizations.of(context).adminError(error.message));
      }
    } on Object catch (error) {
      debugPrint('weekly masterlist load failed: $error');
      if (mounted) _showError(AppLocalizations.of(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMasterlistWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _masterlistWeek,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _masterlistWeek = phWeekStart(
        DateTime.utc(picked.year, picked.month, picked.day),
      );
      _masterlist = [];
      _unended = [];
      _changedAfterExport = false;
    });
  }

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    return '${DateFormat('d MMM yyyy').format(weekStart)} - '
        '${DateFormat('d MMM yyyy').format(end)}';
  }

  List<String> _headers(AppLocalizations l10n) =>
      l10n.masterlistHeaders.split(',');

  Future<void> _exportMasterlist(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final fileName = 'masterlist-${formatPhDate(_masterlistWeek)}.xlsx';
      final bytes = await _masterlistService.buildExcel(
        rows: _masterlist,
        weekLabel: _weekLabel(_masterlistWeek),
        notEndedLabel: l10n.notEndedCell,
        headers: _headers(l10n),
      );
      final saved = await _masterlistService.saveExcel(bytes, fileName);
      if (saved != null) {
        await _masterlistService.recordExport(
          weekStart: _masterlistWeek,
          fileName: fileName,
          rowCount: _masterlist.length,
        );
        if (mounted) _showMessage(l10n.exportSaved);
      }
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(l10n.adminError(error.message));
    } on Object catch (error) {
      debugPrint('weekly masterlist export failed: $error');
      if (mounted) _showError(l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printMasterlist(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final bytes = await buildMasterlistPdf(
        weekStart: _masterlistWeek,
        rows: _masterlist,
        weekLabel: _weekLabel(_masterlistWeek),
        notEndedLabel: l10n.notEndedCell,
        headers: _headers(l10n),
      );
      await Printing.layoutPdf(
        name: 'masterlist-${formatPhDate(_masterlistWeek)}',
        onLayout: (_) async => bytes,
      );
    } on Object catch (error) {
      debugPrint('weekly masterlist print failed: $error');
      if (mounted) _showError(l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
