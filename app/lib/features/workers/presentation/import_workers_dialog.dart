import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../data/worker_service.dart';
import '../domain/csv_import.dart';

enum _Phase { choose, checking, preview, importing, done }

/// CSV upload for workers: choose a file, see a preview with row-level
/// messages and duplicate warnings, then import (SPEC.md section 3).
class ImportWorkersDialog extends StatefulWidget {
  const ImportWorkersDialog({super.key});

  @override
  State<ImportWorkersDialog> createState() => _ImportWorkersDialogState();
}

class _ImportWorkersDialogState extends State<ImportWorkersDialog> {
  /// Only this many lines of errors and duplicates are listed on screen.
  static const _shownLines = 100;

  final _service = WorkerService();
  _Phase _phase = _Phase.choose;
  String? _fileName;
  List<Map<String, dynamic>> _rows = const [];
  List<String> _ignoredColumns = const [];

  /// Rows whose name is already used earlier in the same file and that the
  /// server did not already report (an error or a duplicate of a saved worker).
  List<FileRepeat> _repeats = const [];
  ImportSummary _preview = const ImportSummary();
  bool _includeDuplicates = false;
  int _added = 0;
  int _done = 0;
  String? _error;

  Future<Map<String, dynamic>> _call(
    List<Map<String, dynamic>> rows,
    bool commit,
  ) => _service.importWorkers(rows, commit: commit);

  Future<void> _chooseFile() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
      );
      if (file == null) return;
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final parsed = parseWorkersCsv(text);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = parsed.rows;
        _ignoredColumns = parsed.ignoredColumns;
        _error = switch (parsed.problem) {
          CsvProblem.noNameColumn => l10n.csvNoNameColumn,
          CsvProblem.empty => l10n.csvEmpty,
          null => null,
        };
      });
    } on Object {
      if (mounted) setState(() => _error = l10n.csvReadError);
    }
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phase = _Phase.checking;
      _done = 0;
      _error = null;
    });
    try {
      final summary = await importInChunks(
        _rows,
        commit: false,
        call: _call,
        onProgress: (done, _) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (!mounted) return;
      final reported = {
        for (final e in summary.errors) e.row,
        for (final d in summary.duplicates) d.row,
      };
      // Rows with an error are never added, so they cannot be a first or a
      // repeated name; rows already reported as duplicates are listed once.
      final failed = {for (final e in summary.errors) e.row};
      final repeats = findRepeatsInFile([
        for (final row in _rows)
          if (!failed.contains(row['row'])) row,
      ]).where((repeat) => !reported.contains(repeat.row)).toList();
      setState(() {
        _preview = summary;
        _repeats = repeats;
        _includeDuplicates = false;
        _phase = _Phase.preview;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _phase = _Phase.choose;
          _error = _errorText(l10n, error);
        });
      }
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phase = _Phase.importing;
      _done = 0;
      _error = null;
    });
    try {
      final first = await importInChunks(
        _rows,
        commit: true,
        call: _call,
        onProgress: (done, _) {
          if (mounted) setState(() => _done = done);
        },
      );
      // The server skips a name that is already saved, including one saved a
      // moment ago by an earlier row of this file, so repeats stay out until
      // the admin ticks the box.
      var added = first.inserted;
      final confirmed = _confirmedRows;
      if (_includeDuplicates && confirmed.isNotEmpty) {
        final second = await importInChunks(
          confirmedDuplicateRows(_rows, confirmed),
          commit: true,
          call: _call,
        );
        added += second.inserted;
      }
      if (!mounted) return;
      setState(() {
        _added = added;
        _phase = _Phase.done;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _phase = _Phase.preview;
          _error = _errorText(l10n, error);
        });
      }
    }
  }

  /// Row numbers that are possible duplicates: of a saved worker or of an
  /// earlier row in the file.
  Set<int> get _confirmedRows => {
    for (final d in _preview.duplicates) d.row,
    for (final r in _repeats) r.row,
  };

  /// The server counts a repeat as valid in a preview (nothing is saved yet).
  int get _validCount => _preview.valid - _repeats.length;

  String _errorText(AppLocalizations l10n, Object error) =>
      error is PostgrestException
      ? l10n.adminError(error.message)
      : l10n.workerOperationFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importWorkers),
      content: SizedBox(width: 560, child: _content(l10n)),
      actions: _actions(l10n),
    );
  }

  Widget _content(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.choose:
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.csvHelp),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName ?? l10n.chooseCsvFile),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${l10n.csvRowsInFile}: ${_rows.length}'),
              ],
              ..._ignoredNotice(l10n),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        );
      case _Phase.checking:
      case _Phase.importing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _phase == _Phase.checking ? l10n.csvChecking : l10n.csvImporting,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _rows.isEmpty ? null : _done / _rows.length,
            ),
            const SizedBox(height: 4),
            Text('$_done / ${_rows.length}'),
          ],
        );
      case _Phase.preview:
        return _previewView(l10n);
      case _Phase.done:
        return Text(l10n.importDone(_added));
    }
  }

  /// A warning line for every header the system does not read.
  List<Widget> _ignoredNotice(AppLocalizations l10n) => [
    if (_ignoredColumns.isNotEmpty) const SizedBox(height: 8),
    for (final name in _ignoredColumns)
      Text(
        l10n.csvColumnNotUsed(name),
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      ),
  ];

  Widget _previewView(AppLocalizations l10n) {
    final errors = _preview.errors;
    final duplicates = _preview.duplicates;
    final repeats = _repeats;
    final lines = <String>[
      for (final e in errors.take(_shownLines))
        l10n.importRowLine(e.row, l10n.csvError(e.code)),
      if (errors.length > _shownLines)
        l10n.importMore(errors.length - _shownLines),
      for (final d in duplicates.take(_shownLines))
        l10n.importDuplicateLine(d.row, d.workerId),
      if (duplicates.length > _shownLines)
        l10n.importMore(duplicates.length - _shownLines),
      for (final r in repeats.take(_shownLines))
        l10n.importRepeatLine(r.row, r.firstRow),
      if (repeats.length > _shownLines)
        l10n.importMore(repeats.length - _shownLines),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.validRows}: $_validCount'),
        Text('${l10n.invalidRows}: ${errors.length}'),
        Text('${l10n.duplicateRows}: ${duplicates.length + repeats.length}'),
        ..._ignoredNotice(l10n),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: [for (final line in lines) Text(line)],
              ),
            ),
          ),
        ],
        if (duplicates.isNotEmpty || repeats.isNotEmpty)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeDuplicates,
            onChanged: (value) =>
                setState(() => _includeDuplicates = value ?? false),
            title: Text(l10n.includeDuplicates),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.choose:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _rows.isEmpty ? null : _check,
            child: Text(l10n.preview),
          ),
        ];
      case _Phase.checking:
      case _Phase.importing:
        return const [];
      case _Phase.preview:
        final canImport =
            _validCount > 0 ||
            (_includeDuplicates && _confirmedRows.isNotEmpty);
        return [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: canImport ? _import : null,
            child: Text(l10n.import),
          ),
        ];
      case _Phase.done:
        return [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.close),
          ),
        ];
    }
  }
}
