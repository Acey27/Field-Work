import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/scanner/domain/sync_schedule.dart';

void main() {
  group('retryDelay', () {
    test('waits 30 s, 1 min, 2 min, then 5 min (CONTRACT section 8)', () {
      expect(retryDelay(1), const Duration(seconds: 30));
      expect(retryDelay(2), const Duration(minutes: 1));
      expect(retryDelay(3), const Duration(minutes: 2));
      expect(retryDelay(4), const Duration(minutes: 5));
    });

    test('stays at 5 minutes after that', () {
      expect(retryDelay(5), const Duration(minutes: 5));
      expect(retryDelay(50), const Duration(minutes: 5));
    });

    test('treats zero or fewer failures as the first wait', () {
      expect(retryDelay(0), const Duration(seconds: 30));
    });
  });

  group('SyncThrottle', () {
    final start = DateTime.utc(2026, 10, 29, 1);

    test('allows the first sync at once', () {
      expect(SyncThrottle().remaining(start), Duration.zero);
    });

    test('blocks another sync inside 30 seconds and says how long', () {
      final throttle = SyncThrottle()..markStarted(start);
      expect(
        throttle.remaining(start.add(const Duration(seconds: 29))),
        const Duration(seconds: 1),
      );
      expect(
        throttle.remaining(start.add(const Duration(seconds: 10))),
        const Duration(seconds: 20),
      );
    });

    test('allows a sync at exactly 30 seconds', () {
      final throttle = SyncThrottle()..markStarted(start);
      expect(
        throttle.remaining(start.add(const Duration(seconds: 30))),
        Duration.zero,
      );
    });
  });

  group('isBatchLevelError', () {
    test('stops the loop for device and account errors', () {
      for (final code in [
        'E_DEVICE_PENDING',
        'E_DEVICE_NOT_APPROVED',
        'E_DEVICE_REVOKED',
        'E_ACCOUNT_DISABLED',
      ]) {
        expect(isBatchLevelError(code), isTrue, reason: code);
      }
    });

    test('keeps retrying for network and other errors', () {
      expect(isBatchLevelError('E_BATCH_TOO_LARGE'), isFalse);
      expect(isBatchLevelError('SocketException'), isFalse);
      expect(isBatchLevelError(null), isFalse);
    });
  });
}
