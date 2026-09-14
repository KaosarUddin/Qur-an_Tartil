import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/main.dart';

void main() {
  testWidgets('shows the Quran Tutor home screen', (tester) async {
    await tester.pumpWidget(const QuranTutorApp());

    expect(find.text('Assalamu Alaikum'), findsOneWidget);
    expect(find.text('Read Quran'), findsOneWidget);
  });
}
