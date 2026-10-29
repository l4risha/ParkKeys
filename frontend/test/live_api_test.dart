import 'package:flutter_test/flutter_test.dart';
import 'package:parkkeys_web/services/api_client.dart';

/// Optional live test. Nagkinahanglan ug running backend.
/// Run: flutter test --dart-define=LIVE_API=true test/live_api_test.dart
const _live = bool.fromEnvironment('LIVE_API');

void main() {
  test('seeded roles can log in against the real API', () async {
    const accounts = {
      'admin@parkkeys.com': ('Admin123!', 'admin'),
      'driver1@parkkeys.com': ('Driver123!', 'driver'),
      'passenger1@parkkeys.com': ('Passenger123!', 'passenger'),
    };

    for (final entry in accounts.entries) {
      final api = ApiClient();
      final result = await api.login(entry.key, entry.value.$1);
      expect(result.user.role, entry.value.$2);
      expect(result.user.email, entry.key);

      api.setToken(result.token);
      final me = await api.me();
      expect(me.role, entry.value.$2);

      final routes = await api.routes();
      expect(routes.length, 31, reason: '31 barangays gikan sa DB');
    }
  }, skip: _live ? false : 'Set --dart-define=LIVE_API=true');

  test('admin dashboard + public board return real counts', () async {
    final api = ApiClient();
    final result = await api.login('admin@parkkeys.com', 'Admin123!');
    api.setToken(result.token);

    final stats = await api.dashboard();
    expect(stats.routesActive, 31);

    final queues = await api.adminQueues();
    expect(queues.length, 31);

    final publicApi = ApiClient();
    final publicRoutes = await publicApi.publicRoutes();
    expect(publicRoutes.length, 31);
    expect(publicRoutes.first.demandLevel, isIn(['LOW', 'MEDIUM', 'HIGH']));
  }, skip: _live ? false : 'Set --dart-define=LIVE_API=true');
}
