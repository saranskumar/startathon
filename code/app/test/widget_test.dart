import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/main.dart';

void main() {
  testWidgets('shows Hello World', (WidgetTester tester) async {
    await tester.pumpWidget(const HelloWorldApp());
    expect(find.text('Hello World'), findsOneWidget);
  });
}
