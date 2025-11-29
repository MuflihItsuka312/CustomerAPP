// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customerapp/main.dart';

void main() {
  testWidgets('SmartLockerApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartLockerApp());

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    // Verify that the app builds successfully with title
    expect(find.text('Smart Locker'), findsOneWidget);
  });
}
