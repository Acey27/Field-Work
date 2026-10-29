import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/l10n/app_localizations.dart';
import 'package:fieldwork_attendance/features/dashboard/domain/admin_stats.dart';
import 'package:fieldwork_attendance/features/dashboard/presentation/flagged_section.dart';
import 'package:fieldwork_attendance/features/dashboard/presentation/stats_section.dart';

void main() {
  group('TodayStats.fromJson', () {
    test('reads the get_stats_today answer', () {
      final stats = TodayStats.fromJson({
        'clocked_in_now': 12,
        'finished': 30,
        'technicians_working': 5,
        'fields_working': 4,
        'field_days_not_ended': 2,
      });
      expect(stats.clockedInNow, 12);
      expect(stats.finished, 30);
      expect(stats.techniciansWorking, 5);
      expect(stats.fieldsWorking, 4);
      expect(stats.fieldDaysNotEnded, 2);
    });

    test('treats missing numbers as zero', () {
      expect(TodayStats.fromJson(const {}).clockedInNow, 0);
    });
  });

  group('WeekStats.fromJson', () {
    final json = <String, dynamic>{
      'week_start': '2026-10-19',
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-10-${19 + i}',
            'workers_present': i,
            'total_minutes': i * 60,
          },
      ],
      'attendance_by_field': [
        {
          'field_id': 'f1',
          'field_name': 'Field 1',
          'present_days': 9,
          'total_minutes': 2700,
        },
      ],
      'totals': {'workers_present': 21, 'total_minutes': 1260},
      'previous': {'workers_present': 18, 'total_minutes': 1000},
    };

    test('reads days, fields, totals and the previous week', () {
      final stats = WeekStats.fromJson(json);
      expect(stats.days.length, 7);
      expect(stats.days[2].workersPresent, 2);
      expect(stats.days[6].totalMinutes, 360);
      expect(stats.byField.single.fieldName, 'Field 1');
      expect(stats.byField.single.presentDays, 9);
      expect(stats.workersPresent, 21);
      expect(stats.totalMinutes, 1260);
      expect(stats.previousWorkersPresent, 18);
      expect(stats.previousTotalMinutes, 1000);
    });

    test('copes with an empty week', () {
      final stats = WeekStats.fromJson({
        'days': <Map<String, dynamic>>[],
        'attendance_by_field': <Map<String, dynamic>>[],
      });
      expect(stats.days, isEmpty);
      expect(stats.totalMinutes, 0);
    });
  });

  group('FlaggedItem.fromJson', () {
    test('reads the row shape from CONTRACT section 4.12', () {
      final item = FlaggedItem.fromJson({
        'kind': 'outside_hours',
        'scan_id': 's',
        'technician': 'John Doe',
        'technician_code': 'T-00001',
        'worker': 'Zeann',
        'at': '2026-10-29T22:30:00Z',
        'detail': {'field_name': 'Field 1', 'result': 'clocked_in'},
      });
      expect(item.kind, 'outside_hours');
      expect(item.worker, 'Zeann');
      expect(item.fieldName, 'Field 1');
      expect(item.at, DateTime.utc(2026, 10, 29, 22, 30));
    });
  });

  group('labels', () {
    const english = AppLocalizations(Locale('en'));
    const filipino = AppLocalizations(Locale('fil'));

    test('every flag kind has a readable label in both languages', () {
      for (final kind in [
        'outside_hours',
        'clock_skew',
        'after_field_end',
        'safety_net_close',
        'no_location',
        'burst',
      ]) {
        expect(english.flagLabel(kind), isNot(kind), reason: kind);
        expect(filipino.flagLabel(kind), isNot(kind), reason: kind);
      }
    });

    test('durations read in hours and minutes', () {
      expect(english.durationShort(333), '5 h 33 min');
      expect(english.durationShort(0), '0 h 0 min');
      expect(filipino.durationShort(1623), '27 oras 3 min');
    });
  });

  group('widgets', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('bar heights are proportional to the values', (tester) async {
      await tester.pumpWidget(
        wrap(
          const BarChart(
            height: 100,
            bars: [
              BarValue(label: 'A', value: 10, text: '10'),
              BarValue(label: 'B', value: 5, text: '5'),
              BarValue(label: 'C', value: 0, text: '0'),
            ],
          ),
        ),
      );
      double heightOf(String label) =>
          tester.getSize(find.byKey(ValueKey('bar-$label'))).height;
      expect(tester.takeException(), isNull);
      expect(heightOf('A'), greaterThan(0));
      expect(heightOf('B'), closeTo(heightOf('A') / 2, 0.01));
      expect(heightOf('C'), 2); // an empty day is a thin line
    });

    testWidgets('large text does not overflow the chart', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: BarChart(
                bars: [
                  BarValue(label: 'M', value: 8, text: '8'),
                  BarValue(label: 'T', value: 4, text: '4'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an all-zero chart still draws without dividing by zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const BarChart(bars: [BarValue(label: 'A', value: 0, text: '0')]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a stat card shows its number and label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatCard(
            label: 'Clocked in now',
            value: '12',
            icon: Icons.groups,
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Clocked in now'), findsOneWidget);
    });

    testWidgets('a flagged tile shows a readable label, not the raw kind', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FlaggedTile(
            item: FlaggedItem(
              kind: 'outside_hours',
              worker: 'Zeann',
              technician: 'John Doe',
              technicianCode: 'T-00001',
              fieldName: 'Field 1',
              at: DateTime.utc(2026, 10, 29, 22, 30),
            ),
          ),
        ),
      );
      expect(find.text('Outside scan hours'), findsOneWidget);
      expect(find.textContaining('outside_hours'), findsNothing);
      expect(find.textContaining('6:30 AM'), findsOneWidget); // 22:30 UTC
    });
  });
}
