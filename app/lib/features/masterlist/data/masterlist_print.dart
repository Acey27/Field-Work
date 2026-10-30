import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/ph_time.dart';
import 'masterlist.dart';

Future<Uint8List> buildMasterlistPdf({
  required DateTime weekStart,
  required List<MasterlistRow> rows,
  required String weekLabel,
  required String notEndedLabel,
  required List<String> headers,
}) async {
  final document = pw.Document();
  final grouped = <String, List<MasterlistRow>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent(
          '${row.technicianCode}|${row.fieldName}',
          () => <MasterlistRow>[],
        )
        .add(row);
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text(weekLabel, style: pw.Theme.of(context).header2),
        pw.SizedBox(height: 12),
        for (final section in grouped.values) ...[
          pw.Text(
            '${section.first.technicianCode} ${section.first.technicianName} - '
            '${section.first.fieldLabel}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (section.first.fieldAddress?.trim().isNotEmpty == true)
            pw.Text(section.first.fieldAddress!),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: [
              for (final row in section)
                [
                  row.workerId,
                  row.workerName,
                  ...row.minutes.map(
                    (minutes) => minutes == null
                        ? ''
                        : minutes == 0
                        ? notEndedLabel
                        : formatMinutes(minutes),
                  ),
                  formatMinutes(row.totalMinutes),
                  '${row.presentDays}',
                  '',
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      ],
    ),
  );
  return document.save();
}
