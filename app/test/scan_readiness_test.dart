import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/l10n/app_localizations.dart';
import 'package:fieldwork_attendance/features/scanner/domain/scan_readiness.dart';
import 'package:fieldwork_attendance/features/scanner/presentation/scan_feedback.dart';

void main() {
  group('readinessFromCode', () {
    test('maps every server code from CONTRACT section 13', () {
      expect(
        readinessFromCode('E_DEVICE_PENDING'),
        ScanReadiness.devicePending,
      );
      expect(
        readinessFromCode('E_DEVICE_NOT_APPROVED'),
        ScanReadiness.deviceNotApproved,
      );
      expect(
        readinessFromCode('E_DEVICE_REVOKED'),
        ScanReadiness.deviceRevoked,
      );
      expect(readinessFromCode('E_NO_ACTIVE_FIELD'), ScanReadiness.noField);
      expect(
        readinessFromCode('E_ACCOUNT_DISABLED'),
        ScanReadiness.accountDisabled,
      );
      expect(
        readinessFromCode('E_MUST_CHANGE_PASSWORD'),
        ScanReadiness.mustChangePassword,
      );
    });

    test('treats unknown or missing codes as a connection problem', () {
      expect(readinessFromCode('boom'), ScanReadiness.offline);
      expect(readinessFromCode(null), ScanReadiness.offline);
    });
  });

  group('readinessFromContext', () {
    test('is ready with a profile and a field', () {
      expect(
        readinessFromContext({
          'profile': {'id': 't'},
          'field': {'id': 'f'},
        }),
        ScanReadiness.ready,
      );
    });

    test('reports no field when the technician has no assignment', () {
      expect(
        readinessFromContext({
          'profile': {'id': 't'},
          'field': null,
        }),
        ScanReadiness.noField,
      );
    });

    test('is not ready without a profile', () {
      expect(readinessFromContext({}), ScanReadiness.offline);
    });
  });

  group('feedbackForReadiness', () {
    const english = AppLocalizations(Locale('en'));
    const filipino = AppLocalizations(Locale('fil'));

    test('uses the CONTRACT section 13 messages', () {
      expect(
        feedbackForReadiness(english, ScanReadiness.devicePending).message,
        'This phone is waiting for approval. Ask your admin to approve it.',
      );
      expect(
        feedbackForReadiness(english, ScanReadiness.noField).message,
        'You have no field yet. Ask your admin to assign one.',
      );
    });

    test('every problem has a message in English and Filipino', () {
      for (final readiness in ScanReadiness.values) {
        if (readiness == ScanReadiness.ready) continue;
        expect(
          feedbackForReadiness(english, readiness).message,
          isNotEmpty,
          reason: '$readiness (en)',
        );
        expect(
          feedbackForReadiness(filipino, readiness).message,
          isNotEmpty,
          reason: '$readiness (fil)',
        );
      }
    });

    test('never says "Looking for a QR code" for a problem', () {
      for (final readiness in ScanReadiness.values) {
        expect(
          feedbackForReadiness(english, readiness).message,
          isNot(contains('Looking for')),
        );
      }
    });
  });
}
