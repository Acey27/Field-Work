import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/worker_service.dart';
import '../data/worker_export_service.dart';

import 'package:csv/csv.dart';

class WorkersPage extends StatefulWidget {
  const WorkersPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
  final _service = WorkerService();
  final _exportService = WorkerExportService();
  late Future<List<Map<String, dynamic>>> _workers;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _workers = _service.listWorkers();
  }

  void _refresh() {
    setState(() => _workers = _service.listWorkers());
  }

  Future<void> _reloadAfterMutation() async {
    final workers = await _service.listWorkers();
    if (mounted) setState(() => _workers = Future.value(workers));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workers),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: l10n.importWorkers,
            onPressed: _showImport,
            icon: const Icon(Icons.upload_file),
          ),
          LanguageToggle(onChanged: widget.onLocaleChanged),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addWorker),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _workers,
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
                '${row['name']} ${row['id']}'.toLowerCase().contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: l10n.searchWorkers,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(child: Text(l10n.noWorkers))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => _WorkerTile(
                          row: rows[index],
                          onToggle: () => _toggle(rows[index]),
                          onReissue: () => _reissue(rows[index]),
                          onPrint: () => _printCard(rows[index]),
                          onEdit: () => _showCreate(rows[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printCard(Map<String, dynamic> row) async {
    try {
      await _exportService.printCard(row);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).workerOperationFailed),
          ),
        );
      }
    }
  }

  Future<void> _showImport() async {
    final l10n = AppLocalizations.of(context);
    final csvController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importWorkers),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: csvController,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              labelText: l10n.csvData,
              hintText: 'name,cp_no,address,gender,date_of_birth',
            ),
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
                final rows = _parseCsv(csvController.text);
                final preview = await _exportService.importRows(
                  rows,
                  commit: false,
                );
                if (!context.mounted) return;
                final valid = preview['valid'] ?? 0;
                final errors = (preview['errors'] as List?)?.length ?? 0;
                final duplicates =
                    (preview['duplicates'] as List?)?.length ?? 0;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.importPreview),
                    content: Text(
                      '${l10n.validRows}: $valid\n'
                      '${l10n.invalidRows}: $errors\n'
                      '${l10n.duplicateRows}: $duplicates',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.import),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _exportService.importRows(rows, commit: true);
                  if (context.mounted) Navigator.pop(context, true);
                }
              } on Object catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.workerOperationFailed)),
                  );
                }
              }
            },
            child: Text(l10n.preview),
          ),
        ],
      ),
    );
    csvController.dispose();
    if (result == true) _refresh();
  }

  List<Map<String, dynamic>> _parseCsv(String source) {
    final rows = Csv().decode(source);
    if (rows.isEmpty) return [];
    final header = rows.first
        .map((value) => '$value'.trim().toLowerCase())
        .toList();
    return [
      for (var index = 1; index < rows.length; index++)
        if (rows[index].isNotEmpty)
          {
            'row': index + 1,
            for (var column = 0; column < header.length; column++)
              header[column]: column < rows[index].length
                  ? '${rows[index][column]}'.trim()
                  : '',
          },
    ];
  }

  Future<void> _showCreate([Map<String, dynamic>? existing]) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?['name'] as String?);
    final cpNo = TextEditingController(text: existing?['cp_no'] as String?);
    final address = TextEditingController(
      text: existing?['address'] as String?,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? l10n.addWorker : l10n.editWorker),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.fullName),
              ),
              TextField(
                controller: cpNo,
                decoration: InputDecoration(labelText: l10n.cpNumber),
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
                  await _service.createWorker(
                    name: name.text,
                    cpNo: cpNo.text,
                    address: address.text,
                  );
                } else {
                  await _service.updateWorker(
                    workerId: existing['id'] as String,
                    name: name.text,
                    cpNo: cpNo.text,
                    address: address.text,
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } on Object catch (error) {
                if (context.mounted) {
                  final code = error is AuthException
                      ? error.message
                      : 'E_LOGIN_FAILED';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_workerErrorMessage(l10n, code))),
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
    cpNo.dispose();
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
      await _service.setActive(workerId: row['id'] as String, active: active);
      if (mounted) {
        setState(() {
          row['active'] = active;
        });
      }
      await _reloadAfterMutation();
    } on Object catch (error) {
      if (mounted) _showOperationError(error);
    }
  }

  Future<void> _reissue(Map<String, dynamic> row) async {
    try {
      final result = await _service.reissueCard(row['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).qrReissued}: '
            '${result['qr_payload']}',
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) _showOperationError(error);
    }
  }

  void _showOperationError(Object error) {
    final l10n = AppLocalizations.of(context);
    final code = error is AuthException ? error.message : '';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_workerErrorMessage(l10n, code))));
  }

  String _workerErrorMessage(AppLocalizations l10n, String code) {
    if (code == 'E_SERVER_CONFIG') return l10n.authError(code);
    if (code == 'E_INPUT_INVALID') return l10n.authError(code);
    return l10n.workerOperationFailed;
  }
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({
    required this.row,
    required this.onToggle,
    required this.onReissue,
    required this.onPrint,
    required this.onEdit,
  });
  final Map<String, dynamic> row;
  final VoidCallback onToggle;
  final VoidCallback onReissue;
  final VoidCallback onPrint;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = row['active'] == true;
    return Card(
      child: ListTile(
        leading: Icon(active ? Icons.person : Icons.person_off),
        title: Text('${row['name']} (${row['id']})'),
        subtitle: Text(
          '${row['cp_no'] ?? ''}\n${active ? l10n.active : l10n.inactive}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') onToggle();
            if (value == 'reissue') onReissue();
            if (value == 'print') onPrint();
            if (value == 'edit') onEdit();
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.editWorker)),
            PopupMenuItem(
              value: 'toggle',
              child: Text(active ? l10n.deactivate : l10n.activate),
            ),
            if (active)
              PopupMenuItem(value: 'reissue', child: Text(l10n.reissueCard)),
            PopupMenuItem(value: 'print', child: Text(l10n.printCard)),
          ],
        ),
      ),
    );
  }
}
