import 'package:csv/csv.dart';

/// Most rows sent to `import_workers` in one call (CONTRACT.md section 14).
const maxImportChunk = 500;

/// The columns of the worker CSV (SPEC.md section 3).
const csvColumns = ['name', 'cp_no', 'address'];

enum CsvProblem {
  /// The file has no rows at all.
  empty,

  /// The first row has no `name` column.
  noNameColumn,
}

class CsvParseResult {
  const CsvParseResult({
    this.rows = const [],
    this.problem,
    this.ignoredColumns = const [],
  });

  /// Workers to send, each with its `row` number (the header is row 1).
  final List<Map<String, dynamic>> rows;
  final CsvProblem? problem;

  /// Headers the system does not read, as written in the file, so a wrong
  /// header (`cp number` instead of `cp_no`) is obvious to the admin.
  final List<String> ignoredColumns;
}

/// Reads the worker CSV. The first row must be the column names. Columns the
/// system does not know are not read (and are listed in `ignoredColumns`), and
/// empty lines are skipped. A bad row is not rejected here: the server checks
/// every row and reports it (CONTRACT.md section 4.14).
CsvParseResult parseWorkersCsv(String source) {
  final text = source.startsWith('﻿') ? source.substring(1) : source;
  final table = Csv().decode(text);
  if (table.isEmpty) return const CsvParseResult(problem: CsvProblem.empty);

  final written = [for (final cell in table.first) '$cell'.trim()];
  final header = [for (final cell in written) cell.toLowerCase()];
  final ignored = <String>[
    for (var i = 0; i < written.length; i++)
      if (written[i].isNotEmpty && !csvColumns.contains(header[i])) written[i],
  ];
  if (!header.contains('name')) {
    return CsvParseResult(
      problem: CsvProblem.noNameColumn,
      ignoredColumns: ignored,
    );
  }

  final rows = <Map<String, dynamic>>[];
  for (var index = 1; index < table.length; index++) {
    final record = table[index];
    final values = <String, dynamic>{};
    var hasValue = false;
    for (var column = 0; column < header.length; column++) {
      final name = header[column];
      if (!csvColumns.contains(name)) continue;
      final value = column < record.length ? '${record[column]}'.trim() : '';
      if (value.isNotEmpty) hasValue = true;
      values[name] = value;
    }
    if (!hasValue) continue;
    rows.add({'row': index + 1, ...values});
  }
  return rows.isEmpty
      ? CsvParseResult(problem: CsvProblem.empty, ignoredColumns: ignored)
      : CsvParseResult(rows: rows, ignoredColumns: ignored);
}

/// A row whose name is already used by an earlier row of the same file.
class FileRepeat {
  const FileRepeat(this.row, this.firstRow);
  final int row;
  final int firstRow;
}

/// Finds names that appear more than once in the file. The first row with a
/// name is kept; each later row with the same name (ignoring case and the
/// spaces at the ends) is a repeat. The server cannot see these in a preview,
/// because nothing is saved yet.
List<FileRepeat> findRepeatsInFile(List<Map<String, dynamic>> rows) {
  final firstSeen = <String, int>{};
  final repeats = <FileRepeat>[];
  for (final row in rows) {
    final name = '${row['name'] ?? ''}'.trim().toLowerCase();
    if (name.isEmpty) continue;
    final number = row['row'] as int;
    final first = firstSeen[name];
    if (first == null) {
      firstSeen[name] = number;
    } else {
      repeats.add(FileRepeat(number, first));
    }
  }
  return repeats;
}

class ImportRowError {
  const ImportRowError(this.row, this.code);
  final int row;
  final String code;
}

class ImportDuplicate {
  const ImportDuplicate(this.row, this.workerId);
  final int row;
  final String workerId;
}

/// The answer of `import_workers`, added up over all chunks.
class ImportSummary {
  const ImportSummary({
    this.valid = 0,
    this.inserted = 0,
    this.errors = const [],
    this.duplicates = const [],
  });

  final int valid;
  final int inserted;
  final List<ImportRowError> errors;
  final List<ImportDuplicate> duplicates;

  ImportSummary operator +(ImportSummary other) => ImportSummary(
    valid: valid + other.valid,
    inserted: inserted + other.inserted,
    errors: [...errors, ...other.errors],
    duplicates: [...duplicates, ...other.duplicates],
  );

  factory ImportSummary.fromJson(Map<String, dynamic> json) {
    return ImportSummary(
      valid: (json['valid'] as num?)?.toInt() ?? 0,
      inserted: (json['inserted'] as num?)?.toInt() ?? 0,
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => ImportRowError(
              (e['row'] as num).toInt(),
              e['code'] as String? ?? '',
            ),
          )
          .toList(),
      duplicates: (json['duplicates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (d) => ImportDuplicate(
              (d['row'] as num).toInt(),
              d['worker_id'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }
}

typedef ImportCall = Future<Map<String, dynamic>> Function(
  List<Map<String, dynamic>> rows,
  bool commit,
);

/// Sends [rows] to the server in chunks of at most [maxImportChunk] and adds
/// up the answers. [onProgress] gets (rows done, rows in total).
Future<ImportSummary> importInChunks(
  List<Map<String, dynamic>> rows, {
  required bool commit,
  required ImportCall call,
  void Function(int done, int total)? onProgress,
}) async {
  var summary = const ImportSummary();
  for (var start = 0; start < rows.length; start += maxImportChunk) {
    final end = start + maxImportChunk < rows.length
        ? start + maxImportChunk
        : rows.length;
    final answer = await call(rows.sublist(start, end), commit);
    summary += ImportSummary.fromJson(answer);
    onProgress?.call(end, rows.length);
  }
  return summary;
}

/// The rows (by row number) the admin confirmed as duplicates, marked so the
/// server inserts them (CONTRACT.md section 14: `"allow_duplicate": true`).
List<Map<String, dynamic>> confirmedDuplicateRows(
  List<Map<String, dynamic>> rows,
  Set<int> numbers,
) {
  return [
    for (final row in rows)
      if (numbers.contains(row['row'])) {...row, 'allow_duplicate': true},
  ];
}
