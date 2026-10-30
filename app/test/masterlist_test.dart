import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/masterlist/data/masterlist.dart';
import 'package:fieldwork_attendance/features/scanner/data/worker_week_service.dart';

void main() {
  test('masterlist row preserves blank days and totals', () {
    final row = MasterlistRow.fromJson({
      'technician_id': 'tech',
      'technician_code': 'T-00001',
      'technician_name': 'John Doe',
      'field_id': 'field',
      'field_name': 'Field 1',
      'field_location': 'North',
      'field_address': 'Address',
      'worker_id': 'W-00001',
      'worker_name': 'Zeann',
      'mon_minutes': 333,
      'tue_minutes': 300,
      'wed_minutes': null,
      'thu_minutes': 370,
      'fri_minutes': 300,
      'sat_minutes': null,
      'sun_minutes': 320,
      'total_minutes': 1623,
      'present_days': 5,
    });

    expect(row.minutes, [333, 300, null, 370, 300, null, 320]);
    expect(row.totalMinutes, 1623);
    expect(row.presentDays, 5);
    expect(row.fieldLabel, 'Field 1 - North');
  });

  test('worker week renders zero minutes as not ended', () {
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), null, 'Not ended'),
      '-',
    );
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), 0, 'Not ended'),
      'Not ended',
    );
    expect(
      workerWeekDayLabel(DateTime.utc(2026, 10, 19), 333, 'Not ended'),
      '5 hours 33 minutes',
    );
  });

  test('builds a non-empty Excel workbook', () async {
    final bytes = await MasterlistService().buildExcel(
      rows: [
        MasterlistRow.fromJson({
          'technician_id': 'tech',
          'technician_code': 'T-00001',
          'technician_name': 'John Doe',
          'field_id': 'field',
          'field_name': 'Field 1',
          'field_location': null,
          'field_address': null,
          'worker_id': 'W-00001',
          'worker_name': 'Zeann',
          'mon_minutes': 333,
          'tue_minutes': null,
          'wed_minutes': null,
          'thu_minutes': null,
          'fri_minutes': null,
          'sat_minutes': null,
          'sun_minutes': null,
          'total_minutes': 333,
          'present_days': 1,
        }),
      ],
      weekLabel: '19-25 Oct 2026',
      notEndedLabel: 'Not ended',
      headers: const ['ID', 'Name', 'Monday'],
    );

    expect(bytes, isNotEmpty);
  });
}
