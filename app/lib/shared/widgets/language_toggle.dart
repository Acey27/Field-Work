import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_localizations.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({required this.onChanged, super.key});

  final ValueChanged<Locale> onChanged;

  Future<void> _select(BuildContext context, Locale locale) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('language', locale.languageCode);
    onChanged(locale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    // On a phone the full names are wider than the rest of the app bar, which
    // overflowed the bar on a 320 px screen.
    final compact = MediaQuery.sizeOf(context).width < 480;
    return SegmentedButton<String>(
      showSelectedIcon: !compact,
      style: compact
          ? const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          : null,
      segments: [
        ButtonSegment(
          value: 'en',
          label: Text(compact ? 'EN' : l10n.english),
          tooltip: l10n.english,
        ),
        ButtonSegment(
          value: 'fil',
          label: Text(compact ? 'FIL' : l10n.filipino),
          tooltip: l10n.filipino,
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) {
        final language = selection.first;
        _select(context, Locale(language));
      },
    );
  }
}
