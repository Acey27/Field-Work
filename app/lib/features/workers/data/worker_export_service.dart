import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'worker_service.dart';

class WorkerExportService {
  Future<void> printCard(Map<String, dynamic> worker) async {
    final id = worker['id'] as String;
    final payload = '$id.${worker['qr_check']}';
    final qrData = await QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    ).toImageData(320);
    if (qrData == null) throw StateError('QR image could not be generated');
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                worker['name'] as String,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(id, style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 16),
              pw.Image(pw.MemoryImage(Uint8List.view(qrData.buffer))),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => document.save());
  }

  Future<Map<String, dynamic>> importRows(
    List<Map<String, dynamic>> rows, {
    required bool commit,
  }) async {
    return WorkerService().importWorkers(rows, commit: commit);
  }
}
