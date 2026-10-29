import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/driver_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/passenger_dashboard.dart';
import 'screens/register_screen.dart';
import 'state/auth_state.dart';

/// GoRouter + role-based guards.
GoRouter buildRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      // Ginahulat sa app ang restore sa token; ayaw pa-redirect.
      if (auth.isRestoring) return null;

      final location = state.matchedLocation;
      final isAuthPage = location == '/login' || location == '/register';

      if (!auth.isAuthenticated) {
        if (isAuthPage) return null;
        return '/login';
      }

      // Naka-login na: ayaw na ipakita ang login/register.
      if (isAuthPage || location == '/') return auth.homePath;

      // Role guard per section. Backend gihapon ang final check.
      if (location.startsWith('/passenger') && auth.role != 'passenger') {
        return auth.homePath;
      }
      if (location.startsWith('/driver') && auth.role != 'driver') {
        return auth.homePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/passenger',
        builder: (context, state) => const PassengerDashboard(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverDashboard(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off, size: 56),
            const SizedBox(height: 12),
            const Text('Page not found'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(auth.homePath),
              child: const Text('Go to my dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
