import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkkeys_web/screens/login_screen.dart';
import 'package:parkkeys_web/theme.dart';

void main() {
  testWidgets('login screen renders email and password form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const LoginScreen()),
    );

    expect(find.text('ParkKeys'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(
      find.text('View public queue board (no login)'),
      findsOneWidget,
    );
  });
}
