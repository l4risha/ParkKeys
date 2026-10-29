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
    return Scaffold(
      backgroundColor: ParkKeysColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: ParkKeysColors.yellow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.electric_rickshaw,
                size: 42,
                color: ParkKeysColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ParkKeys',
              style: ParkKeysText.textTheme.headlineMedium?.copyWith(
                color: ParkKeysColors.green,
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
