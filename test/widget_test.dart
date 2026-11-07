import 'package:flutter_test/flutter_test.dart';
import 'package:the_menu_driver_app/main.dart';

void main() {
  testWidgets('TheMenuDriverApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TheMenuDriverApp());
    // Advance past sequential splash screen delays (300ms + 600ms + 1500ms)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TheMenuDriverApp), findsOneWidget);
  });
}
