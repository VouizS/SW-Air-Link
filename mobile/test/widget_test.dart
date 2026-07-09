import 'package:flutter_test/flutter_test.dart';
import 'package:sw_air_link/main.dart';

void main() {
  testWidgets('SW Air Link pairing screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('SW Air Link'), findsOneWidget);
    expect(find.text('Preparar conexão'), findsOneWidget);
  });
}
