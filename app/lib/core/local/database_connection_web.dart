import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

Future<QueryExecutor> openDatabaseConnection() async {
  return WebDatabase('attendance');
}
