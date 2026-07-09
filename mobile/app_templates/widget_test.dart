import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sw_air_link/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SW Air Link basic screen loads', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SWAirLinkApp());
    await tester.pumpAndSettle();

    expect(find.text('SW Air Link'), findsOneWidget);
    expect(find.text('Preparar conexão'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('AMOLED'), findsOneWidget);
  });
}
