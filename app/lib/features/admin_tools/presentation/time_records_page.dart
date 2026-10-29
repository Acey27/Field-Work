import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../technicians/data/technician_service.dart';
import '../../workers/data/worker_service.dart';
import '../data/time_records_service.dart';

/// The admin's day list of time records, with add and fix
/// (SPEC.md section 8: "Adding or fixing time records by hand").
class TimeRecordsPage extends StatefulWidget {
  const TimeRecordsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<TimeRecordsPage> createState() => _TimeRecordsPageState();
}

class _TimeRecordsPageState extends State<TimeRecordsPage> {
  final _service = TimeRecordsService();
  late DateTime _date;
  late Future<List<TimeRecord>> _records;

  @override
  void initState() {
    super.initState();
    _date = phDateOf(DateTime.now());
    _records = _service.forDate(_date);
  }

  void _refresh() => setState(() => _records = _service.forDate(_date));

  void _moveDay(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
      _records = _service.forDate(_date);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime.utc(picked.year, picked.month, picked.day);
      _records = _service.forDate(_date);
    });
  }

  Future<void> _add() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (context) => _TimeRecordDialog(date: _date, service: _service),
    );
    if (done == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saved)),
        );
      }
      _refresh();
    }
  }

  Future<void> _fix(TimeRecord record) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _TimeRecordDialog(date: _date, service: _service, fixing: record),
    );
    if (done == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saved)),
        );
      }
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timeRecords),
        leading: BackButton(onPressed: () => context.go('/admin/tools')),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.edit_calendar),
        label: Text(l10n.addTimeRecord),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.previousDay,
                  onPressed: () => _moveDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(formatPhDate(_date)),
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextDay,
                  onPressed: () => _moveDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TimeRecord>>(
              future: _records,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: FilledButton(
                      onPressed: _refresh,
                      child: Text(l10n.retry),
                    ),
                  );
                }
                final records = snapshot.data!;
                if (records.isEmpty) {
                  return Center(child: Text(l10n.noTimeRecords));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  itemCount: records.length,
                  itemBuilder: (context, index) => _RecordTile(
                    record: records[index],
                    onTap: () => _fix(records[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final TimeRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final out = record.timeOut;
    final times =
        '${formatPhTime(record.timeIn)} – '
        '${out == null ? l10n.notClockedOut : formatPhTime(out)}';
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${record.workerName} (${record.workerId})'),
        subtitle: Text(
          '${record.technicianName} (${record.technicianCode}) · '
          '${record.fieldName}\n$times'
          '${record.enteredByAdmin ? '\n${l10n.enteredByAdmin}'
                    '${record.manualReason == null ? '' : ': ${record.manualReason}'}' : ''}',
        ),
        isThreeLine: true,
        trailing: record.enteredByAdmin
            ? Icon(Icons.edit_note, color: Theme.of(context).colorScheme.secondary)
            : const Icon(Icons.edit),
      ),
    );
  }
}

/// Add a record, or fix one when [fixing] is given.
class _TimeRecordDialog extends StatefulWidget {
  const _TimeRecordDialog({
    required this.date,
    required this.service,
    this.fixing,
  });

  final DateTime date;
  final TimeRecordsService service;
  final TimeRecord? fixing;

  @override
  State<_TimeRecordDialog> createState() => _TimeRecordDialogState();
}

class _TimeRecordDialogState extends State<_TimeRecordDialog> {
  final _reason = TextEditingController();
  final _technicians = TechnicianService();
  final _workers = WorkerService();
  List<Map<String, dynamic>> _workerRows = [];
  List<Map<String, dynamic>> _technicianRows = [];
  List<Map<String, dynamic>> _fieldRows = [];
  Map<String, String> _assignedField = {};
  Map<String, dynamic>? _worker;
  String? _technicianId;
  String? _fieldId;
  TimeOfDay _timeIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _timeOut = const TimeOfDay(hour: 17, minute: 0);
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isFix => widget.fixing != null;

  @override
  void initState() {
    super.initState();
    final fixing = widget.fixing;
    if (fixing != null) {
      _timeIn = _toTimeOfDay(fixing.timeIn);
      _timeOut = fixing.timeOut == null
          ? _timeIn
          : _toTimeOfDay(fixing.timeOut!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  TimeOfDay _toTimeOfDay(DateTime utc) {
    final ph = utc.toUtc().add(const Duration(hours: 8));
    return TimeOfDay(hour: ph.hour, minute: ph.minute);
  }

  Future<void> _load() async {
    try {
      final workers = await _workers.listWorkers();
      final technicians = await _technicians.listTechnicians();
      final fields = await _technicians.listFields();
      final assignments = await _technicians.listAssignments();
      if (!mounted) return;
      setState(() {
        _workerRows = workers.where((w) => w['active'] == true).toList();
        _technicianRows = technicians
            .where((t) => t['active'] == true)
            .toList();
        _fieldRows = fields;
        _assignedField = {
          for (final row in assignments)
            row['technician_id'] as String: row['field_id'] as String,
        };
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).adminLoadError;
        });
      }
    }
  }

  Future<void> _pick(bool isIn) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      helpText: l10n.pickTime,
      initialTime: isIn ? _timeIn : _timeOut,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isIn ? _timeIn = picked : _timeOut = picked);
  }

  String _label(TimeOfDay time) =>
      formatClock12(formatClock24(time.hour, time.minute));

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final timeIn = phTimeToUtc(widget.date, _timeIn.hour, _timeIn.minute);
    final timeOut = phTimeToUtc(widget.date, _timeOut.hour, _timeOut.minute);
    if (!_isFix &&
        (_worker == null || _technicianId == null || _fieldId == null)) {
      setState(() => _error = l10n.timeRecordIncomplete);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isFix) {
        await widget.service.fix(
          sessionId: widget.fixing!.sessionId,
          timeIn: timeIn,
          timeOut: timeOut,
          reason: _reason.text.trim(),
        );
      } else {
        await widget.service.add(
          workerId: _worker!['id'] as String,
          fieldId: _fieldId!,
          technicianId: _technicianId!,
          workDate: widget.date,
          timeIn: timeIn,
          timeOut: timeOut,
          reason: _reason.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.adminError(error.message);
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.adminToolsOperationFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fixing = widget.fixing;
    return AlertDialog(
      title: Text(_isFix ? l10n.fixTimeRecord : l10n.addTimeRecord),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPhDate(widget.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (fixing != null)
                      Text('${fixing.workerName} (${fixing.workerId})')
                    else ...[
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (w) => '${w['name']} (${w['id']})',
                        optionsBuilder: (value) {
                          final query = value.text.trim().toLowerCase();
                          if (query.isEmpty) return const Iterable.empty();
                          return _workerRows
                              .where(
                                (w) => '${w['name']} ${w['id']}'
                                    .toLowerCase()
                                    .contains(query),
                              )
                              .take(8);
                        },
                        onSelected: (w) => setState(() => _worker = w),
                        fieldViewBuilder: (context, controller, focus, submit) =>
                            TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: InputDecoration(
                                labelText: l10n.workerLabel,
                                helperText: l10n.chooseWorker,
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onChanged: (_) => setState(() => _worker = null),
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _technicianId,
                        decoration: InputDecoration(
                          labelText: l10n.technician,
                        ),
                        items: [
                          for (final t in _technicianRows)
                            DropdownMenuItem(
                              value: t['id'] as String,
                              child: Text('${t['full_name']} (${t['code']})'),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _technicianId = value;
                          // Start from the technician's current field.
                          final assigned = value == null
                              ? null
                              : _assignedField[value];
                          if (assigned != null) _fieldId = assigned;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _fieldId,
                        decoration: InputDecoration(labelText: l10n.fieldLabel),
                        items: [
                          for (final f in _fieldRows)
                            DropdownMenuItem(
                              value: f['id'] as String,
                              child: Text('${f['name']}'),
                            ),
                        ],
                        onChanged: (value) => setState(() => _fieldId = value),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.sheetTimeIn),
                      subtitle: Text(_label(_timeIn)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () => _pick(true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.sheetTimeOut),
                      subtitle: Text(_label(_timeOut)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () => _pick(false),
                    ),
                    TextField(
                      controller: _reason,
                      decoration: InputDecoration(labelText: l10n.reason),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving || _loading ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
