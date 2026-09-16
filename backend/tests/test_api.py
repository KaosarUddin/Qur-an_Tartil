from io import BytesIO
from unittest import IsolatedAsyncioTestCase
from unittest.mock import patch

from fastapi import UploadFile

from app.main import analyze_recitation
from app.recitation_analysis import ENGINE_NAME, quran_asr_engine


class RecitationApiTests(IsolatedAsyncioTestCase):
    async def test_recording_uses_real_alignment_response_shape(self):
        audio = UploadFile(filename="recitation.wav", file=BytesIO(b"audio"))
        markup = (
            "بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ "
            "ٱلرَّحْمَ<tajweed class=madda_normal>ـٰ</tajweed>نِ "
            "ٱلرَّحِيمِ <span class=end>١</span>"
        )
        with patch.object(
            quran_asr_engine,
            "transcribe",
            return_value="بسم الله الرحمن الرحيم",
        ):
            response = await analyze_recitation(
                surah=1,
                ayah=1,
                expected_text="بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                tajweed_markup=markup,
                audio=audio,
            )

        self.assertEqual(response.engine, ENGINE_NAME)
        self.assertEqual(response.overall_score, 1.0)
        self.assertEqual(response.transcript, "بسم الله الرحمن الرحيم")
        self.assertEqual(len(response.words), 4)
        self.assertIn("Madd: 2 counts", response.words[2].rules)
        self.assertIn("not measured performance", response.assessment_notice)
