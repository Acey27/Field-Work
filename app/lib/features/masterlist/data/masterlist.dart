import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/ph_time.dart';

/// The name of the one sheet in the exported file.
const masterlistSheetName = 'Masterlist';

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

/// One technician's block of the masterlist: the workers that technician had
/// time records for in one field during the week (SPEC.md section 12).
class MasterlistSection {
  const MasterlistSection({
    required this.technicianId,
    required this.technicianCode,
    required this.technicianName,
    required this.fieldName,
    required this.fieldLocation,
    required this.fieldAddress,
    required this.rows,
  });

  final String technicianId;
  final String technicianCode;
  final String technicianName;
  final String fieldName;
  final String? fieldLocation;
  final String? fieldAddress;
  final List<MasterlistRow> rows;

  /// "Field 1 - North", or just the field name without a location.
  String get fieldLabel => rows.first.fieldLabel;

  /// "T-00001 John Doe". The field and its address are not printed.
  String get heading => '$technicianCode $technicianName';
}

/// Splits the rows into one section per technician and field, keeping the order
/// the database returned them in (technician code, field, worker).
List<MasterlistSection> groupMasterlist(List<MasterlistRow> rows) {
  final grouped = <String, List<MasterlistRow>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent('${row.technicianId}|${row.fieldId}', () => [])
        .add(row);
  }
  return [
    for (final group in grouped.values)
      MasterlistSection(
        technicianId: group.first.technicianId,
        technicianCode: group.first.technicianCode,
        technicianName: group.first.technicianName,
        fieldName: group.first.fieldName,
        fieldLocation: group.first.fieldLocation,
        fieldAddress: group.first.fieldAddress,
        rows: group,
      ),
  ];
}

/// The text of one day cell: blank when the worker was not there, the "not
/// ended" label for a session that was never closed, otherwise hours and
/// minutes.
String masterlistDayText(int? minutes, String notEndedLabel) {
  if (minutes == null) return '';
  if (minutes == 0) return notEndedLabel;
  return formatMinutes(minutes);
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

  /// The accountant's file (SPEC.md section 12): one sheet, and per technician
  /// a block with the technician's line (ID, name, date), the column headers
  /// and one row per worker, drawn as a table with borders. [headers] and
  /// [notEndedLabel] come from the English strings, whatever language the app
  /// is in. There is no Pay column and the Signature column is left empty.
  /// Column widths follow the longest text in each column.
  Future<Uint8List> buildExcel({
    required List<MasterlistRow> rows,
    required String weekLabel,
    required String notEndedLabel,
    required List<String> headers,
  }) async {
    final workbook = Excel.createExcel();
    // A new workbook already has an empty sheet (Sheet1), which is the one
    // Excel opens. Use that one, so the data is on the first tab.
    final first = workbook.getDefaultSheet() ?? 'Sheet1';
    workbook[first];
    workbook.rename(first, masterlistSheetName);
    workbook.setDefaultSheet(masterlistSheetName);
    final sheet = workbook[masterlistSheetName];

    final line = Border(borderStyle: BorderStyle.Thin);
    CellStyle boxed({bool bold = false, bool header = false}) => CellStyle(
      bold: bold,
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Center,
      horizontalAlign: header ? HorizontalAlign.Center : HorizontalAlign.Left,
      backgroundColorHex: header
          ? ExcelColor.fromHexString('#D9D9D9')
          : ExcelColor.none,
      leftBorder: line,
      rightBorder: line,
      topBorder: line,
      bottomBorder: line,
    );

    // Longest text of each table column, in characters (headers count by
    // their longest word, since they wrap).
    final columns = headers.length;
    final longest = List<int>.filled(columns, 0);
    void measure(int column, String text, {bool words = false}) {
      if (column >= columns) return;
      final length = words
          ? text.split(' ').fold<int>(0, (m, w) => w.length > m ? w.length : m)
          : text.length;
      if (length > longest[column]) longest[column] = length;
    }

    for (var column = 0; column < columns; column++) {
      measure(column, headers[column], words: true);
    }

    var rowIndex = 0;
    void put(int column, CellValue value, CellStyle? style) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
        value,
        cellStyle: style,
      );
    }

    final info = CellStyle(bold: true);
    for (final section in groupMasterlist(rows)) {
      // ID, then the name and the date, each over a few columns so a long
      // name never has to squeeze into the narrow ID column.
      put(0, TextCellValue('ID: ${section.technicianCode}'), info);
      put(
        1,
        TextCellValue('Name of Technician: ${section.technicianName}'),
        info,
      );
      put(5, TextCellValue('Date: $weekLabel'), info);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
      );
      rowIndex++;

      for (var column = 0; column < columns; column++) {
        put(
          column,
          TextCellValue(headers[column]),
          boxed(bold: true, header: true),
        );
      }
      sheet.setRowHeight(rowIndex, 32);
      rowIndex++;

      for (final row in section.rows) {
        final cells = <String>[
          row.workerId,
          row.workerName,
          for (final minutes in row.minutes)
            masterlistDayText(minutes, notEndedLabel),
          formatMinutes(row.totalMinutes),
          '${row.presentDays}',
          '', // Signature
        ];
        for (
          var column = 0;
          column < columns && column < cells.length;
          column++
        ) {
          measure(column, cells[column]);
          // The present count is a number; everything else is text. Empty
          // cells are written too, so they get their borders.
          put(
            column,
            column == columns - 2
                ? IntCellValue(row.presentDays)
                : TextCellValue(cells[column]),
            boxed(),
          );
        }
        // Room to sign.
        sheet.setRowHeight(rowIndex, 26);
        rowIndex++;
      }
      rowIndex++; // a blank row between technicians
    }

    // Each column as wide as its longest text (a little extra for the
    // padding and bold), never narrower than the Signature box needs.
    for (var column = 0; column < columns; column++) {
      final minimum = column == columns - 1 ? 24.0 : 8.0;
      final fitted = longest[column] * 1.2 + 3;
      sheet.setColumnWidth(column, fitted < minimum ? minimum : fitted);
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
