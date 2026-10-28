import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/utils/ph_time.dart';

void main() {
  group('phDateOf', () {
    test('keeps 15:59 UTC on the same Philippine date', () {
      expect(
        phDateOf(DateTime.utc(2026, 10, 19, 15, 59)),
        DateTime.utc(2026, 10, 19),
      );
    });

    test('moves 16:00 UTC to the next Philippine date', () {
      expect(
        phDateOf(DateTime.utc(2026, 10, 19, 16)),
        DateTime.utc(2026, 10, 20),
      );
    });
  });

  test('finds the Monday of a Philippine week', () {
    expect(phWeekStart(DateTime.utc(2026, 10, 21)), DateTime.utc(2026, 10, 19));
  });

  group('Philippine time of day', () {
    test('formats the date as YYYY-MM-DD', () {
      expect(formatPhDate(DateTime.utc(2026, 1, 5)), '2026-01-05');
    });

    test('converts 4:52 PM Philippine time to 08:52 UTC', () {
      expect(
        phTimeToUtc(DateTime.utc(2026, 10, 19), 16, 52),
        DateTime.utc(2026, 10, 19, 8, 52),
      );
    });

    test('converts 12:30 AM Philippine time to the previous UTC day', () {
      expect(
        phTimeToUtc(DateTime.utc(2026, 10, 20), 0, 30),
        DateTime.utc(2026, 10, 19, 16, 30),
      );
    });

    test('formats clock times with AM and PM', () {
      expect(formatPhTime(DateTime.utc(2026, 10, 19, 22, 2)), '6:02 AM');
      expect(formatPhTime(DateTime.utc(2026, 10, 19, 8, 52)), '4:52 PM');
      expect(formatPhTime(DateTime.utc(2026, 10, 19, 15, 59)), '11:59 PM');
      expect(formatPhTime(DateTime.utc(2026, 10, 19, 16)), '12:00 AM');
    });
  });

  group('formatMinutes', () {
    test('formats exact hours without minutes', () {
      expect(formatMinutes(60), '1 hour');
      expect(formatMinutes(120), '2 hours');
    });

    test('formats 61 minutes with singular units', () {
      expect(formatMinutes(61), '1 hour 1 minute');
    });

    test('formats zero as zero minutes', () {
      expect(formatMinutes(0), '0 minutes');
    });

    test('formats the contract example', () {
      expect(formatMinutes(333), '5 hours 33 minutes');
    });
  });
}
