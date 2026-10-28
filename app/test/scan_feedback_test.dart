import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/scanner/presentation/scan_feedback.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1B5E20),
      secondary: Color(0xFFF9A825),
      error: Color(0xFFB71C1C),
    ),
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the banner shows the message for each state', (tester) async {
    for (final feedback in const [
      ScanFeedback(ScanFeedbackKind.idle, 'Looking for a QR code...'),
      ScanFeedback(ScanFeedbackKind.detected, 'QR code detected'),
      ScanFeedback(ScanFeedbackKind.success, 'Juan: CLOCKED IN 6:02 AM'),
      ScanFeedback(ScanFeedbackKind.attention, 'Already scanned a moment ago.'),
      ScanFeedback(ScanFeedbackKind.error, 'This card is not valid.'),
    ]) {
      await tester.pumpWidget(_wrap(ScanFeedbackBanner(feedback: feedback)));
      expect(find.text(feedback.message), findsOneWidget);
    }
  });

  testWidgets('each state has its own banner color', (tester) async {
    Color colorOf(WidgetTester tester) => tester
        .widget<Container>(
          find
              .descendant(
                of: find.byType(ScanFeedbackBanner),
                matching: find.byType(Container),
              )
              .first,
        )
        .color!;

    final colors = <ScanFeedbackKind, Color>{};
    for (final kind in ScanFeedbackKind.values) {
      await tester.pumpWidget(
        _wrap(ScanFeedbackBanner(feedback: ScanFeedback(kind, 'x'))),
      );
      colors[kind] = colorOf(tester);
    }
    expect(colors[ScanFeedbackKind.success], const Color(0xFF1B5E20));
    expect(colors[ScanFeedbackKind.detected], const Color(0xFFF9A825));
    expect(colors[ScanFeedbackKind.error], const Color(0xFFB71C1C));
    expect(colors[ScanFeedbackKind.success], isNot(colors[ScanFeedbackKind.error]));
  });

  testWidgets('the camera off panel tells the technician what to do', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CameraOffPanel()));
    expect(find.textContaining('Open camera'), findsOneWidget);
  });

  testWidgets('the camera error panel has a retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(CameraErrorPanel(onRetry: () => retried = true)),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('the frame changes color when a QR code is detected', (
    tester,
  ) async {
    Color frameColor(WidgetTester tester) {
      final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    await tester.pumpWidget(_wrap(const ScanFrame(kind: ScanFeedbackKind.idle)));
    expect(frameColor(tester), Colors.white);
    await tester.pumpWidget(
      _wrap(const ScanFrame(kind: ScanFeedbackKind.detected)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(frameColor(tester), const Color(0xFFF9A825));
  });
}
