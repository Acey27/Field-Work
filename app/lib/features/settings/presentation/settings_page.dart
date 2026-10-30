import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../auth/data/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.length < 2 || !email.contains('@') || password.length < 10) {
      setState(() {
        _error = l10n.errAdminInput;
        _message = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create_admin_account',
        body: {
          'email': email,
          'full_name': name,
          'starting_password': password,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final code = data is Map ? data['error'] : null;
        throw AuthException(code is String ? code : 'E_ACCOUNT_CREATE_FAILED');
      }
      final data = response.data as Map;
      if (!mounted) return;
      setState(() {
        _message = l10n.adminCreated(data['code'] as String? ?? '');
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = l10n.authError(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.authError('E_FORBIDDEN'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [LanguageToggle(onChanged: widget.onLocaleChanged)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.adminAccounts,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(l10n.adminAccountDescription),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.fullName),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.email),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.startingPassword,
                    helperText: l10n.startingPasswordHint,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_message != null)
                  Text(
                    _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _createAdmin,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(l10n.createAdmin),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(l10n.logOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
