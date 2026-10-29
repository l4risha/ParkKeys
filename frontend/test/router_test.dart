import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parkkeys_web/router.dart';
import 'package:parkkeys_web/services/api_client.dart';
import 'package:parkkeys_web/state/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('router exposes every app route', () {
    final router = buildRouter(AuthState(ApiClient()));

    final paths = <String>[];
    for (final route in router.configuration.routes) {
      if (route is GoRoute) paths.add(route.path);
    }

    expect(
      paths,
      containsAll([
        '/login',
        '/register',
        '/public',
        '/passenger',
        '/driver',
        '/admin',
        '/admin/drivers',
        '/admin/routes',
        '/admin/queues',
        '/admin/queues/:id',
      ]),
    );
  });
}
