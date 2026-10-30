/// How long a repeat scan of the same card is ignored on the phone.
/// Same value as the server rule in CONTRACT.md section 4.6, step 5.
const repeatScanWindow = Duration(seconds: 30);

enum LocalDirection { clockIn, clockOut }

/// Scans of a worker up to this moment no longer count for clock in or out,
/// because another technician took the worker over at [takenOverAt]
/// (CONTRACT.md section 4.6, rule 6). The server stores that moment to the
/// minute, which can be up to a minute before this phone's own last scan, so
/// scans in that minute count as before the takeover.
DateTime takeoverCutoff(DateTime takenOverAt) =>
    takenOverAt.toUtc().add(const Duration(minutes: 1));

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

/// [todaysScans] are the accepted scan times (UTC) of this worker since the
/// last End field day, in any order. An even count means the next scan is a
/// clock in, an odd count means a clock out.
///
/// [recentScans] are all of the worker's scans today, used only for the
/// 30-second repeat rule. It defaults to [todaysScans].
ScanDecision decideScan({
  required List<DateTime> todaysScans,
  required DateTime now,
  List<DateTime>? recentScans,
}) {
  final recent = recentScans ?? todaysScans;
  if (recent.isNotEmpty) {
    final last = recent.reduce((a, b) => a.isAfter(b) ? a : b);
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
