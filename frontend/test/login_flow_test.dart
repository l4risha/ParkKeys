import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkkeys_web/models/models.dart';
import 'package:parkkeys_web/screens/login_screen.dart';
import 'package:parkkeys_web/services/api_client.dart';
import 'package:parkkeys_web/state/auth_state.dart';
import 'package:parkkeys_web/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake API para ma-test ang login form without network.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.expectedRole);

  final String expectedRole;

  @override
  Future<AuthResult> login(String email, String password) async {
    return AuthResult(
      token: 'fake-token',
      user: User(
        id: 1,
        email: email,
        fullName: 'Test $expectedRole',
        role: expectedRole,
        isActive: true,
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final role in ['passenger', 'driver', 'admin']) {
    testWidgets('login form saves $role session', (tester) async {
      final auth = AuthState(_FakeApiClient(role));
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthState>.value(
          value: auth,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '$role@parkkeys.com');
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(auth.user?.role, role);
      expect(auth.user?.email, '$role@parkkeys.com');
      expect(auth.homePath, '/$role');
    });
  }

  testWidgets('login form validates empty fields', (tester) async {
    final auth = AuthState(_FakeApiClient('passenger'));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(auth.user, isNull);
  });
}
