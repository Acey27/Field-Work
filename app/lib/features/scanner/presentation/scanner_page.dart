import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scan),
        actions: [LanguageToggle(onChanged: onLocaleChanged)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  l10n.placeholder,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Text(l10n.workersStillClockedIn(0)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () {}, child: Text(l10n.endFieldDay)),
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
