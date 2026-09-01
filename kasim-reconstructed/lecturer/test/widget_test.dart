import 'package:flutter_test/flutter_test.dart';
import 'package:kasim_lecturer/main.dart';

void main() {
  testWidgets('KasimLecturerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KasimLecturerApp());
    expect(find.text('KASIM LECTURER'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
