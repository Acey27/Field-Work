const _philippineOffset = Duration(hours: 8);

DateTime phDateOf(DateTime utc) {
  final philippines = utc.toUtc().add(_philippineOffset);
  return DateTime.utc(philippines.year, philippines.month, philippines.day);
}

DateTime phWeekStart(DateTime phDate) {
  final date = DateTime.utc(phDate.year, phDate.month, phDate.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

/// `YYYY-MM-DD` for a date-only value (the wire format for dates).
String formatPhDate(DateTime phDate) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${phDate.year.toString().padLeft(4, '0')}-'
      '${two(phDate.month)}-${two(phDate.day)}';
}

/// The UTC instant for [hour]:[minute] Philippine time on [phDate].
DateTime phTimeToUtc(DateTime phDate, int hour, int minute) {
  return DateTime.utc(
    phDate.year,
    phDate.month,
    phDate.day,
    hour,
    minute,
  ).subtract(_philippineOffset);
}

/// Philippine clock time such as `4:52 PM`.
String formatPhTime(DateTime utc) {
  final philippines = utc.toUtc().add(_philippineOffset);
  final hour = philippines.hour % 12 == 0 ? 12 : philippines.hour % 12;
  final minute = philippines.minute.toString().padLeft(2, '0');
  final suffix = philippines.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

String formatMinutes(int minutes) {
  if (minutes == 0) return '0 minutes';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  final parts = <String>[];
  if (hours > 0) {
    parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  }
  if (remainingMinutes > 0) {
    parts.add(
      '$remainingMinutes '
      '${remainingMinutes == 1 ? 'minute' : 'minutes'}',
    );
  }
  return parts.join(' ');
}
