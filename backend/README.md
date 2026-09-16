# Backend

This backend deliberately uses a mock scoring engine while preserving a production-ready endpoint contract.

Each word can include structured `issues` with a `type` (`missing_letter`,
`pronunciation`, or `tajweed`), an explanation, the expected letter or rule,
and a practice suggestion. The mock values are UI examples only and are not
inferred from the uploaded audio.

## Endpoints

- `GET /health`
- `POST /v1/recitation/analyze`

Multipart fields:

- `surah`: integer
- `ayah`: integer
- `expected_text`: Arabic Quran text
- `audio`: optional recorded audio file

## Next model milestone

A production scorer should return evidence-based word/phoneme alignment. Do not present mock or generic ASR confidence as Tajweed correctness.
