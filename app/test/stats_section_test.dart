import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/utils/refresh_group.dart';
import 'package:fieldwork_attendance/features/dashboard/data/admin_service.dart';
import 'package:fieldwork_attendance/features/dashboard/domain/admin_stats.dart';
import 'package:fieldwork_attendance/features/dashboard/presentation/flagged_section.dart';
import 'package:fieldwork_attendance/features/dashboard/presentation/stats_section.dart';

/// Answers without Supabase and counts the calls.
class FakeAdminService extends AdminService {
  int todayCalls = 0;
  int flaggedCalls = 0;
  final weekStarts = <DateTime>[];
  int clockedInNow = 3;

  /// When true every call fails, like a dropped connection.
  bool failing = false;

  @override
  Future<List<FlaggedItem>> flaggedItems(DateTime from, DateTime to) async {
    flaggedCalls++;
    if (failing) throw StateError('offline');
    return [
      FlaggedItem(
        kind: 'outside_hours',
        worker: 'Zeann',
        technician: 'John Doe',
        technicianCode: 'T-00001',
        fieldName: 'Field 1',
        at: DateTime.utc(2026, 10, 29, 22, 30),
      ),
    ];
  }

  @override
  Future<TodayStats> statsToday() async {
    todayCalls++;
    if (failing) throw StateError('offline');
    return TodayStats(
      clockedInNow: clockedInNow,
      finished: 2,
      techniciansWorking: 1,
      fieldsWorking: 1,
      fieldDaysNotEnded: 0,
    );
  }

  @override
  Future<WeekStats> statsWeek(DateTime weekStart) async {
    weekStarts.add(weekStart);
    if (failing) throw StateError('offline');
    return WeekStats(
      days: [
        for (var i = 0; i < 7; i++)
          DayStat(
            date: weekStart.add(Duration(days: i)),
            workersPresent: i,
            totalMinutes: i * 60,
          ),
      ],
      byField: const [
        FieldStat(fieldName: 'Field 1', presentDays: 9, totalMinutes: 2700),
      ],
      workersPresent: 21,
      totalMinutes: 1260,
      previousWorkersPresent: 18,
      previousTotalMinutes: 1000,
    );
  }
}

void main() {
  // The dashboard puts the statistics in a ListView, which gives its children
  // unbounded height. A card with a Spacer cannot be laid out there.
  Widget inDashboard(Widget child) => MaterialApp(
    home: Scaffold(body: ListView(children: [child])),
  );

  testWidgets(
    'Weekly builds inside a scrolling page and the arrows move the week',
    (tester) async {
      final service = FakeAdminService();
      await tester.pumpWidget(inDashboard(StatsSection(service: service)));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget); // clocked in now

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Last week'), findsOneWidget);

      final shown = service.weekStarts.last;
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.weekStarts.last, shown.subtract(const Duration(days: 7)));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.weekStarts.last, shown.add(const Duration(days: 7)));

      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'a refresh tick shows new numbers and keeps Weekly and the week',
    (tester) async {
      final service = FakeAdminService();
      final tick = RefreshGroup();
      await tester.pumpWidget(
        inDashboard(StatsSection(service: service, refresh: tick)),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // The technicians scan more workers; the next tick shows it.
      service.clockedInNow = 8;
      unawaited(tick.run());
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(find.text('3'), findsNothing);

      // Look at the week before this one, then let the tick run.
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      final viewed = service.weekStarts.last;
      final calls = service.weekStarts.length;
      unawaited(tick.run());
      await tester.pumpAndSettle();
      expect(service.weekStarts.length, calls + 1);
      expect(service.weekStarts.last, viewed);
      expect(find.text('This week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed refresh keeps the numbers that are on screen', (
    tester,
  ) async {
    final service = FakeAdminService();
    final tick = RefreshGroup();
    await tester.pumpWidget(
      inDashboard(StatsSection(service: service, refresh: tick)),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    service.failing = true;
    unawaited(tick.run());
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('the flagged list refreshes and survives a failed refresh', (
    tester,
  ) async {
    final service = FakeAdminService();
    final tick = RefreshGroup();
    await tester.pumpWidget(
      inDashboard(FlaggedSection(service: service, refresh: tick)),
    );
    await tester.pumpAndSettle();
    expect(service.flaggedCalls, 1);
    expect(find.text('Outside scan hours'), findsOneWidget);

    unawaited(tick.run());
    await tester.pumpAndSettle();
    expect(service.flaggedCalls, 2);

    service.failing = true;
    unawaited(tick.run());
    await tester.pumpAndSettle();
    expect(service.flaggedCalls, 3);
    expect(find.text('Outside scan hours'), findsOneWidget);
  });

  testWidgets('Weekly builds with large text and an empty week', (
    tester,
  ) async {
    final service = FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(children: [StatsSection(service: service)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
