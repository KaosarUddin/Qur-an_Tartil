# Backend

This backend deliberately uses a mock scoring engine while preserving a production-ready endpoint contract.

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
