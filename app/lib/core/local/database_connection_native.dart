import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openDatabaseConnection() async {
  final directory = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File('${directory.path}/attendance.sqlite'),
  );
}
