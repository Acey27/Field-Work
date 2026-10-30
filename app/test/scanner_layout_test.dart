import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/scanner/presentation/scan_feedback.dart';
import 'package:fieldwork_attendance/features/scanner/presentation/scanner_banners.dart';
import 'package:fieldwork_attendance/shared/widgets/language_toggle.dart';

/// The scanner page builds a camera and a database, so it cannot be pumped in
/// a test. This is its layout (the real ScannerLayout) with a camera stand-in
/// and with every banner showing at once.
Widget _scannerLayout({required bool banners, required double textScale}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          LanguageToggle(onChanged: (_) {}),
          IconButton(
            tooltip: 'Log out',
            onPressed: () {},
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ScannerLayout(
        status: ListTile(
          leading: const Icon(Icons.cloud_done),
          title: const Text('Offline - 12 waiting'),
          trailing: IconButton(
            tooltip: 'Sync',
            onPressed: () {},
            icon: const Icon(Icons.sync),
          ),
        ),
        banners: banners
            ? ScannerBanners(
                closeLabel: 'Close',
                retryLabel: 'Retry',
                readinessMessage: 'This phone is waiting for approval. Ask your admin to approve it.',
                onRetry: () {},
                refused: const [
                  'Juan dela Cruz: not saved. Another technician has this '
                      'worker clocked in. Only that technician can clock them out.',
                  'Maria Santos: not saved. Another technician has this '
                      'worker clocked in. Only that technician can clock them out.',
                ],
                onCloseRefused: () {},
                notices: const [
                  'Worker clocked out: Pedro Reyes (scanned by another technician)',
                ],
                onCloseNotices: () {},
              )
            : const ScannerBanners(closeLabel: 'Close', retryLabel: 'Retry'),
        camera: const ColoredBox(color: Colors.black),
        footer: [
          const ScanFeedbackBanner(
            feedback: ScanFeedback(
              ScanFeedbackKind.attention,
              'This phone is waiting for approval. Ask your admin to approve it.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.videocam_off),
                label: const Text('Close camera'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Workers still clocked in: 12'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('End field day'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  // The console reported "A RenderFlex overflowed by 11 pixels on the bottom".
  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.3]) {
      for (final banners in const [false, true]) {
        testWidgets(
          'the scanner fits ${size.width.toInt()}x${size.height.toInt()} '
          'at text size $scale ${banners ? 'with' : 'without'} banners',
          (tester) async {
            tester.view
              ..devicePixelRatio = 1
              ..physicalSize = size;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              _scannerLayout(banners: banners, textScale: scale),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('three banners scroll inside their share of the screen', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_scannerLayout(banners: true, textScale: 1));
    await tester.pump();

    final height = tester.getSize(find.byType(ScannerBanners)).height;
    expect(height, lessThanOrEqualTo(568 * 0.25 + 0.01));
    expect(find.text('Retry'), findsOneWidget);
  });
}
