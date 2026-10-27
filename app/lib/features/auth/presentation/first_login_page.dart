import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../data/auth_service.dart';

class FirstLoginPage extends StatefulWidget {
  const FirstLoginPage({
    required this.onLocaleChanged,
    required this.role,
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final String role;

  @override
  State<FirstLoginPage> createState() => _FirstLoginPageState();
}

class _FirstLoginPageState extends State<FirstLoginPage> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    if (password.length < 10 || password != _confirmationController.text) {
      setState(() => _error = l10n.errPasswordChangeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService().completeFirstLogin(password);
      if (!mounted) return;
      context.go(switch (widget.role) {
        'technician' => '/technician',
        'admin' => '/admin',
        'super_admin' => '/super-admin',
        _ => '/login',
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
                    l10n.firstLoginTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.firstLoginDescription),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.newPassword),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmationController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(l10n.savePassword),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
