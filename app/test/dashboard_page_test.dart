import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/utils/ph_time.dart';
import 'package:fieldwork_attendance/features/dashboard/data/admin_service.dart';
import 'package:fieldwork_attendance/features/dashboard/domain/admin_stats.dart';
import 'package:fieldwork_attendance/features/dashboard/presentation/dashboard_page.dart';

class _FakeAdmin extends AdminService {
  _FakeAdmin(this.rows);

  List<Map<String, dynamic>> rows;
  int fieldDayCalls = 0;

  /// When set, the next field-day request waits for it.
  Completer<void>? hold;

  @override
  Future<List<Map<String, dynamic>>> todayFieldDays() async {
    fieldDayCalls++;
    final wait = hold;
    if (wait != null) await wait.future;
    return rows;
  }

  @override
  Future<TodayStats> statsToday() async => const TodayStats(
    clockedInNow: 3,
    finished: 2,
    techniciansWorking: 1,
    fieldsWorking: 1,
    fieldDaysNotEnded: 1,
  );

  @override
  Future<List<FlaggedItem>> flaggedItems(DateTime from, DateTime to) async =>
      const [];
}

Map<String, dynamic> _row({
  required String date,
  required String status,
  String technician = 'Mark Cruz',
  String field = 'Field 1',
  String id = 'a',
}) => {
  'field_day_id': id,
  'work_date': date,
  'technician_id': 't-$id',
  'technician_code': 'T-0000$id',
  'technician_name': technician,
  'field_id': 'f-$id',
  'field_name': field,
  'status': status,
  'ended_at': null,
  'clocked_in_count': 2,
  'worked_count': 4,
  'last_sync_at': null,
};

void main() {
  final today = formatPhDate(phDateOf(DateTime.now()));
  final earlier = formatPhDate(
    phDateOf(DateTime.now()).subtract(const Duration(days: 3)),
  );

  Widget app(AdminService service, {double textScale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: DashboardPage(
      service: service,
      onLocaleChanged: (_) {},
      onWorkers: () {},
      onFields: () {},
      onTechnicians: () {},
      onAdminTools: () {},
      onNotifications: () {},
    ),
  );

  testWidgets('an earlier day that was never ended is listed with its date', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 3000);
    addTearDown(tester.view.reset);
    final service = _FakeAdmin([
      _row(date: today, status: 'ended', id: '1'),
      _row(
        date: earlier,
        status: 'not_ended',
        technician: 'Ana Reyes',
        id: '2',
      ),
    ]);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ana Reyes'), findsOneWidget);
    expect(
      find.textContaining('$earlier · Field 1 · Not ended'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Earlier days that were never ended'),
      findsOneWidget,
    );
    // Only the unended day can be ended; today's ended one cannot.
    expect(find.text('End field day'), findsOneWidget);
  });

  testWidgets('without earlier days there is no hint and no date', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(800, 3000);
    addTearDown(tester.view.reset);
    final service = _FakeAdmin([_row(date: today, status: 'working')]);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Earlier days'), findsNothing);
    expect(find.textContaining('$today ·'), findsNothing);
  });

  testWidgets('the refresh button turns until the page has its data', (
    tester,
  ) async {
    final service = _FakeAdmin([_row(date: today, status: 'working')]);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    final calls = service.fieldDayCalls;

    RotationTransition spinner() => tester.widget<RotationTransition>(
      find.descendant(
        of: find.byTooltip('Refresh'),
        matching: find.byType(RotationTransition),
      ),
    );

    service.hold = Completer<void>();
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.fieldDayCalls, calls + 1);
    expect(spinner().turns.status, AnimationStatus.forward);

    service.hold!.complete();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(spinner().turns.status, AnimationStatus.dismissed);
    expect(tester.takeException(), isNull);
  });

  // The console reported "A RenderFlex overflowed by 11 pixels on the bottom".
  // Long names and larger text must fit a small screen.
  for (final width in const [320.0, 360.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('the dashboard fits ${width.toInt()} px wide'
          ' at text size $scale', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          // Tall, so the whole list is built and checked without scrolling.
          ..physicalSize = Size(width, 4000);
        addTearDown(tester.view.reset);
        final log = _ErrorLog();
        addTearDown(log.stop);
        final service = _FakeAdmin([
          _row(
            date: today,
            status: 'not_ended',
            technician: 'Mark Anthony Villanueva-Santos',
            field: 'North Bukid Rice Field Block 12, Echague',
            id: '1',
          ),
          _row(date: earlier, status: 'not_ended', id: '2'),
          _row(date: today, status: 'ended', id: '3'),
        ]);
        await tester.pumpWidget(app(service, textScale: scale));
        // Not pumpAndSettle: a layout error repeats on every frame, and it would
        // never settle, hiding the message.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // The message names the widget and the file that overflowed.
        log.stop();
        expect(log.messages, isEmpty, reason: log.messages.join('\n\n'));
      });
    }
  }
}

/// Collects the layout errors Flutter reports instead of letting the test
/// framework reduce them to one line. Call [stop] before the test's own
/// expectations, which hands error reporting back to the framework.
class _ErrorLog {
  _ErrorLog() : _original = FlutterError.onError {
    FlutterError.onError = (details) => messages.add(details.toString());
  }

  final void Function(FlutterErrorDetails)? _original;
  final messages = <String>[];

  void stop() => FlutterError.onError = _original;
}
