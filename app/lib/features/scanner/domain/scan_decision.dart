/// How long a repeat scan of the same card is ignored on the phone.
/// Same value as the server rule in CONTRACT.md section 4.6, step 5.
const repeatScanWindow = Duration(seconds: 30);

enum LocalDirection { clockIn, clockOut }

/// What a scan means, from the phone's own scans of the worker today.
///
/// The server decides for real (CONTRACT.md section 6); this only drives the
/// on-screen confirmation.
class ScanDecision {
  const ScanDecision.repeat() : isRepeat = true, direction = null;
  const ScanDecision.accepted(LocalDirection this.direction) : isRepeat = false;

  final bool isRepeat;
  final LocalDirection? direction;
}

/// [todaysScans] are the accepted scan times (UTC) of this worker on the
/// current Philippine date, in any order. An even count means the next scan
/// is a clock in, an odd count means a clock out.
ScanDecision decideScan({
  required List<DateTime> todaysScans,
  required DateTime now,
}) {
  if (todaysScans.isNotEmpty) {
    final last = todaysScans.reduce((a, b) => a.isAfter(b) ? a : b);
    if (now.difference(last) < repeatScanWindow) {
      return const ScanDecision.repeat();
    }
  }
  return ScanDecision.accepted(
    todaysScans.length.isEven
        ? LocalDirection.clockIn
        : LocalDirection.clockOut,
  );
}
