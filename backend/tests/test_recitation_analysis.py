import unittest

from app.recitation_analysis import (
    evaluate_transcript,
    normalize_arabic,
    parse_tajweed_rules,
    word_similarity,
)


class RecitationAnalysisTests(unittest.TestCase):
    def test_normalizes_quran_marks_and_alif_variants(self):
        self.assertEqual(normalize_arabic("ٱلرَّحْمَٰنِ"), "الرحمن")
        self.assertEqual(normalize_arabic("إِيَّاكَ"), "اياك")

    def test_exact_transcript_scores_each_word(self):
        result = evaluate_transcript(
            "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            "بسم الله الرحمن الرحيم",
        )

        self.assertEqual(result.overall_score, 1.0)
        self.assertTrue(all(word.status == "correct" for word in result.words))

    def test_reports_a_missing_word_without_shifting_later_words(self):
        result = evaluate_transcript(
            "بسم الله الرحمن الرحيم",
            "بسم الله الرحيم",
        )

        self.assertEqual(result.words[2].status, "incorrect")
        self.assertEqual(result.words[2].issues[0].type, "missing_word")
        self.assertEqual(result.words[3].status, "correct")

    def test_reports_letter_substitutions(self):
        result = evaluate_transcript("الرحيم", "الرحمن")

        self.assertEqual(result.words[0].status, "improve")
        self.assertTrue(result.words[0].issues)
        self.assertTrue(
            any(issue.type == "pronunciation" for issue in result.words[0].issues)
        )
        self.assertLess(word_similarity("الرحيم", "الرحمن"), 1.0)

    def test_maps_tajweed_markup_to_expected_words(self):
        markup = (
            "بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ "
            "ٱلرَّحْمَ<tajweed class=madda_normal>ـٰ</tajweed>نِ "
            "ٱلرَّحِيمِ <span class=end>١</span>"
        )

        rules = parse_tajweed_rules(
            markup,
            "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        )

        self.assertEqual(rules[1], ["Hamzat al-wasl"])
        self.assertIn("Madd: 2 counts", rules[2])


if __name__ == "__main__":
    unittest.main()
