import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/models/quran_models.dart';

void main() {
  test('parses detailed recitation issues from the API', () {
    final result = RecitationResult.fromJson({
      'overall_score': .72,
      'engine': 'quran-asr-v1',
      'words': [
        {
          'word': 'الرَّحْمَٰنِ',
          'status': 'improve',
          'score': .72,
          'tip': 'One detail needs attention.',
          'issues': [
            {
              'type': 'tajweed',
              'title': 'Madd is too short',
              'detail': 'The long vowel needs more time.',
              'expected': 'ا',
              'rule': 'Madd tabi‘i',
              'suggestion': 'Hold it for two counts.',
            }
          ],
        }
      ],
    });

    final issue = result.words.single.issues.single;
    expect(issue.type, FeedbackIssueType.tajweed);
    expect(issue.rule, 'Madd tabi‘i');
    expect(issue.expected, 'ا');
    expect(issue.suggestion, 'Hold it for two counts.');
  });

  test('remains compatible with responses that have no issue list', () {
    final feedback = WordFeedback.fromJson({
      'word': 'اللَّهِ',
      'status': 'correct',
      'score': .97,
      'tip': 'Clear pronunciation.',
    });

    expect(feedback.issues, isEmpty);
  });
}
