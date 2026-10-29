import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_state.dart';
import '../theme.dart';
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
    return Scaffold(
      backgroundColor: ParkKeysColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel(expanded: true)),
                Expanded(
                  flex: 6,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildForm(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const _BrandPanel(expanded: false),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _buildForm(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Log in', style: ParkKeysText.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Gamita ang imong ParkKeys account.',
                    style: ParkKeysText.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/register'),
                    child: const Text('New passenger? Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: [
                ListTile(
                  leading: const BrandIconWell(
                    icon: Icons.key,
                    background: ParkKeysColors.yellowSoft,
                    foreground: ParkKeysColors.ink,
                  ),
                  title: const Text('Demo accounts'),
                  subtitle: const Text('Tap one to autofill'),
                ),
                _DemoTile(
                  label: 'Admin',
                  email: 'admin@parkkeys.com',
                  password: 'Admin123!',
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: _fillDemo,
                ),
                _DemoTile(
                  label: 'Driver',
                  email: 'driver1@parkkeys.com',
                  password: 'Driver123!',
                  icon: Icons.electric_rickshaw,
                  onTap: _fillDemo,
                ),
                _DemoTile(
                  label: 'Passenger',
                  email: 'passenger1@parkkeys.com',
                  password: 'Passenger123!',
                  icon: Icons.person_outline,
                  onTap: _fillDemo,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => context.go('/public'),
          icon: const Icon(Icons.public),
          label: const Text('View public queue board (no login)'),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final panel = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 48 : 24,
        vertical: expanded ? 48 : 28,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: expanded ? 88 : 68,
            height: expanded ? 88 : 68,
            decoration: BoxDecoration(
              color: ParkKeysColors.yellow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.electric_rickshaw,
              size: expanded ? 48 : 38,
              color: ParkKeysColors.ink,
            ),
          ),
          SizedBox(height: expanded ? 24 : 14),
          Text(
            'ParkKeys',
            textAlign: expanded ? TextAlign.left : TextAlign.center,
            style: ParkKeysText.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Barangay tricycle queue • Cabadbaran City',
            textAlign: expanded ? TextAlign.left : TextAlign.center,
            style: ParkKeysText.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 28),
            const _BrandPoint(
              icon: Icons.confirmation_number_outlined,
              text: 'Get a queue number sa imong barangay.',
            ),
            const SizedBox(height: 12),
            const _BrandPoint(
              icon: Icons.groups_outlined,
              text: 'Tan-awa pila ka pasahero ang naa sa unahan.',
            ),
            const SizedBox(height: 12),
            const _BrandPoint(
              icon: Icons.schedule_outlined,
              text: 'Live updates every 3 seconds.',
            ),
          ],
        ],
      ),
    );

    final decorated = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ParkKeysColors.greenDark,
            ParkKeysColors.green,
          ],
        ),
      ),
      child: panel,
    );

    if (!expanded) return SizedBox(width: double.infinity, child: decorated);
    return SizedBox.expand(child: decorated);
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ParkKeysColors.yellow, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: ParkKeysText.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.label,
    required this.email,
    required this.password,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String email;
  final String password;
  final IconData icon;
  final void Function(String email, String password) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ParkKeysRadii.control),
        ),
        leading: BrandIconWell(icon: icon),
        title: Text(label),
        subtitle: Text(email),
        trailing: const Icon(Icons.touch_app, size: 18),
        onTap: () => onTap(email, password),
      ),
    );
  }
}
