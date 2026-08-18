import 'package:flutter_test/flutter_test.dart';
import 'package:kasim_student/main.dart';

void main() {
  testWidgets('KasimStudentApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KasimStudentApp());
    expect(find.text('Student Exam Access'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Exam Code'), findsOneWidget);
  });
}
