import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/l10n/app_localizations.dart';
import 'package:fieldwork_attendance/features/admin_tools/data/paper_sheet.dart';

void main() {
  const sheet = PaperSheet(
    technicianCode: 'T-00001',
    technicianName: 'John Doe',
    fieldName: 'Field 1',
    workDate: '2026-10-29',
    workers: [
      SheetWorker(id: 'W-00001', name: 'Zeann'),
      SheetWorker(id: 'W-00002', name: 'Czar'),
    ],
  );

  group('sheetRows', () {
    test('lists the usual workers first, then blank rows', () {
      final rows = sheetRows(sheet.workers);
      expect(rows[0]?.id, 'W-00001');
      expect(rows[1]?.id, 'W-00002');
      expect(rows[2], isNull);
    });

    test('has at least 25 rows so there is room for extra workers', () {
      expect(sheetRows(const []).length, 25);
      expect(sheetRows(sheet.workers).length, 25);
    });

    test('keeps at least 8 blank rows for a long list', () {
      final workers = [
        for (var i = 0; i < 40; i++) SheetWorker(id: 'W-${i + 1}', name: 'N$i'),
      ];
      final rows = sheetRows(workers);
      expect(rows.length, 48);
      expect(rows.where((row) => row == null).length, 8);
    });
  });

  group('PaperSheet.fromJson', () {
    test('reads the get_paper_sheet answer', () {
      final parsed = PaperSheet.fromJson({
        'technician': {'id': 'x', 'code': 'T-00001', 'name': 'John Doe'},
        'field': {'id': 'f', 'name': 'Field 1', 'location': 'Echague'},
        'work_date': '2026-10-29',
        'workers': [
          {'id': 'W-00001', 'name': 'Zeann'},
        ],
      });
      expect(parsed.technicianName, 'John Doe');
      expect(parsed.fieldName, 'Field 1');
      expect(parsed.workers.single.id, 'W-00001');
    });

    test('accepts a technician with no field', () {
      final parsed = PaperSheet.fromJson({
        'technician': {'id': 'x', 'code': 'T-00001', 'name': 'John Doe'},
        'field': null,
        'work_date': '2026-10-29',
        'workers': <Map<String, dynamic>>[],
      });
      expect(parsed.fieldName, isNull);
      expect(parsed.workers, isEmpty);
    });
  });

  group('buildPaperSheetPdf', () {
    test('makes a PDF in English', () async {
      final bytes = await buildPaperSheetPdf(
        sheet,
        const AppLocalizations(Locale('en')),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('makes a PDF in Filipino', () async {
      final bytes = await buildPaperSheetPdf(
        sheet,
        const AppLocalizations(Locale('fil')),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('makes a PDF with no workers and no field', () async {
      final bytes = await buildPaperSheetPdf(
        const PaperSheet(
          technicianCode: 'T-00002',
          technicianName: 'Juan Reyes',
          fieldName: null,
          workDate: '2026-10-29',
          workers: [],
        ),
        const AppLocalizations(Locale('en')),
      );
      expect(bytes, isNotEmpty);
    });
  });
}
