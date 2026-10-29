import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';

/// Data for the printable daily paper sheet (SPEC.md section 8, CONTRACT.md
/// section 17 item 3: the technician's usual workers are those scanned in the
/// last 14 days).
class PaperSheet {
  const PaperSheet({
    required this.technicianCode,
    required this.technicianName,
    required this.fieldName,
    required this.workDate,
    required this.workers,
  });

  factory PaperSheet.fromJson(Map<String, dynamic> json) {
    final technician = json['technician'] as Map<String, dynamic>;
    final field = json['field'] as Map<String, dynamic>?;
    return PaperSheet(
      technicianCode: technician['code'] as String? ?? '',
      technicianName: technician['name'] as String? ?? '',
      fieldName: field?['name'] as String?,
      workDate: json['work_date'] as String,
      workers: (json['workers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (w) => SheetWorker(id: w['id'] as String, name: w['name'] as String),
          )
          .toList(),
    );
  }

  final String technicianCode;
  final String technicianName;
  final String? fieldName;
  final String workDate;
  final List<SheetWorker> workers;
}

class SheetWorker {
  const SheetWorker({required this.id, required this.name});
  final String id;
  final String name;
}

/// Rows of the sheet: the usual workers first, then blank rows for extra
/// workers who are written in by ID. There are always at least [minimumRows]
/// rows and at least [extraRows] blank ones.
List<SheetWorker?> sheetRows(
  List<SheetWorker> workers, {
  int extraRows = 8,
  int minimumRows = 25,
}) {
  final total = workers.length + extraRows;
  final length = total < minimumRows ? minimumRows : total;
  return [for (var i = 0; i < length; i++) i < workers.length ? workers[i] : null];
}

class PaperSheetService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<PaperSheet> load({
    required String technicianId,
    required DateTime date,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
    final value = await _client.rpc<Map<String, dynamic>>(
      'get_paper_sheet',
      params: {'p_technician_id': technicianId, 'p_date': formatPhDate(date)},
    );
    return PaperSheet.fromJson(value);
  }
}

/// The sheet as a PDF. All labels come from [l10n], so it follows the
/// language toggle (English or Filipino).
Future<Uint8List> buildPaperSheetPdf(
  PaperSheet sheet,
  AppLocalizations l10n,
) async {
  final document = pw.Document();
  final bold = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
  const body = pw.TextStyle(fontSize: 14);
  final rows = sheetRows(sheet.workers);

  pw.Widget cell(String text, {pw.TextStyle? style, double height = 28}) =>
      pw.Container(
        height: height,
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Text(text, style: style ?? body, maxLines: 1),
      );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.sheetTitle,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${l10n.sheetTechnician}: ${sheet.technicianCode} '
            '${sheet.technicianName}',
            style: bold,
          ),
          pw.Text(
            '${l10n.sheetField}: ${sheet.fieldName ?? l10n.noField}',
            style: bold,
          ),
          pw.Text('${l10n.sheetDate}: ${sheet.workDate}', style: bold),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Text(l10n.sheetExtra, style: const pw.TextStyle(fontSize: 11)),
      build: (context) => [
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FixedColumnWidth(34),
            1: pw.FixedColumnWidth(70),
            2: pw.FlexColumnWidth(),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                cell(l10n.sheetNo, style: bold),
                cell(l10n.sheetId, style: bold),
                cell(l10n.sheetName, style: bold),
                cell(l10n.sheetTimeIn, style: bold),
                cell(l10n.sheetTimeOut, style: bold),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              pw.TableRow(
                children: [
                  cell('${i + 1}'),
                  cell(rows[i]?.id ?? ''),
                  cell(rows[i]?.name ?? ''),
                  cell(''),
                  cell(''),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return document.save();
}
