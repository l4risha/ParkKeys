import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/manage_drivers.dart';
import 'screens/admin/manage_routes.dart';
import 'screens/admin/queue_monitoring.dart';
import 'screens/driver_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/passenger_dashboard.dart';
import 'screens/public_status_screen.dart';
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
      final isPublic = location == '/public';

      if (!auth.isAuthenticated) {
        if (isAuthPage || isPublic) return null;
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
      if (location.startsWith('/admin') && auth.role != 'admin') {
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
        path: '/public',
        builder: (context, state) => const PublicStatusScreen(),
      ),
      GoRoute(
        path: '/passenger',
        builder: (context, state) => const PassengerDashboard(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/drivers',
        builder: (context, state) => const ManageDriversScreen(),
      ),
      GoRoute(
        path: '/admin/routes',
        builder: (context, state) => const ManageRoutesScreen(),
      ),
      GoRoute(
        path: '/admin/queues',
        builder: (context, state) => const QueueMonitoringScreen(),
      ),
      GoRoute(
        path: '/admin/queues/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _NotFoundScreen();
          return QueueDetailScreen(routeId: id);
        },
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
