import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/notifications/data/notification_service.dart';
import 'package:fieldwork_attendance/features/scanner/domain/clocked_out_notice.dart';

void main() {
  AppNotification notice(
    String id, {
    String type = workerClockedOutType,
    bool read = false,
  }) => AppNotification(
    id: id,
    type: type,
    params: const {'worker_name': 'Test worker two', 'reason': 'safety_net'},
    target: null,
    readAt: read ? DateTime.utc(2026, 10, 30, 1) : null,
    createdAt: DateTime.utc(2026, 10, 30),
  );

  group('unreadClockedOutNotices', () {
    test('keeps unread clock-out notices in the given order', () {
      final result = unreadClockedOutNotices([notice('b'), notice('a')]);
      expect(result.map((n) => n.id), ['b', 'a']);
    });

    test('drops notices that are read or of another type', () {
      final result = unreadClockedOutNotices([
        notice('read', read: true),
        notice('other', type: 'device_approval_needed'),
        notice('keep'),
      ]);
      expect(result.map((n) => n.id), ['keep']);
    });

    test('drops notices dismissed on this phone while offline', () {
      final result = unreadClockedOutNotices(
        [notice('a'), notice('b')],
        dismissed: {'a'},
      );
      expect(result.map((n) => n.id), ['b']);
    });

    test('is empty when there is nothing to show', () {
      expect(unreadClockedOutNotices(const []), isEmpty);
    });
  });

  group('takenOverCutoffs', () {
    AppNotification takeover(
      String id,
      String workerId,
      String timeOut, {
      bool read = false,
      String type = workerClockedOutType,
    }) => AppNotification(
      id: id,
      type: type,
      params: {'worker_id': workerId, 'time_out': timeOut},
      target: null,
      readAt: read ? DateTime.utc(2026, 10, 30, 5) : null,
      createdAt: DateTime.utc(2026, 10, 30),
    );

    test(
      'gives each taken-over worker a cutoff a minute after the takeover',
      () {
        final cutoffs = takenOverCutoffs([
          takeover('a', 'W-00001', '2026-10-30T02:00:00+00:00'),
        ]);
        expect(cutoffs.keys, ['W-00001']);
        expect(cutoffs['W-00001'], DateTime.utc(2026, 10, 30, 2, 1));
      },
    );

    test('read notices still count, so a restart keeps the answer', () {
      final cutoffs = takenOverCutoffs([
        takeover('a', 'W-00001', '2026-10-30T02:00:00Z', read: true),
      ]);
      expect(cutoffs, contains('W-00001'));
    });

    test('the latest takeover of a worker wins', () {
      final cutoffs = takenOverCutoffs([
        takeover('a', 'W-00001', '2026-10-30T02:00:00Z'),
        takeover('b', 'W-00001', '2026-10-30T06:30:00Z'),
        takeover('c', 'W-00001', '2026-10-30T04:00:00Z'),
      ]);
      expect(cutoffs['W-00001'], DateTime.utc(2026, 10, 30, 6, 31));
    });

    test('ignores other types and notices without a worker or a time', () {
      final cutoffs = takenOverCutoffs([
        takeover('a', 'W-00001', '2026-10-30T02:00:00Z', type: 'other'),
        takeover('b', 'W-00002', 'not a time'),
        AppNotification(
          id: 'c',
          type: workerClockedOutType,
          params: const {'time_out': '2026-10-30T02:00:00Z'},
          target: null,
          readAt: null,
          createdAt: DateTime.utc(2026, 10, 30),
        ),
      ]);
      expect(cutoffs, isEmpty);
    });
  });
}
