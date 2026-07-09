import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw_air_link/main.dart';

void main() {
  testWidgets('SW Air Link home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SW Air Link'), findsOneWidget);
    expect(find.textContaining('base real'), findsOneWidget);
    expect(find.byIcon(Icons.cast_connected), findsOneWidget);
  });
}
