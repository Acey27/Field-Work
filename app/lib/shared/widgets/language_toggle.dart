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
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'en', label: Text(l10n.english)),
        ButtonSegment(value: 'fil', label: Text(l10n.filipino)),
      ],
      selected: {current},
      onSelectionChanged: (selection) {
        final language = selection.first;
        _select(context, Locale(language));
      },
    );
  }
}
