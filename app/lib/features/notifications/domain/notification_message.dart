import '../../../core/l10n/app_localizations.dart';

/// The text of a notification. The database stores data only (`type` and
/// `params`), never translated text (CONTRACT.md section 2.12), so the
/// sentence is built here in the current language.
String notificationText(
  AppLocalizations l10n,
  String type,
  Map<String, dynamic> params,
) {
  switch (type) {
    case 'field_day_not_ended':
      final technicians = (params['technicians'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (technicians.isEmpty) return l10n.notifGeneric;
      final names = technicians
          .map((t) => '${t['name'] ?? ''} (${t['field_name'] ?? ''})')
          .join(', ');
      return technicians.length == 1
          ? l10n.notifFieldDayNotEndedOne(names)
          : l10n.notifFieldDayNotEnded(technicians.length, names);
    case 'device_approval_needed':
      return l10n.notifDeviceApproval;
    default:
      return l10n.notifGeneric;
  }
}

/// The admin route a notification opens when tapped, or null for none.
String? notificationRoute(String? target, String type) {
  switch (target ?? type) {
    case 'today_field_days':
    case 'field_day_not_ended':
      return '/admin';
    case 'devices':
    case 'device_approval_needed':
      return '/admin/technicians';
    default:
      return null;
  }
}
