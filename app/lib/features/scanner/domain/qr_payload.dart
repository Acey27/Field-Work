class QrPayload {
  const QrPayload({required this.workerId, required this.qrCheck});

  final String workerId;
  final String qrCheck;

  static final _pattern = RegExp(r'^W-\d{5}\.[0-9a-z]{3}$');

  static QrPayload? parse(String? raw) {
    final value = raw?.trim();
    if (value == null || !_pattern.hasMatch(value)) return null;
    final separator = value.lastIndexOf('.');
    return QrPayload(
      workerId: value.substring(0, separator),
      qrCheck: value.substring(separator + 1),
    );
  }

  String get value => '$workerId.$qrCheck';
}
