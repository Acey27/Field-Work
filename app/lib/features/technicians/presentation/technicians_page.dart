import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../shared/widgets/refresh_button.dart';
import '../data/technician_service.dart';

class TechniciansPage extends StatefulWidget {
  const TechniciansPage({
    required this.onLocaleChanged,
    this.service,
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;

  /// Only tests pass one; the app talks to Supabase.
  final TechnicianService? service;

  @override
  State<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends State<TechniciansPage> {
  late final TechnicianService _service = widget.service ?? TechnicianService();
  _TechnicianData? _data;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads everything from the server. The page on screen is replaced only when
  /// the new data arrives, so a change never blanks the page or loses the
  /// scroll position.
  /// [report] tells the admin when a refresh they asked for failed.
  Future<void> _load({bool report = false}) async {
    try {
      final results = await (
        _service.listTechnicians(),
        _service.listFields(),
        _service.listAssignments(),
        _service.listDevices(),
      ).wait;
      final data = _TechnicianData(
        technicians: results.$1,
        fields: results.$2,
        assignments: results.$3,
        devices: results.$4,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _loadFailed = false;
        });
      }
    } on Object catch (error) {
      debugPrint('Could not load the technicians: $error');
      if (!mounted) return;
      if (_data == null) {
        setState(() => _loadFailed = true);
      } else if (report) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).adminLoadError)),
        );
      }
    }
  }

  Future<void> _refresh() => _load(report: true);

  void _retry() {
    setState(() => _loadFailed = false);
    _load();
  }

  /// Runs a change, tells the admin if it failed, and then always shows what
  /// the server has now.
  Future<void> _change(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Technician change failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.technicianOperationFailed)),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.technicians),
        actions: [
          RefreshButton(tooltip: l10n.refresh, onRefresh: _refresh),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.createTechnician),
      ),
      body: _body(l10n),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final data = _data;
    if (data == null) {
      return _loadFailed
          ? Center(
              child: FilledButton(onPressed: _retry, child: Text(l10n.retry)),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final fieldsById = {
      for (final field in data.fields)
        field['id'] as String: field['name'] as String,
    };
    final assignments = {
      for (final row in data.assignments)
        row['technician_id'] as String:
            (row['fields'] as Map?)?['name'] as String? ?? '',
    };
    final deviceCounts = <String, int>{};
    for (final device in data.devices) {
      if (device['status'] == 'pending') {
        final id = device['technician_id'] as String;
        deviceCounts[id] = (deviceCounts[id] ?? 0) + 1;
      }
    }
    final techniciansById = {
      for (final technician in data.technicians)
        technician['id'] as String: technician,
    };
    // Phones waiting for approval come first.
    final devices = [...data.devices]
      ..sort((a, b) {
        final pendingFirst = (b['status'] == 'pending' ? 1 : 0).compareTo(
          a['status'] == 'pending' ? 1 : 0,
        );
        return pendingFirst != 0
            ? pendingFirst
            : '${b['registered_at']}'.compareTo('${a['registered_at']}');
      });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final technician in data.technicians)
          Card(
            child: ListTile(
              leading: Icon(
                technician['active'] == true ? Icons.badge : Icons.no_accounts,
              ),
              title: Text('${technician['full_name']} (${technician['code']})'),
              subtitle: Text(
                '${technician['active'] == true ? '' : '${l10n.accountOff} • '}'
                '${_subtitle(technician['id'] as String, assignments, deviceCounts, l10n)}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => value == 'assign'
                    ? _assign(technician['id'] as String, fieldsById)
                    : _toggleActive(technician),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'assign', child: Text(l10n.assignField)),
                  PopupMenuItem(
                    value: 'active',
                    child: Text(
                      technician['active'] == true
                          ? l10n.turnOffAccount
                          : l10n.turnOnAccount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.deviceApprovals,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          for (final device in devices)
            _deviceTile(l10n, device, techniciansById),
        ],
      ],
    );
  }

  /// "Mark Cruz (T-00003)", then the phone's name, its status and when it was
  /// first seen, so the admin knows whose phone is waiting.
  Widget _deviceTile(
    AppLocalizations l10n,
    Map<String, dynamic> device,
    Map<String, Map<String, dynamic>> techniciansById,
  ) {
    final owner = techniciansById[device['technician_id']];
    final seen = DateTime.tryParse('${device['registered_at'] ?? ''}')?.toUtc();
    final label = device['label'] as String? ?? l10n.device;
    final details = [
      label,
      l10n.deviceStatus('${device['status']}'),
      if (seen != null) '${formatPhDate(phDateOf(seen))} ${formatPhTime(seen)}',
    ].join(' • ');
    return ListTile(
      leading: Icon(
        device['status'] == 'approved' ? Icons.phone_android : Icons.pending,
      ),
      title: Text(
        owner == null ? label : '${owner['full_name']} (${owner['code']})',
      ),
      subtitle: Text(details),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _change(
          () => _service.setDeviceStatus(device['id'] as String, action),
        ),
        itemBuilder: (context) => [
          if (device['status'] != 'approved')
            PopupMenuItem(
              value: 'approve_device',
              child: Text(l10n.approveDevice),
            ),
          if (device['status'] == 'approved')
            PopupMenuItem(
              value: 'revoke_device',
              child: Text(l10n.revokeDevice),
            ),
        ],
      ),
    );
  }

  String _subtitle(
    String technicianId,
    Map<String, String> assignments,
    Map<String, int> deviceCounts,
    AppLocalizations l10n,
  ) {
    final pending = deviceCounts[technicianId];
    return '${assignments[technicianId] ?? l10n.noField}'
        '${pending == null ? '' : ' • $pending ${l10n.pendingDevices}'}';
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createTechnician),
        // Scrollable: on a small screen, or with the keyboard open, the three
        // fields are taller than the dialog.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.fullName),
              ),
              TextField(
                controller: email,
                decoration: InputDecoration(labelText: l10n.email),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.startingPassword,
                  helperText: l10n.startingPasswordHint,
                ),
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
                final response = await Supabase.instance.client.functions
                    .invoke(
                      'create_technician_account',
                      body: {
                        'email': email.text.trim(),
                        'full_name': name.text.trim(),
                        'starting_password': password.text,
                      },
                    );
                if (response.status < 200 || response.status >= 300) {
                  final responseData = response.data;
                  final errorCode = responseData is Map
                      ? responseData['error']
                      : null;
                  throw AuthException(
                    errorCode is String ? errorCode : 'E_ACCOUNT_CREATE_FAILED',
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } on Object {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.technicianOperationFailed)),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    password.dispose();
    if (result == true) await _load();
  }

  /// Turning an account off asks first, in plain words (SPEC.md section 14).
  Future<void> _toggleActive(Map<String, dynamic> technician) async {
    final l10n = AppLocalizations.of(context);
    final turnOff = technician['active'] == true;
    final name = technician['full_name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(turnOff ? l10n.turnOffAccount : l10n.turnOnAccount),
        content: Text(
          turnOff ? l10n.confirmTurnOff(name) : l10n.confirmTurnOn(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(
      () => _service.setActive(
        technicianId: technician['id'] as String,
        active: !turnOff,
      ),
    );
  }

  Future<void> _assign(String technicianId, Map<String, String> fields) async {
    final l10n = AppLocalizations.of(context);
    if (fields.isEmpty) return;
    final fieldId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.assignField),
        children: [
          for (final entry in fields.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (fieldId == null || !mounted) return;
    await _change(
      () => _service.assignField(technicianId: technicianId, fieldId: fieldId),
    );
  }
}

class _TechnicianData {
  const _TechnicianData({
    required this.technicians,
    required this.fields,
    required this.assignments,
    required this.devices,
  });
  final List<Map<String, dynamic>> technicians;
  final List<Map<String, dynamic>> fields;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> devices;
}
