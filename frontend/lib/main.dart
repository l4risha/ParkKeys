import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'services/api_client.dart';
import 'state/auth_state.dart';
import 'theme.dart';

void main() {
  runApp(const ParkKeysApp());
}

class ParkKeysApp extends StatefulWidget {
  const ParkKeysApp({super.key});

  @override
  State<ParkKeysApp> createState() => _ParkKeysAppState();
}

class _ParkKeysAppState extends State<ParkKeysApp> {
  late final AuthState _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthState(ApiClient());
    _router = buildRouter(_auth);
    _auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthState>.value(
      value: _auth,
      child: AnimatedBuilder(
        animation: _auth,
        builder: (context, child) {
          final theme = buildAppTheme();
          // Splash samtang ginabasa ang saved JWT token sa browser.
          if (_auth.isRestoring) {
            return MaterialApp(
              title: 'ParkKeys',
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: const _SplashScreen(),
            );
          }
          return MaterialApp.router(
            title: 'ParkKeys',
            debugShowCheckedModeBanner: false,
            theme: theme,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electric_rickshaw,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'ParkKeys',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
