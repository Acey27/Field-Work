import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final preferences = await SharedPreferences.getInstance();
  final language = preferences.getString('language') ?? 'en';
  runApp(ProviderScope(child: AttendanceApp(initialLocale: Locale(language))));
}
