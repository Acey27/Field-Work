import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/field_service.dart';

class FieldsPage extends StatefulWidget {
  const FieldsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<FieldsPage> createState() => _FieldsPageState();
}

class _FieldsPageState extends State<FieldsPage> {
  final _service = FieldService();
  late Future<List<Map<String, dynamic>>> _fields;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fields = _service.listFields();
  }

  void _refresh() => setState(() => _fields = _service.listFields());

  Future<void> _reloadAfterMutation() async {
    final fields = await _service.listFields();
    if (mounted) setState(() => _fields = Future.value(fields));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fields),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.addField),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fields,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
            );
          }
          final rows = snapshot.data!.where((row) {
            final query = _query.toLowerCase();
            return query.isEmpty ||
                '${row['name']} ${row['location'] ?? ''} ${row['address'] ?? ''}'
                    .toLowerCase()
                    .contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: l10n.searchFields,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(child: Text(l10n.noFields))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return _FieldTile(
                            row: row,
                            onToggle: () => _toggle(row),
                            onEdit: () => _showCreate(row),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreate([Map<String, dynamic>? existing]) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?['name'] as String?);
    final location = TextEditingController(
      text: existing?['location'] as String?,
    );
    final address = TextEditingController(
      text: existing?['address'] as String?,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? l10n.addField : l10n.editField),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.fieldName),
              ),
              TextField(
                controller: location,
                decoration: InputDecoration(labelText: l10n.location),
              ),
              TextField(
                controller: address,
                decoration: InputDecoration(labelText: l10n.address),
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
              if (name.text.trim().isEmpty) return;
              try {
                if (existing == null) {
                  await _service.createField(
                    name: name.text,
                    location: location.text,
                    address: address.text,
                  );
                } else {
                  await _service.updateField(
                    fieldId: existing['id'] as String,
                    name: name.text,
                    location: location.text,
                    address: address.text,
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } on Object catch (error) {
                if (context.mounted) _showOperationError(error);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    location.dispose();
    address.dispose();
    if (result == true) {
      try {
        await _reloadAfterMutation();
      } on Object catch (error) {
        if (mounted) _showOperationError(error);
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    final active = row['active'] != true;
    try {
      await _service.setActive(fieldId: row['id'] as String, active: active);
      if (mounted) setState(() => row['active'] = active);
      await _reloadAfterMutation();
    } on Object catch (error) {
      if (mounted) _showOperationError(error);
    }
  }

  void _showOperationError(Object error) {
    final l10n = AppLocalizations.of(context);
    final code = switch (error) {
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      _ => '',
    };
    final message = code == 'E_SERVER_CONFIG'
        ? l10n.authError(code)
        : code == 'E_FIELD_NOT_FOUND' || code == 'E_FORBIDDEN'
        ? l10n.adminError(code)
        : l10n.fieldOperationFailed;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.row,
    required this.onToggle,
    required this.onEdit,
  });

  final Map<String, dynamic> row;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = row['active'] == true;
    final details = [
      if ((row['location'] as String?)?.isNotEmpty == true) row['location'],
      if ((row['address'] as String?)?.isNotEmpty == true) row['address'],
      active ? l10n.active : l10n.inactive,
    ].join(' • ');
    return Card(
      child: ListTile(
        leading: Icon(active ? Icons.location_on : Icons.location_off),
        title: Text(row['name'] as String),
        subtitle: Text(details),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onToggle(),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.editField)),
            PopupMenuItem(
              value: 'toggle',
              child: Text(active ? l10n.deactivate : l10n.activate),
            ),
          ],
        ),
      ),
    );
  }
}
