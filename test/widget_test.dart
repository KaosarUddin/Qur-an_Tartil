import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/main.dart';

void main() {
  testWidgets('shows the Quran Tarteel home screen', (tester) async {
    await tester.pumpWidget(const QuranTutorApp());

    expect(find.text('Quran Tarteel'), findsOneWidget);
    expect(
      find.text(
        'السَّلَامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ',
      ),
      findsOneWidget,
    );
    expect(find.text('Read Quran'), findsOneWidget);
  });
}
