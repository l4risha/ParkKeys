import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(
        _email.text.trim(),
        _password.text,
      );
      // GoRouter redirect mo-handle sa role-based home.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _email.text = email;
      _password.text = password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 480,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.electric_rickshaw,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'ParkKeys',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Barangay tricycle queue • Cabadbaran City',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Log in',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'Email is required';
                              if (!text.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? 'Hide' : 'Show',
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (value) => (value == null || value.isEmpty)
                                ? 'Password is required'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            ErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Log in'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.go('/register'),
                            child: const Text('New passenger? Create account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: const Icon(Icons.key),
                    title: const Text('Demo accounts'),
                    subtitle: const Text('Tap one to autofill'),
                    children: [
                      _DemoTile(
                        label: 'Admin',
                        email: 'admin@parkkeys.com',
                        password: 'Admin123!',
                        onTap: _fillDemo,
                      ),
                      _DemoTile(
                        label: 'Driver',
                        email: 'driver1@parkkeys.com',
                        password: 'Driver123!',
                        onTap: _fillDemo,
                      ),
                      _DemoTile(
                        label: 'Passenger',
                        email: 'passenger1@parkkeys.com',
                        password: 'Passenger123!',
                        onTap: _fillDemo,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/public'),
                  icon: const Icon(Icons.public),
                  label: const Text('View public queue board (no login)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.label,
    required this.email,
    required this.password,
    required this.onTap,
  });

  final String label;
  final String email;
  final String password;
  final void Function(String email, String password) onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline),
      title: Text(label),
      subtitle: Text(email),
      trailing: const Icon(Icons.touch_app, size: 18),
      onTap: () => onTap(email, password),
    );
  }
}
