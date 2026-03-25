import 'package:flutter_test/flutter_test.dart';
import 'package:oyuncu_dukkani/main.dart';

void main() {
  testWidgets('Uygulama açılıyor', (WidgetTester tester) async {
    await tester.pumpWidget(const OyuncuDukkaniApp());
    expect(find.text('OYUNCU DÜKKANI'), findsOneWidget);
  });
}