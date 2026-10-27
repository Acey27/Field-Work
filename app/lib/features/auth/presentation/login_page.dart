import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../data/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn(AppRole fallbackRole) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final role = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      context.go(switch (role) {
        'technician' => '/technician',
        'admin' => '/admin',
        'super_admin' => '/super-admin',
        _ => switch (fallbackRole) {
          AppRole.technician => '/technician',
          AppRole.admin => '/admin',
          AppRole.superAdmin => '/super-admin',
        },
      });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = l10n.authError(error.message));
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.authError('E_FORBIDDEN'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      hintText: l10n.emailHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
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
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _busy ? null : () => _signIn(role),
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(l10n.signIn),
                  ),
                  const SizedBox(height: 24),
                  LanguageToggle(onChanged: widget.onLocaleChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
