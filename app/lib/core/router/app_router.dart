import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/first_login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/scanner/presentation/scanner_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../l10n/app_localizations.dart';

final selectedRoleProvider = NotifierProvider<RoleNotifier, AppRole>(
  RoleNotifier.new,
);

enum AppRole { technician, admin, superAdmin }

class RoleNotifier extends Notifier<AppRole> {
  @override
  AppRole build() => AppRole.technician;

  void setRole(AppRole role) => state = role;
}

GoRouter buildRouter(ValueChanged<Locale> onLocaleChanged) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginPage(onLocaleChanged: onLocaleChanged),
      ),
      GoRoute(
        path: '/first-login',
        builder: (context, state) => FirstLoginPage(
          onLocaleChanged: onLocaleChanged,
          role: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/technician',
        builder: (context, state) =>
            ScannerPage(onLocaleChanged: onLocaleChanged),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            DashboardPage(onLocaleChanged: onLocaleChanged),
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) =>
            SettingsPage(onLocaleChanged: onLocaleChanged),
      ),
    ],
  );
}

String roleLabel(BuildContext context, AppRole role) {
  final l10n = AppLocalizations.of(context);
  return switch (role) {
    AppRole.technician => l10n.technician,
    AppRole.admin => l10n.admin,
    AppRole.superAdmin => l10n.superAdmin,
  };
}
