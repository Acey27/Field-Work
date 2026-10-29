/// The phone never starts a sync more often than this (CONTRACT.md section 8,
/// item 2).
const minSyncInterval = Duration(seconds: 30);

/// How long to wait before the next try after [failures] failed syncs in a
/// row: 30 seconds, 1 minute, 2 minutes, then every 5 minutes (CONTRACT.md
/// section 8, item 5). Repeating is safe because every scan has its own ID.
Duration retryDelay(int failures) {
  if (failures <= 1) return const Duration(seconds: 30);
  if (failures == 2) return const Duration(minutes: 1);
  if (failures == 3) return const Duration(minutes: 2);
  return const Duration(minutes: 5);
}

/// Errors that stop the whole sync loop and are shown to the technician
/// instead of being retried (CONTRACT.md section 8, item 6).
bool isBatchLevelError(String? code) => const {
  'E_DEVICE_PENDING',
  'E_DEVICE_NOT_APPROVED',
  'E_DEVICE_REVOKED',
  'E_ACCOUNT_DISABLED',
}.contains(code);

/// Remembers when the last sync started so automatic syncs can be spaced out.
class SyncThrottle {
  DateTime? _lastStart;

  /// Time left before another sync may start. Zero means go ahead.
  Duration remaining(DateTime now) {
    final last = _lastStart;
    if (last == null) return Duration.zero;
    final left = minSyncInterval - now.difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  void markStarted(DateTime now) => _lastStart = now;
}
