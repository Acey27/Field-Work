import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fieldwork_attendance/app.dart';

void main() {
  testWidgets('shows the localized login scaffold', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AttendanceApp(initialLocale: Locale('en'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('QR Attendance'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
