import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sw_air_link/main.dart';

void main() {
  testWidgets('SW Air Link AMOLED theme option loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());

    expect(find.text('SW Air Link'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('AMOLED'), findsOneWidget);
    expect(find.textContaining('pareamento real'), findsOneWidget);
  });
}
