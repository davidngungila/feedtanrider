import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feedtanstore/screens/login_screen.dart';
import 'package:feedtanstore/screens/splash_screen.dart';

void main() {
  testWidgets('Splash shows the Feedtan Rider brand', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.text('RIDER'), findsOneWidget);
    expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
  });

  testWidgets('Login screen renders sign-in form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
