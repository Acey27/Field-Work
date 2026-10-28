import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/technician_service.dart';

class TechniciansPage extends StatefulWidget {
  const TechniciansPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends State<TechniciansPage> {
  final _service = TechnicianService();
  late Future<_TechnicianData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_TechnicianData> _load() async {
    return _TechnicianData(
      technicians: await _service.listTechnicians(),
      fields: await _service.listFields(),
      assignments: await _service.listAssignments(),
      devices: await _service.listDevices(),
    );
  }

  void _refresh() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.technicians),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.createTechnician),
      ),
      body: FutureBuilder<_TechnicianData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
            );
          }
          final data = snapshot.data!;
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final technician in data.technicians)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge),
                    title: Text(
                      '${technician['full_name']} (${technician['code']})',
                    ),
                    subtitle: Text(
                      _subtitle(
                        technician['id'] as String,
                        assignments,
                        deviceCounts,
                        l10n,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _assign(technician['id'] as String, fieldsById),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'assign',
                          child: Text(l10n.assignField),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data.devices.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.deviceApprovals,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                for (final device in data.devices)
                  ListTile(
                    leading: Icon(
                      device['status'] == 'approved'
                          ? Icons.phone_android
                          : Icons.pending,
                    ),
                    title: Text(device['label'] as String? ?? l10n.device),
                    subtitle: Text('${device['status']}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        try {
                          await _service.setDeviceStatus(
                            device['id'] as String,
                            action,
                          );
                          _refresh();
                        } on Object {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.technicianOperationFailed),
                            ),
                          );
                        }
                      },
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
                  ),
              ],
            ],
          );
        },
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
        content: Column(
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
    if (result == true) _refresh();
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
    if (fieldId == null) return;
    try {
      await _service.assignField(technicianId: technicianId, fieldId: fieldId);
      _refresh();
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.technicianOperationFailed)));
      }
    }
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
