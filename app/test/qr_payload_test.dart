import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/features/scanner/domain/qr_payload.dart';

void main() {
  test('parses a valid worker QR payload', () {
    final payload = QrPayload.parse('W-00001.abc');

    expect(payload?.workerId, 'W-00001');
    expect(payload?.qrCheck, 'abc');
  });

  test('rejects malformed or non-lowercase checksum payloads', () {
    expect(QrPayload.parse('W-0001.abc'), isNull);
    expect(QrPayload.parse('W-00001.ABC'), isNull);
    expect(QrPayload.parse('W-00001.abcd'), isNull);
    expect(QrPayload.parse('W-00001abc'), isNull);
  });
}
