import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/language_toggle.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final role = ref.watch<AppRole>(selectedRoleProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.login,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      hintText: l10n.usernameHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      hintText: l10n.passwordHint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.chooseRole),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AppRole>(
                    initialValue: role,
                    items: AppRole.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(roleLabel(context, item)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedRoleProvider.notifier).setRole(value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go(switch (role) {
                      AppRole.technician => '/technician',
                      AppRole.admin => '/admin',
                      AppRole.superAdmin => '/super-admin',
                    }),
                    child: Text(l10n.signIn),
                  ),
                  const SizedBox(height: 24),
                  LanguageToggle(onChanged: onLocaleChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
