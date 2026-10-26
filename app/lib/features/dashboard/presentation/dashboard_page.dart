import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [LanguageToggle(onChanged: onLocaleChanged)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.placeholder,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.login),
            ),
          ],
        ),
      ),
    );
  }
}
