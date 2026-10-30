import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/l10n/app_localizations.dart';

void main() {
  const english = AppLocalizations(Locale('en'));
  const filipino = AppLocalizations(Locale('fil'));

  const results = [
    'blocked_held_elsewhere',
    'blocked_bad_qr',
    'blocked_unknown_worker',
    'blocked_inactive_worker',
    'blocked_inactive_field',
    'blocked_inactive_technician',
    'blocked_not_assigned',
  ];

  test('a worker held by another technician says who can clock them out', () {
    expect(
      english.scanRefused('Juan dela Cruz', 'blocked_held_elsewhere'),
      'Juan dela Cruz: not saved. Another technician has this worker clocked '
      'in. Only that technician can clock them out.',
    );
  });

  test('every refused result has its own text in both languages', () {
    final seen = <String>{};
    for (final result in results) {
      final en = english.scanRefused('Juan', result);
      final fil = filipino.scanRefused('Juan', result);
      expect(en, contains('Juan'), reason: result);
      expect(fil, contains('Juan'), reason: result);
      expect(en, isNot(equals(fil)), reason: result);
      expect(
        en,
        isNot(contains(english.scanRefused('Juan', 'something_new'))),
        reason: result,
      );
      expect(seen.add(en), isTrue, reason: '$result has a text of its own');
    }
  });

  test('an unknown result falls back to a plain message', () {
    expect(
      english.scanRefused('Juan', 'something_new'),
      'Juan: not saved. The scan was not saved. Tell your admin.',
    );
  });
}
