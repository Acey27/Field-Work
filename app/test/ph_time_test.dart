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
