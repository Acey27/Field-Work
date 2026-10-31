import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:fieldwork_attendance/features/masterlist/data/masterlist.dart';
import 'package:fieldwork_attendance/features/masterlist/data/masterlist_print.dart';
import 'package:fieldwork_attendance/features/scanner/data/worker_week_service.dart';

void main() {
  test('masterlist row preserves blank days and totals', () {
    final row = MasterlistRow.fromJson({
      'technician_id': 'tech',
      'technician_code': 'T-00001',
      'technician_name': 'John Doe',
      'field_id': 'field',
      'field_name': 'Field 1',
      'field_location': 'North',
      'field_address': 'Address',
      'worker_id': 'W-00001',
      'worker_name': 'Zeann',
      'mon_minutes': 333,
      'tue_minutes': 300,
      'wed_minutes': null,
      'thu_minutes': 370,
      'fri_minutes': 300,
      'sat_minutes': null,
      'sun_minutes': 320,
      'total_minutes': 1623,
      'present_days': 5,
    });

    expect(row.minutes, [333, 300, null, 370, 300, null, 320]);
    expect(row.totalMinutes, 1623);
    expect(row.presentDays, 5);
    expect(row.fieldLabel, 'Field 1 - North');
  });

  test('worker week renders zero minutes as not ended', () {
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), null, 'Not ended'),
      '-',
    );
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), 0, 'Not ended'),
      'Not ended',
    );
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), 333, 'Not ended'),
      '5 hours 33 minutes',
    );
  });

  MasterlistRow row({
    String technicianId = 'tech-1',
    String technicianCode = 'T-00001',
    String technicianName = 'John Doe',
    String fieldId = 'field-1',
    String fieldName = 'Field 1',
    String? fieldLocation,
    String? fieldAddress,
    String workerId = 'W-00001',
    String workerName = 'Zeann',
    List<int?> days = const [333, 300, null, 370, 300, null, 320],
  }) {
    final total = days.whereType<int>().fold<int>(0, (sum, m) => sum + m);
    return MasterlistRow.fromJson({
      'technician_id': technicianId,
      'technician_code': technicianCode,
      'technician_name': technicianName,
      'field_id': fieldId,
      'field_name': fieldName,
      'field_location': fieldLocation,
      'field_address': fieldAddress,
      'worker_id': workerId,
      'worker_name': workerName,
      'mon_minutes': days[0],
      'tue_minutes': days[1],
      'wed_minutes': days[2],
      'thu_minutes': days[3],
      'fri_minutes': days[4],
      'sat_minutes': days[5],
      'sun_minutes': days[6],
      'total_minutes': total,
      'present_days': days.whereType<int>().length,
    });
  }

  const headers = [
    'ID',
    'Name of the Worker',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
    'Total Weekly Hours',
    'Total Weekly Present',
    'Signature',
  ];

  Future<Excel> exported(List<MasterlistRow> rows) async {
    final bytes = await MasterlistService().buildExcel(
      rows: rows,
      weekLabel: '19 Oct 2026 - 25 Oct 2026',
      notEndedLabel: 'Not ended',
      headers: headers,
    );
    return Excel.decodeBytes(bytes);
  }

  /// The text of every cell, row by row (blank cells as empty strings).
  List<List<String>> textOf(Sheet sheet) => [
    for (final cells in sheet.rows)
      [for (final cell in cells) cell?.value?.toString() ?? ''],
  ];

  group('groupMasterlist', () {
    test('makes one section per technician and field, in the given order', () {
      final sections = groupMasterlist([
        row(workerId: 'W-00001'),
        row(workerId: 'W-00002', workerName: 'Czar'),
        row(fieldId: 'field-2', fieldName: 'Field 2', workerId: 'W-00001'),
        row(
          technicianId: 'tech-2',
          technicianCode: 'T-00002',
          technicianName: 'Juan Reyes',
          fieldId: 'field-3',
          fieldName: 'Field 3',
          workerId: 'W-00001',
        ),
      ]);
      expect(sections.map((s) => s.technicianCode), [
        'T-00001',
        'T-00001',
        'T-00002',
      ]);
      expect(sections.map((s) => s.rows.length), [2, 1, 1]);
      expect(sections.first.heading, 'T-00001 John Doe');
    });

    test('has no sections without rows', () {
      expect(groupMasterlist(const []), isEmpty);
    });
  });

  group('Excel export', () {
    test(
      'the data is on the one and only sheet, the one Excel opens',
      () async {
        final excel = await exported([row()]);
        expect(excel.tables.keys, [masterlistSheetName]);
        expect(excel.getDefaultSheet(), masterlistSheetName);
        expect(excel.tables[masterlistSheetName]!.maxRows, greaterThan(1));
      },
    );

    test(
      'lays out the date, the technician line, the headers and rows',
      () async {
        final excel = await exported([
          row(fieldLocation: 'North', fieldAddress: 'Echague'),
          row(
            workerId: 'W-00002',
            workerName: 'Czar',
            days: [600, null, null, 495, 120, 540, null],
          ),
        ]);
        final text = textOf(excel.tables[masterlistSheetName]!);

        expect(text[0][0], 'ID: T-00001');
        expect(text[0][1], 'Name of Technician: John Doe');
        expect(text[0][5], 'Date: 19 Oct 2026 - 25 Oct 2026');
        expect(text[1], headers);
        expect(text[2], [
          'W-00001',
          'Zeann',
          '5 hours 33 minutes',
          '5 hours',
          '',
          '6 hours 10 minutes',
          '5 hours',
          '',
          '5 hours 20 minutes',
          '27 hours 3 minutes',
          '5',
          '',
        ]);
        expect(text[3].sublist(0, 4), ['W-00002', 'Czar', '10 hours', '']);
        // The Signature column is always empty.
        expect(text[2].last, '');
        expect(text[3].last, '');
      },
    );

    test(
      'draws a table: every cell has borders and the headers are shaded',
      () async {
        final excel = await exported([row()]);
        final sheet = excel.tables[masterlistSheetName]!;
        for (final column in [0, 1, 6, 11]) {
          for (final line in [1, 2]) {
            final style = sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: column,
                    rowIndex: line,
                  ),
                )
                .cellStyle;
            expect(
              style?.leftBorder.borderStyle,
              BorderStyle.Thin,
              reason: 'col $column row $line',
            );
            expect(style?.bottomBorder.borderStyle, BorderStyle.Thin);
          }
        }
        // The empty Signature cell is a real, bordered cell.
        final signature = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 2),
        );
        expect(signature.cellStyle?.rightBorder.borderStyle, BorderStyle.Thin);
      },
    );

    test('column widths follow the longest text', () async {
      final short = await exported([row()]);
      final long = await exported([
        row(workerName: 'A worker with a really very long full name indeed'),
      ]);
      double nameWidth(Excel e) =>
          e.tables[masterlistSheetName]!.getColumnWidth(1);
      expect(nameWidth(long), greaterThan(nameWidth(short)));
      // The day columns fit "5 hours 33 minutes"; the signature box is wide.
      final sheet = short.tables[masterlistSheetName]!;
      expect(
        sheet.getColumnWidth(2),
        greaterThanOrEqualTo('5 hours 33 minutes'.length),
      );
      expect(sheet.getColumnWidth(11), greaterThanOrEqualTo(24));
    });

    test('has no Pay column', () async {
      final excel = await exported([row()]);
      final all = textOf(excel.tables[masterlistSheetName]!).expand((r) => r);
      expect(all.where((cell) => cell.toLowerCase().contains('pay')), isEmpty);
    });

    test('a worker with two technicians appears in each section', () async {
      final excel = await exported([
        row(days: [333, null, null, null, null, null, null]),
        row(
          technicianId: 'tech-2',
          technicianCode: 'T-00002',
          technicianName: 'Juan Reyes',
          fieldId: 'field-2',
          fieldName: 'Field 2',
          days: [null, 180, null, null, null, null, null],
        ),
      ]);
      final text = textOf(excel.tables[masterlistSheetName]!);
      final technicianLines = text
          .where((r) => r.first.startsWith('ID: T-'))
          .map((r) => r.first)
          .toList();
      expect(technicianLines, ['ID: T-00001', 'ID: T-00002']);
      expect(text.where((r) => r.first == 'W-00001'), hasLength(2));
      // Hours are kept apart: 5 h 33 m with the first, 3 h with the second.
      expect(text.any((r) => r.contains('5 hours 33 minutes')), isTrue);
      expect(text.any((r) => r.contains('3 hours')), isTrue);
    });

    test('an open session shows the not ended label', () async {
      final excel = await exported([
        row(days: [0, null, null, null, null, null, null]),
      ]);
      final text = textOf(excel.tables[masterlistSheetName]!);
      expect(text[2][2], 'Not ended');
    });

    test('an empty week still makes a valid single sheet', () async {
      final excel = await exported(const []);
      expect(excel.tables.keys, [masterlistSheetName]);
      expect(
        textOf(excel.tables[masterlistSheetName]!).expand((r) => r),
        isEmpty,
      );
    });
  });

  group('Printed masterlist', () {
    Future<Uint8List> pdf(List<MasterlistRow> rows) => buildMasterlistPdf(
      weekStart: DateTime.utc(2026, 10, 19),
      rows: rows,
      weekLabel: '19 Oct 2026 - 25 Oct 2026',
      notEndedLabel: 'Not ended',
      headers: headers,
    );

    /// The width and height of the first page's MediaBox.
    List<double> pageSize(Uint8List bytes) {
      final text = latin1.decode(bytes);
      final match = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]')
          .firstMatch(text)!;
      return [double.parse(match.group(1)!), double.parse(match.group(2)!)];
    }

    test('is a PDF on a landscape page', () async {
      final bytes = await pdf([row()]);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      final size = pageSize(bytes);
      expect(size[0], greaterThan(size[1]));
      expect(
        masterlistPageFormat.width,
        greaterThan(masterlistPageFormat.height),
      );
    });

    test('the table is as wide as the page, with room for the signature', () {
      final widths = masterlistPdfColumnWidths;
      expect(widths.keys, [for (var i = 0; i < headers.length; i++) i]);
      // Shares of the page width: nothing can run past the margin.
      expect(widths.values.every((w) => w is pw.FlexColumnWidth), isTrue);
      final flex = [
        for (final w in widths.values) (w as pw.FlexColumnWidth).flex,
      ];
      final signature = flex.last;
      expect(signature, greaterThanOrEqualTo(2));
      // The signature box is wider than any day column.
      expect(
        signature,
        greaterThan(flex.sublist(2, 9).reduce((a, b) => a > b ? a : b)),
      );
    });

    test('a long list over several sections and pages builds', () async {
      final rows = [
        for (var technician = 1; technician <= 3; technician++)
          for (var worker = 1; worker <= 14; worker++)
            row(
              technicianId: 'tech-$technician',
              technicianCode: 'T-0000$technician',
              technicianName: 'Technician $technician',
              fieldId: 'field-$technician',
              fieldName: 'Field $technician',
              fieldAddress: 'Echague, Isabela',
              workerId: 'W-${worker.toString().padLeft(5, '0')}',
              workerName: 'Worker number $worker with a long name',
            ),
      ];
      final bytes = await pdf(rows);
      expect(bytes.length, greaterThan(1000));
      // 42 rows of 24 pt on a 595 pt tall page need more than one page.
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes));
      expect(pages.length, greaterThan(1));
    });

    test('an empty week still prints a page', () async {
      final bytes = await pdf(const []);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
