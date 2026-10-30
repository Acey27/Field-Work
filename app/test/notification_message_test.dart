import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/l10n/app_localizations.dart';
import 'package:fieldwork_attendance/features/notifications/domain/notification_message.dart';

void main() {
  const english = AppLocalizations(Locale('en'));
  const filipino = AppLocalizations(Locale('fil'));

  final twoTechnicians = <String, dynamic>{
    'work_date': '2026-10-29',
    'reminder_number': 1,
    'technicians': [
      {
        'id': 'a',
        'code': 'T-00003',
        'name': 'Mark Cruz',
        'field_name': 'Field 3',
      },
      {
        'id': 'b',
        'code': 'T-00001',
        'name': 'Ana Reyes',
        'field_name': 'Field 1',
      },
    ],
  };

  group('notificationText', () {
    test('matches the SPEC section 8 example for several technicians', () {
      expect(
        notificationText(english, 'field_day_not_ended', twoTechnicians),
        '2 technicians have not ended their field day: '
        'Mark Cruz (Field 3), Ana Reyes (Field 1)',
      );
    });

    test('uses the singular form for one technician', () {
      final params = <String, dynamic>{
        'technicians': [
          {'name': 'Mark Cruz', 'field_name': 'Field 3'},
        ],
      };
      expect(
        notificationText(english, 'field_day_not_ended', params),
        '1 technician has not ended their field day: Mark Cruz (Field 3)',
      );
    });

    test('follows the language toggle', () {
      expect(
        notificationText(filipino, 'field_day_not_ended', twoTechnicians),
        contains('Mark Cruz (Field 3), Ana Reyes (Field 1)'),
      );
      expect(
        notificationText(filipino, 'field_day_not_ended', twoTechnicians),
        isNot(contains('have not ended')),
      );
    });

    test('falls back for an empty list or an unknown type', () {
      expect(
        notificationText(english, 'field_day_not_ended', {
          'technicians': <Map<String, dynamic>>[],
        }),
        english.notifGeneric,
      );
      expect(
        notificationText(english, 'something_new', {}),
        english.notifGeneric,
      );
    });

    test('device approval has its own message', () {
      expect(
        notificationText(english, 'device_approval_needed', {}),
        english.notifDeviceApproval,
      );
    });

    group('worker clocked out by another technician', () {
      final params = <String, dynamic>{
        'worker_id': 'W-00002',
        'worker_name': 'Test worker two',
        'reason': 'safety_net',
        'session_id': 's-1',
      };

      test('names the worker and the reason', () {
        expect(
          notificationText(english, 'worker_clocked_out', params),
          'Worker clocked out: Test worker two (scanned by another technician)',
        );
      });

      test('follows the language toggle', () {
        final text = notificationText(filipino, 'worker_clocked_out', params);
        expect(text, contains('Test worker two'));
        expect(text, contains('na-scan ng ibang technician'));
        expect(text, isNot(contains('Worker clocked out')));
      });

      test('falls back to the worker ID, and to a plain reason', () {
        expect(
          notificationText(english, 'worker_clocked_out', {
            'worker_id': 'W-00002',
            'reason': 'something_else',
          }),
          'Worker clocked out: W-00002 (closed by the system)',
        );
      });
    });
  });

  group('notificationRoute', () {
    test('opens Today\'s field days for a not-ended reminder', () {
      expect(
        notificationRoute('today_field_days', 'field_day_not_ended'),
        '/admin',
      );
    });

    test('opens technicians for a device approval', () {
      expect(
        notificationRoute('devices', 'device_approval_needed'),
        '/admin/technicians',
      );
    });

    test('has no route for other notices', () {
      expect(notificationRoute(null, 'audit_deletion_notice'), isNull);
    });
  });
}
