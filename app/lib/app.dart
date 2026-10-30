import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({required this.initialLocale, super.key});

  final Locale initialLocale;

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late Locale _locale = widget.initialLocale;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(_setLocale);
    if (SupabaseConfig.isConfigured) {
      // Whatever ended the session (log out, a renewal that failed, a phone
      // turned off by the admin), every screen goes back to the login page.
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((state) {
            if (state.event == AuthChangeEvent.signedOut) {
              _router.go('/login');
            }
          });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
