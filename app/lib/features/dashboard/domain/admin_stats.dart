// Data classes for the admin statistics and the flagged list
// (CONTRACT.md section 4.12, SPEC.md section 11).

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

class TodayStats {
  const TodayStats({
    required this.clockedInNow,
    required this.finished,
    required this.techniciansWorking,
    required this.fieldsWorking,
    required this.fieldDaysNotEnded,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
    clockedInNow: _int(json['clocked_in_now']),
    finished: _int(json['finished']),
    techniciansWorking: _int(json['technicians_working']),
    fieldsWorking: _int(json['fields_working']),
    fieldDaysNotEnded: _int(json['field_days_not_ended']),
  );

  final int clockedInNow;
  final int finished;
  final int techniciansWorking;
  final int fieldsWorking;
  final int fieldDaysNotEnded;
}

class DayStat {
  const DayStat({
    required this.date,
    required this.workersPresent,
    required this.totalMinutes,
  });

  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
    date: DateTime.parse('${json['date']}T00:00:00Z'),
    workersPresent: _int(json['workers_present']),
    totalMinutes: _int(json['total_minutes']),
  );

  final DateTime date;
  final int workersPresent;
  final int totalMinutes;
}

class FieldStat {
  const FieldStat({
    required this.fieldName,
    required this.presentDays,
    required this.totalMinutes,
  });

  factory FieldStat.fromJson(Map<String, dynamic> json) => FieldStat(
    fieldName: json['field_name'] as String? ?? '',
    presentDays: _int(json['present_days']),
    totalMinutes: _int(json['total_minutes']),
  );

  final String fieldName;
  final int presentDays;
  final int totalMinutes;
}

class WeekStats {
  const WeekStats({
    required this.days,
    required this.byField,
    required this.workersPresent,
    required this.totalMinutes,
    required this.previousWorkersPresent,
    required this.previousTotalMinutes,
  });

  factory WeekStats.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final previous = json['previous'] as Map<String, dynamic>? ?? const {};
    return WeekStats(
      days: (json['days'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DayStat.fromJson)
          .toList(),
      byField: (json['attendance_by_field'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FieldStat.fromJson)
          .toList(),
      workersPresent: _int(totals['workers_present']),
      totalMinutes: _int(totals['total_minutes']),
      previousWorkersPresent: _int(previous['workers_present']),
      previousTotalMinutes: _int(previous['total_minutes']),
    );
  }

  final List<DayStat> days;
  final List<FieldStat> byField;

  /// Workers present, added up over the days of the week.
  final int workersPresent;
  final int totalMinutes;
  final int previousWorkersPresent;
  final int previousTotalMinutes;
}

class FlaggedItem {
  const FlaggedItem({
    required this.kind,
    required this.worker,
    required this.technician,
    required this.technicianCode,
    required this.fieldName,
    required this.at,
  });

  factory FlaggedItem.fromJson(Map<String, dynamic> json) {
    final detail = json['detail'] as Map<String, dynamic>? ?? const {};
    return FlaggedItem(
      kind: json['kind'] as String? ?? '',
      worker: json['worker'] as String? ?? '',
      technician: json['technician'] as String? ?? '',
      technicianCode: json['technician_code'] as String? ?? '',
      fieldName: detail['field_name'] as String? ?? '',
      at: DateTime.parse(json['at'] as String).toUtc(),
    );
  }

  final String kind;
  final String worker;
  final String technician;
  final String technicianCode;
  final String fieldName;
  final DateTime at;
}
