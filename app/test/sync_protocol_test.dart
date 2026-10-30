import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/scanner/data/sync_service.dart';

void main() {
  test('splits uploads into batches of no more than 50', () {
    final batches = splitIntoBatches(List.generate(121, (index) => index));

    expect(batches.map((batch) => batch.length), [50, 50, 21]);
    expect(batches.expand((batch) => batch), List.generate(121, (i) => i));
  });

  test('maps every server result category to a retained upload state', () {
    for (final result in [
      'clocked_in',
      'clocked_out',
      'ignored_repeat',
      'blocked_unknown_worker',
      'blocked_bad_qr',
      'blocked_inactive_worker',
      'blocked_inactive_field',
      'blocked_inactive_technician',
      'blocked_not_assigned',
      'blocked_held_elsewhere',
    ]) {
      expect(
        scanUploadState(result),
        result.startsWith('blocked_') ? 'rejected' : 'uploaded',
      );
    }
  });
}
