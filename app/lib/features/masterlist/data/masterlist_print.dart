import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/ph_time.dart';
import 'masterlist.dart';

/// The printed masterlist is landscape: twelve columns do not fit a portrait
/// page. The page is 720 x 520 pt, smaller than both A4 and Letter landscape,
/// because the browser's print window prints a PDF at full size on the paper
/// (Letter by default) and leaves a margin: a full A4 landscape page (842 pt
/// wide) lost its right end, the Signature column, on Letter paper. This page
/// fits either paper with the printer's margins. Pass it as `format` to the
/// preview as well.
const masterlistPageFormat = PdfPageFormat(720, 520);

const _margin = 24.0;

/// Column widths as shares of the page width, so the table is exactly as wide
/// as the page and no column (the Signature one is last) runs off the edge.
/// ID, name, Monday to Sunday, total hours, total present, signature.
final masterlistPdfColumnWidths = <int, pw.TableColumnWidth>{
  0: const pw.FlexColumnWidth(1.0),
  1: const pw.FlexColumnWidth(2.3),
  for (var day = 2; day <= 8; day++) day: const pw.FlexColumnWidth(1.5),
  9: const pw.FlexColumnWidth(1.8),
  10: const pw.FlexColumnWidth(1.0),
  11: const pw.FlexColumnWidth(2.6),
};

Future<Uint8List> buildMasterlistPdf({
  required DateTime weekStart,
  required List<MasterlistRow> rows,
  required String weekLabel,
  required String notEndedLabel,
  required List<String> headers,
}) async {
  final document = pw.Document();
  final sections = groupMasterlist(rows);

  document.addPage(
    pw.MultiPage(
      pageFormat: masterlistPageFormat,
      margin: const pw.EdgeInsets.all(_margin),
      build: (context) => [
        for (final section in sections) ...[
          pw.Text(
            '${section.heading}   Date: $weekLabel',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: [
              for (final row in section.rows)
                [
                  row.workerId,
                  row.workerName,
                  for (final minutes in row.minutes)
                    masterlistDayText(minutes, notEndedLabel),
                  formatMinutes(row.totalMinutes),
                  '${row.presentDays}',
                  '',
                ],
            ],
            columnWidths: masterlistPdfColumnWidths,
            tableWidth: pw.TableWidth.max,
            border: pw.TableBorder.all(width: 0.5),
            // Tall enough to sign in the last column.
            cellHeight: 24,
            headerHeight: 28,
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 2,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );
  return document.save();
}
