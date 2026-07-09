import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sw_air_link/main.dart';

void main() {
  testWidgets('SW Air Link mirror controls load', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());

    expect(find.text('SW Air Link'), findsOneWidget);
    expect(find.text('AMOLED'), findsOneWidget);
    expect(find.text('Iniciar espelhamento experimental'), findsOneWidget);
    expect(find.textContaining('espelhamento experimental real'), findsOneWidget);
  });
}
