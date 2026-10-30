import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';

class MasterlistRow {
  const MasterlistRow({
    required this.technicianId,
    required this.technicianCode,
    required this.technicianName,
    required this.fieldId,
    required this.fieldName,
    required this.fieldLocation,
    required this.fieldAddress,
    required this.workerId,
    required this.workerName,
    required this.minutes,
    required this.totalMinutes,
    required this.presentDays,
  });

  factory MasterlistRow.fromJson(Map<String, dynamic> json) {
    int? minute(String key) => (json[key] as num?)?.toInt();
    return MasterlistRow(
      technicianId: json['technician_id'] as String,
      technicianCode: json['technician_code'] as String,
      technicianName: json['technician_name'] as String,
      fieldId: json['field_id'] as String,
      fieldName: json['field_name'] as String,
      fieldLocation: json['field_location'] as String?,
      fieldAddress: json['field_address'] as String?,
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String,
      minutes: [
        minute('mon_minutes'),
        minute('tue_minutes'),
        minute('wed_minutes'),
        minute('thu_minutes'),
        minute('fri_minutes'),
        minute('sat_minutes'),
        minute('sun_minutes'),
      ],
      totalMinutes: (json['total_minutes'] as num).toInt(),
      presentDays: (json['present_days'] as num).toInt(),
    );
  }

  final String technicianId;
  final String technicianCode;
  final String technicianName;
  final String fieldId;
  final String fieldName;
  final String? fieldLocation;
  final String? fieldAddress;
  final String workerId;
  final String workerName;
  final List<int?> minutes;
  final int totalMinutes;
  final int presentDays;

  String get fieldLabel => [
    fieldName,
    if (fieldLocation?.trim().isNotEmpty == true) fieldLocation!,
  ].join(' - ');
}

class UnendedFieldDay {
  const UnendedFieldDay({
    required this.date,
    required this.technicianCode,
    required this.technicianName,
    required this.fieldName,
    required this.clockedInCount,
  });

  factory UnendedFieldDay.fromJson(Map<String, dynamic> json) {
    return UnendedFieldDay(
      date: DateTime.parse(json['work_date'] as String),
      technicianCode: json['technician_code'] as String,
      technicianName: json['technician_name'] as String,
      fieldName: json['field_name'] as String,
      clockedInCount: (json['clocked_in_count'] as num).toInt(),
    );
  }

  final DateTime date;
  final String technicianCode;
  final String technicianName;
  final String fieldName;
  final int clockedInCount;
}

class MasterlistService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<MasterlistRow>> load(DateTime weekStart) async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>(
      'weekly_masterlist',
      params: {'p_week_start': formatPhDate(weekStart)},
    );
    return value
        .whereType<Map<String, dynamic>>()
        .map(MasterlistRow.fromJson)
        .toList();
  }

  Future<List<UnendedFieldDay>> loadUnended(DateTime weekStart) async {
    _requireConfigured();
    final value = await _client.rpc<List<dynamic>>(
      'get_unended_field_days',
      params: {'p_week_start': formatPhDate(weekStart)},
    );
    return value
        .whereType<Map<String, dynamic>>()
        .map(UnendedFieldDay.fromJson)
        .toList();
  }

  Future<void> recordExport({
    required DateTime weekStart,
    required String fileName,
    required int rowCount,
  }) async {
    _requireConfigured();
    await _client.rpc<Map<String, dynamic>>(
      'record_weekly_export',
      params: {
        'p_week_start': formatPhDate(weekStart),
        'p_file_name': fileName,
        'p_row_count': rowCount,
      },
    );
  }

  Future<bool> hasChangedAfterExport(DateTime weekStart) async {
    _requireConfigured();
    final row = await _client
        .from('weekly_exports')
        .select('changed_after_export')
        .eq('week_start', formatPhDate(weekStart))
        .order('exported_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['changed_after_export'] == true;
  }

  Future<Uint8List> buildExcel({
    required List<MasterlistRow> rows,
    required String weekLabel,
    required String notEndedLabel,
    required List<String> headers,
  }) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Masterlist'];
    sheet.appendRow([TextCellValue(weekLabel)]);
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.workerId),
        TextCellValue(row.workerName),
        ...row.minutes.map(
          (minutes) => TextCellValue(
            minutes == null
                ? ''
                : minutes == 0
                ? notEndedLabel
                : formatMinutes(minutes),
          ),
        ),
        TextCellValue(formatMinutes(row.totalMinutes)),
        IntCellValue(row.presentDays),
        TextCellValue(''),
      ]);
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('The Excel file could not be created.');
    return Uint8List.fromList(bytes);
  }

  Future<Uri?> saveExcel(Uint8List bytes, String fileName) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  void _requireConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthException('E_SERVER_CONFIG');
    }
  }
}
