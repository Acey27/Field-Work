import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [LanguageToggle(onChanged: onLocaleChanged)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.dashboard,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(l10n.placeholder),
            const SizedBox(height: 32),
            Text(
              l10n.settings,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
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
