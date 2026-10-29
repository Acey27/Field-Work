import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';



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

  /// Cards for many workers on A4 pages (name, ID and QR), 10 per page, ready
  /// to print and cut (SPEC.md section 3: "Makes printable cards").
  Future<Uint8List> buildCardsPdf(List<Map<String, dynamic>> workers) async {
    final document = pw.Document();
    final cards = <pw.Widget>[];
    for (final worker in workers) {
      final id = worker['id'] as String;
      final qrData = await QrPainter(
        data: '$id.${worker['qr_check']}',
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(320);
      if (qrData == null) throw StateError('QR image could not be generated');
      cards.add(
        pw.Container(
          width: 255,
          height: 150,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Row(
            children: [
              pw.Image(
                pw.MemoryImage(Uint8List.view(qrData.buffer)),
                width: 125,
                height: 125,
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      worker['name'] as String,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(id, style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Wrap(spacing: 8, runSpacing: 8, children: cards),
        ],
      ),
    );
    return document.save();
  }

  Future<void> printCards(List<Map<String, dynamic>> workers) async {
    final bytes = await buildCardsPdf(workers);
    await Printing.layoutPdf(name: 'worker-cards', onLayout: (_) async => bytes);
  }
}
