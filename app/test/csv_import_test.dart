import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/workers/domain/csv_import.dart';

void main() {
  group('parseWorkersCsv', () {
    test(
      'reads the SPEC columns and numbers rows from the header as row 1',
      () {
        final result = parseWorkersCsv(
          'name,cp_no,address\n'
          'Juan Dela Cruz,0917,Echague\n'
          'Maria Santos,,Cauayan\n',
        );
        expect(result.problem, isNull);
        expect(result.ignoredColumns, isEmpty);
        expect(result.rows.length, 2);
        expect(result.rows[0]['row'], 2);
        expect(result.rows[0]['name'], 'Juan Dela Cruz');
        expect(result.rows[0]['cp_no'], '0917');
        expect(result.rows[1]['row'], 3);
        expect(result.rows[1]['cp_no'], '');
      },
    );

    test('ignores a byte order mark, case and spaces in known headers', () {
      final result = parseWorkersCsv(
        '﻿ Name , CP_NO \n'
        ' Juan , 0917 \n',
      );
      expect(result.rows.single['name'], 'Juan');
      expect(result.rows.single['cp_no'], '0917');
      expect(result.ignoredColumns, isEmpty);
    });

    test('lists a header it does not read, as written in the file', () {
      // The wrong headers from a real test file: "cp number" is not cp_no.
      final result = parseWorkersCsv(
        'name,cp number,address,date of birth ,Gender\n'
        'Juan,0917,Echague,5/1/1990,male\n',
      );
      expect(result.problem, isNull);
      expect(result.ignoredColumns, ['cp number', 'date of birth', 'Gender']);
      expect(result.rows.single.keys, containsAll(['row', 'name', 'address']));
      expect(result.rows.single.containsKey('cp number'), isFalse);
      expect(result.rows.single.containsKey('cp_no'), isFalse);
      expect(result.rows.single.containsKey('gender'), isFalse);
      expect(result.rows.single.containsKey('date_of_birth'), isFalse);
    });

    test('does not list an empty header cell as a column', () {
      final result = parseWorkersCsv('name,cp_no,,\nJuan,0917,,\n');
      expect(result.ignoredColumns, isEmpty);
    });

    test('reads quoted values with commas', () {
      final result = parseWorkersCsv(
        'name,address\n"Dela Cruz, Juan","Purok 1, Echague"\n',
      );
      expect(result.rows.single['name'], 'Dela Cruz, Juan');
      expect(result.rows.single['address'], 'Purok 1, Echague');
    });

    test('skips empty lines; row numbers count records, header is row 1', () {
      final result = parseWorkersCsv('name\nJuan\n\n,\nMaria\n');
      expect(result.rows.map((r) => r['name']), ['Juan', 'Maria']);
      // Blank lines are dropped by the reader, so Maria is record 3.
      expect(result.rows.last['row'], 3);
    });

    test('reports a missing name column and still lists the headers', () {
      final result = parseWorkersCsv('full name,cp_no\nJuan,0917\n');
      expect(result.problem, CsvProblem.noNameColumn);
      expect(result.ignoredColumns, ['full name']);
    });

    test('reports an empty file or a file with only a header', () {
      expect(parseWorkersCsv('').problem, CsvProblem.empty);
      expect(parseWorkersCsv('name,cp_no\n').problem, CsvProblem.empty);
    });

    test('does not reject a bad row: the server reports it', () {
      final result = parseWorkersCsv('name,cp_no\nJuan,0917\n,0918\n');
      // The second row has a phone number but no name; both go to the server.
      expect(result.rows.length, 2);
      expect(result.rows[1]['name'], '');
    });
  });

  group('findRepeatsInFile', () {
    List<Map<String, dynamic>> named(List<String> names) => [
      for (var i = 0; i < names.length; i++) {'row': i + 2, 'name': names[i]},
    ];

    test('finds a name used again later in the same file', () {
      final repeats = findRepeatsInFile(
        named(['Juan dela Cruz', 'Maria Santos', 'Juan dela Cruz']),
      );
      expect(repeats.length, 1);
      expect(repeats.single.row, 4);
      expect(repeats.single.firstRow, 2);
    });

    test('ignores case and spaces at the ends', () {
      final repeats = findRepeatsInFile(
        named(['Juan dela Cruz', '  juan DELA cruz ', 'JUAN DELA CRUZ']),
      );
      expect(repeats.map((r) => r.row), [3, 4]);
      // Every repeat points to the first row, not to the previous repeat.
      expect(repeats.map((r) => r.firstRow), [2, 2]);
    });

    test('finds nothing when every name is different', () {
      expect(findRepeatsInFile(named(['A', 'B', 'C'])), isEmpty);
    });

    test('does not treat rows without a name as repeats of each other', () {
      expect(findRepeatsInFile(named(['', '  ', 'A'])), isEmpty);
    });

    test('keeps names with different words apart', () {
      expect(
        findRepeatsInFile(named(['Juan Cruz', 'Juan dela Cruz'])),
        isEmpty,
      );
    });
  });

  group('importInChunks', () {
    List<Map<String, dynamic>> rows(int count) => [
      for (var i = 0; i < count; i++) {'row': i + 2, 'name': 'Worker $i'},
    ];

    test('sends 2,000 rows in 4 calls of at most 500', () async {
      final sizes = <int>[];
      final summary = await importInChunks(
        rows(2000),
        commit: false,
        call: (chunk, commit) async {
          sizes.add(chunk.length);
          expect(commit, isFalse);
          return {
            'valid': chunk.length,
            'errors': <Map<String, dynamic>>[],
            'duplicates': <Map<String, dynamic>>[],
            'inserted': 0,
          };
        },
      );
      expect(sizes, [500, 500, 500, 500]);
      expect(summary.valid, 2000);
      expect(summary.errors, isEmpty);
    });

    test('keeps a partial last chunk', () async {
      final sizes = <int>[];
      await importInChunks(
        rows(1201),
        commit: true,
        call: (chunk, commit) async {
          sizes.add(chunk.length);
          return {'valid': chunk.length, 'inserted': chunk.length};
        },
      );
      expect(sizes, [500, 500, 201]);
    });

    test(
      'adds up errors, duplicates and inserted rows from every chunk',
      () async {
        var call = 0;
        final summary = await importInChunks(
          rows(1000),
          commit: true,
          call: (chunk, commit) async {
            call++;
            return call == 1
                ? {
                    'valid': 498,
                    'inserted': 498,
                    'errors': [
                      {'row': 12, 'code': 'E_CSV_ROW_TOO_LONG'},
                    ],
                    'duplicates': [
                      {'row': 40, 'worker_id': 'W-00031'},
                    ],
                  }
                : {
                    'valid': 500,
                    'inserted': 500,
                    'errors': [
                      {'row': 600, 'code': 'E_CSV_NAME_MISSING'},
                    ],
                    'duplicates': <Map<String, dynamic>>[],
                  };
          },
        );
        expect(summary.valid, 998);
        expect(summary.inserted, 998);
        expect(summary.errors.map((e) => e.row), [12, 600]);
        expect(summary.errors.first.code, 'E_CSV_ROW_TOO_LONG');
        expect(summary.duplicates.single.workerId, 'W-00031');
      },
    );

    test('reports progress after each chunk', () async {
      final progress = <(int, int)>[];
      await importInChunks(
        rows(1100),
        commit: false,
        call: (chunk, commit) async => {'valid': chunk.length},
        onProgress: (done, total) => progress.add((done, total)),
      );
      expect(progress, [(500, 1100), (1000, 1100), (1100, 1100)]);
    });

    test('makes no call for no rows', () async {
      var calls = 0;
      final summary = await importInChunks(
        const [],
        commit: false,
        call: (chunk, commit) async {
          calls++;
          return {};
        },
      );
      expect(calls, 0);
      expect(summary.valid, 0);
    });
  });

  group('confirmedDuplicateRows', () {
    test('marks only the confirmed rows with allow_duplicate', () {
      final rows = [
        {'row': 2, 'name': 'A'},
        {'row': 3, 'name': 'B'},
        {'row': 4, 'name': 'C'},
      ];
      final marked = confirmedDuplicateRows(rows, {3});
      expect(marked.length, 1);
      expect(marked.single['name'], 'B');
      expect(marked.single['allow_duplicate'], isTrue);
      expect(rows[1].containsKey('allow_duplicate'), isFalse);
    });

    test(
      'confirms saved-worker duplicates and repeats in the file together',
      () {
        final rows = [
          {'row': 2, 'name': 'Juan'},
          {'row': 3, 'name': 'Maria'},
          {'row': 4, 'name': 'Juan'},
        ];
        final saved = const [ImportDuplicate(3, 'W-00001')];
        final repeats = findRepeatsInFile(rows);
        final marked = confirmedDuplicateRows(rows, {
          for (final d in saved) d.row,
          for (final r in repeats) r.row,
        });
        expect(marked.map((r) => r['row']), [3, 4]);
        expect(marked.every((r) => r['allow_duplicate'] == true), isTrue);
      },
    );

    test('sends nothing when no row is confirmed', () {
      expect(
        confirmedDuplicateRows([
          {'row': 2, 'name': 'A'},
        ], const {}),
        isEmpty,
      );
    });
  });

  test('parses and chunks a 2,000-row file end to end', () async {
    final buffer = StringBuffer('name,cp_no,address\n');
    for (var i = 0; i < 2000; i++) {
      buffer.writeln('Worker $i,0917$i,Echague');
    }
    final parsed = parseWorkersCsv(buffer.toString());
    expect(parsed.rows.length, 2000);
    expect(parsed.rows.last['row'], 2001);

    var calls = 0;
    await importInChunks(
      parsed.rows,
      commit: false,
      call: (chunk, commit) async {
        calls++;
        expect(chunk.length, lessThanOrEqualTo(maxImportChunk));
        return {'valid': chunk.length};
      },
    );
    expect(calls, 4);
  });
}
