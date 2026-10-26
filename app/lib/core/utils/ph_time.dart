const _philippineOffset = Duration(hours: 8);

DateTime phDateOf(DateTime utc) {
  final philippines = utc.toUtc().add(_philippineOffset);
  return DateTime.utc(philippines.year, philippines.month, philippines.day);
}

DateTime phWeekStart(DateTime phDate) {
  final date = DateTime.utc(phDate.year, phDate.month, phDate.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
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
