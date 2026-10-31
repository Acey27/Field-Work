import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/l10n/app_localizations.dart';
import '../data/masterlist_print.dart';

/// A full-screen, landscape preview of the masterlist PDF, so the admin can
/// read it before printing. The share button downloads the PDF (on the web),
/// which can be opened and printed from any PDF viewer.
class MasterlistPreviewPage extends StatelessWidget {
  const MasterlistPreviewPage({
    required this.bytes,
    required this.fileName,
    super.key,
  });

  final Uint8List bytes;
  final String fileName;

  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MasterlistPreviewPage(bytes: bytes, fileName: fileName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.printMasterlist)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.masterlistPrintHint),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) async => bytes,
              initialPageFormat: masterlistPageFormat,
              pageFormats: {'Masterlist': masterlistPageFormat},
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: fileName,
              dynamicLayout: false,
            ),
          ),
        ],
      ),
    );
  }
}
