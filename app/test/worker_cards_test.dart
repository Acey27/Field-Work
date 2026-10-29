import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/workers/data/worker_export_service.dart';

void main() {
  List<Map<String, dynamic>> workers(int count) => [
    for (var i = 1; i <= count; i++)
      {'id': 'W-${i.toString().padLeft(5, '0')}', 'name': 'Worker $i', 'qr_check': 'abc'},
  ];

  testWidgets('makes one PDF with many cards', (tester) async {
    final bytes = await tester.runAsync(
      () => WorkerExportService().buildCardsPdf(workers(25)),
    );
    expect(bytes, isNotNull);
    expect(latin1.decode(bytes!.sublist(0, 5)), '%PDF-');
    // 25 cards at 10 per page need 3 pages (page objects, not the page tree).
    final pages = RegExp(
      r'/Type\s*/Page(?![a-zA-Z])',
    ).allMatches(latin1.decode(bytes)).length;
    expect(pages, 3);
  });

  testWidgets('more cards make a bigger file', (tester) async {
    final one = await tester.runAsync(
      () => WorkerExportService().buildCardsPdf(workers(1)),
    );
    final many = await tester.runAsync(
      () => WorkerExportService().buildCardsPdf(workers(25)),
    );
    expect(many!.length, greaterThan(one!.length * 3));
  });

  testWidgets('makes a PDF for a single card', (tester) async {
    final bytes = await tester.runAsync(
      () => WorkerExportService().buildCardsPdf(workers(1)),
    );
    expect(bytes, isNotEmpty);
  });
}
