import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_wheel_app/main.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bottle+ 🎡'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}