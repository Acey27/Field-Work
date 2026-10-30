import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/admin_tools/data/time_records_service.dart';
import 'package:fieldwork_attendance/features/admin_tools/presentation/time_records_page.dart';
import 'package:fieldwork_attendance/features/fields/data/field_service.dart';
import 'package:fieldwork_attendance/features/fields/presentation/fields_page.dart';
import 'package:fieldwork_attendance/features/technicians/data/technician_service.dart';
import 'package:fieldwork_attendance/features/technicians/presentation/technicians_page.dart';

// These pages once refreshed with `setState(() => _list = service.load())`.
// That callback returns the Future, and in a debug build Flutter throws before
// it rebuilds, so a saved change only showed after the browser was reloaded.
// Widget tests run with the same debug checks, so they catch it.

void main() {
  Widget app(Widget page) => MaterialApp(home: page);

  group('time records', () {
    TimeRecord record({required DateTime timeIn}) => TimeRecord(
      sessionId: 's-1',
      workerId: 'W-00001',
      workerName: 'Juan dela Cruz',
      technicianCode: 'T-00001',
      technicianName: 'Mark Cruz',
      fieldName: 'Field 1',
      workDate: '2026-10-30',
      timeIn: timeIn,
      timeOut: timeIn.add(const Duration(hours: 2)),
      enteredByAdmin: false,
      manualReason: null,
    );

    testWidgets('the refresh button shows a record that was fixed', (
      tester,
    ) async {
      final service = _FakeTimeRecords([
        record(timeIn: DateTime.utc(2026, 10, 30, 0)), // 8:00 AM
      ]);
      await tester.pumpWidget(
        app(TimeRecordsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('8:00 AM'), findsOneWidget);

      // Someone fixes the time somewhere else; the admin presses Refresh.
      service.records = [record(timeIn: DateTime.utc(2026, 10, 30, 1))];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.calls, 2);
      expect(find.textContaining('9:00 AM'), findsOneWidget);
      expect(find.textContaining('8:00 AM'), findsNothing);
    });

    testWidgets('a failed refresh keeps the list and says so', (tester) async {
      final service = _FakeTimeRecords([
        record(timeIn: DateTime.utc(2026, 10, 30, 0)),
      ]);
      await tester.pumpWidget(
        app(TimeRecordsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();

      service.failing = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('8:00 AM'), findsOneWidget);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });

    testWidgets('moving to another day loads that day', (tester) async {
      final service = _FakeTimeRecords([
        record(timeIn: DateTime.utc(2026, 10, 30, 0)),
      ]);
      await tester.pumpWidget(
        app(TimeRecordsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      final first = service.dates.last;

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.dates.last, first.subtract(const Duration(days: 1)));
    });
  });

  group('fields', () {
    testWidgets('a new field shows at once, with no manual reload', (
      tester,
    ) async {
      final service = _FakeFields();
      await tester.pumpWidget(
        app(FieldsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Field 1'), findsOneWidget);

      await tester.tap(find.text('Add field'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Field 2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Field 2'), findsOneWidget);
      expect(find.textContaining('could not be completed'), findsNothing);
    });

    testWidgets('turning a field off and on updates the list', (tester) async {
      final service = _FakeFields();
      await tester.pumpWidget(
        app(FieldsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Active'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Inactive'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Inactive'), findsNothing);
    });

    testWidgets('editing a field shows the new name', (tester) async {
      final service = _FakeFields();
      await tester.pumpWidget(
        app(FieldsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit field'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Field One');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Field One'), findsOneWidget);
      expect(find.text('Field 1'), findsNothing);
    });

    testWidgets('a failed save says so and the list stays correct', (
      tester,
    ) async {
      final service = _FakeFields()..failing = true;
      await tester.pumpWidget(
        app(FieldsPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be completed'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);
    });
  });

  // "A RenderFlex overflowed" must not appear on a small phone or browser
  // window, with larger text and long names.
  group('small screens', () {
    Widget scaled(Widget page, double scale) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final scale in const [1.0, 1.3]) {
      testWidgets('the lists and dialogs fit 320x568 at text size $scale', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);

        final records = _FakeTimeRecords([
          TimeRecord(
            sessionId: 's-1',
            workerId: 'W-00001',
            workerName: 'Juan Carlos dela Cruz de Villanueva',
            technicianCode: 'T-00001',
            technicianName: 'Mark Anthony Villanueva-Santos',
            fieldName: 'North Bukid Rice Field Block 12, Echague',
            workDate: '2026-10-30',
            timeIn: DateTime.utc(2026, 10, 30),
            timeOut: DateTime.utc(2026, 10, 30, 9),
            enteredByAdmin: true,
            manualReason: 'Paper sheet, the phone battery died in the field',
          ),
        ]);
        await tester.pumpWidget(
          scaled(
            TimeRecordsPage(onLocaleChanged: (_) {}, service: records),
            scale,
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'time records');

        final fields = _FakeFields()
          ..rows.first['name'] = 'North Bukid Rice Field Block 12, Echague';
        await tester.pumpWidget(
          scaled(FieldsPage(onLocaleChanged: (_) {}, service: fields), scale),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'fields');
        await tester.tap(find.text('Add field'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'add field dialog');
        await tester.tap(find.text('Cancel'));
        await settle(tester);

        final technicians = _FakeTechnicians()
          ..technicians.first['full_name'] = 'Mark Anthony Villanueva-Santos';
        await tester.pumpWidget(
          scaled(
            TechniciansPage(onLocaleChanged: (_) {}, service: technicians),
            scale,
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'technicians');
        await tester.tap(find.text('Create technician'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'create technician');
      });
    }
  });

  group('technicians', () {
    testWidgets('turning an account off and on shows at once', (tester) async {
      final service = _FakeTechnicians();
      await tester.pumpWidget(
        app(TechniciansPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Account off'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Account off'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Account off'), findsNothing);
    });

    testWidgets('assigning a field shows the new field', (tester) async {
      final service = _FakeTechnicians();
      await tester.pumpWidget(
        app(TechniciansPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Field 1'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Field 2'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Field 2'), findsOneWidget);
      expect(find.textContaining('Field 1'), findsNothing);
    });

    testWidgets('a phone shows whose it is, its status and when', (
      tester,
    ) async {
      final service = _FakeTechnicians();
      await tester.pumpWidget(
        app(TechniciansPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Device approvals'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // The owner is the title of the phone's tile, not just "Device".
      expect(find.text('Mark Cruz (T-00003)'), findsWidgets);
      expect(find.textContaining('Waiting for approval'), findsOneWidget);
      expect(find.textContaining('Phone A'), findsOneWidget);
      expect(find.textContaining('Oct 30'), findsNothing); // no raw timestamps
    });

    testWidgets('approving a phone updates its status', (tester) async {
      final service = _FakeTechnicians();
      await tester.pumpWidget(
        app(TechniciansPage(onLocaleChanged: (_) {}, service: service)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Device approvals'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve device'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Waiting for approval'), findsNothing);
      expect(find.textContaining('Approved'), findsOneWidget);
    });
  });
}

class _FakeTimeRecords extends TimeRecordsService {
  _FakeTimeRecords(this.records);

  List<TimeRecord> records;
  int calls = 0;
  bool failing = false;
  final dates = <DateTime>[];

  @override
  Future<List<TimeRecord>> forDate(DateTime phDate) async {
    calls++;
    dates.add(phDate);
    if (failing) throw StateError('offline');
    return records;
  }
}

class _FakeFields extends FieldService {
  final rows = <Map<String, dynamic>>[
    {'id': 'f1', 'name': 'Field 1', 'active': true},
  ];
  bool failing = false;

  @override
  Future<List<Map<String, dynamic>>> listFields() async => [
    for (final row in rows) Map<String, dynamic>.from(row),
  ];

  @override
  Future<Map<String, dynamic>> createField({
    required String name,
    String? location,
    String? address,
  }) async {
    if (failing) throw StateError('failed');
    rows.add({'id': 'f${rows.length + 1}', 'name': name, 'active': true});
    return rows.last;
  }

  @override
  Future<void> updateField({
    required String fieldId,
    required String name,
    String? location,
    String? address,
  }) async {
    if (failing) throw StateError('failed');
    rows.firstWhere((row) => row['id'] == fieldId)['name'] = name;
  }

  @override
  Future<void> setActive({
    required String fieldId,
    required bool active,
  }) async {
    if (failing) throw StateError('failed');
    rows.firstWhere((row) => row['id'] == fieldId)['active'] = active;
  }
}

class _FakeTechnicians extends TechnicianService {
  final technicians = <Map<String, dynamic>>[
    {'id': 't1', 'code': 'T-00003', 'full_name': 'Mark Cruz', 'active': true},
  ];
  final assignments = <Map<String, dynamic>>[
    {
      'technician_id': 't1',
      'field_id': 'f1',
      'fields': {'name': 'Field 1'},
    },
  ];
  final devices = <Map<String, dynamic>>[
    {
      'id': 'd1',
      'technician_id': 't1',
      'label': 'Phone A',
      'status': 'pending',
      'registered_at': '2026-10-30T01:00:00Z',
    },
  ];

  List<Map<String, dynamic>> _copy(List<Map<String, dynamic>> rows) => [
    for (final row in rows) Map<String, dynamic>.from(row),
  ];

  @override
  Future<List<Map<String, dynamic>>> listTechnicians() async =>
      _copy(technicians);

  @override
  Future<List<Map<String, dynamic>>> listFields() async => [
    {'id': 'f1', 'name': 'Field 1', 'active': true},
    {'id': 'f2', 'name': 'Field 2', 'active': true},
  ];

  @override
  Future<List<Map<String, dynamic>>> listAssignments() async =>
      _copy(assignments);

  @override
  Future<List<Map<String, dynamic>>> listDevices() async => _copy(devices);

  @override
  Future<void> assignField({
    required String technicianId,
    required String fieldId,
  }) async {
    assignments
      ..clear()
      ..add({
        'technician_id': technicianId,
        'field_id': fieldId,
        'fields': {'name': fieldId == 'f2' ? 'Field 2' : 'Field 1'},
      });
  }

  @override
  Future<void> setActive({
    required String technicianId,
    required bool active,
  }) async {
    technicians.firstWhere((t) => t['id'] == technicianId)['active'] = active;
  }

  @override
  Future<void> setDeviceStatus(String deviceId, String action) async {
    devices.firstWhere((d) => d['id'] == deviceId)['status'] =
        action == 'approve_device' ? 'approved' : 'revoked';
  }
}
