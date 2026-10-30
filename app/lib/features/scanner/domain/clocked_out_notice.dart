import '../../../core/utils/moments.dart';
import '../../notifications/data/notification_service.dart';
import 'scan_decision.dart';

/// The notification the database writes when another technician's scan clocks
/// out a worker who was clocked in on this technician's phone (migration 018).
const workerClockedOutType = 'worker_clocked_out';

/// The notices the scanner still has to show: unread, of that type, and not
/// already dismissed on this phone ([dismissed] covers the moment when marking
/// them read failed because the phone was offline).
List<AppNotification> unreadClockedOutNotices(
  Iterable<AppNotification> all, {
  Set<String> dismissed = const {},
}) => [
  for (final notice in all)
    if (notice.type == workerClockedOutType &&
        !notice.isRead &&
        !dismissed.contains(notice.id))
      notice,
];

/// Workers another technician took over, from every clock-out notice (read or
/// not, so the answer is the same after the phone restarts). The value is the
/// moment up to which this phone's own scans of the worker no longer count
/// (`takeoverCutoff`): until the new holder clocks the worker out, this
/// technician's next scan is a clock in again, never a clock out (migration 019).
Map<String, DateTime> takenOverCutoffs(Iterable<AppNotification> all) {
  final cutoffs = <String, DateTime>{};
  for (final notice in all) {
    if (notice.type != workerClockedOutType) continue;
    final workerId = notice.params['worker_id'];
    final timeOut = DateTime.tryParse('${notice.params['time_out'] ?? ''}');
    if (workerId is! String || timeOut == null) continue;
    cutoffs[workerId] = laterOf(cutoffs[workerId], takeoverCutoff(timeOut))!;
  }
  return cutoffs;
}
