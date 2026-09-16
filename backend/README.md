# Backend

The backend supports an experimental Quran-specific Wav2Vec2 ASR engine. It
aligns the recognized Arabic transcript with the selected ayah and reports
possible missing words and letter differences. These are speech-recognition
results, not certified pronunciation judgments.

Each word can include structured `issues`, the recognized word, and expected
Tajweed rules from Quran Foundation's Uthmani Tajweed annotations. The rules
identify what applies to the text; the current engine does not yet measure
whether the learner performed those rules correctly.

## Endpoints

- `GET /health`
- `POST /v1/recitation/analyze`

Multipart fields:

- `surah`: integer
- `ayah`: integer
- `expected_text`: Arabic Quran text
- `audio`: optional recorded audio file

## Next model milestone

Add a phoneme-level model and teacher-labelled learner recordings for calibrated
makhraj and Tajweed scoring. Do not present ASR string similarity as certified
Tajweed correctness.

## Local experimental engine

The model is about 1.3 GB and is downloaded from Hugging Face when the backend
first starts. Install PyTorch for your CUDA or CPU platform first, then install the
remaining dependencies:

```powershell
# NVIDIA example; choose the current command for your system from pytorch.org
pip install torch --index-url https://download.pytorch.org/whl/cu128
pip install -r requirements-ml.txt
uvicorn app.main:app --reload --port 8000
```

FFmpeg must be available on `PATH`. The desktop app connects to
`http://127.0.0.1:8000` by default. On Windows, start the backend from the
project root and keep its terminal open while using the app:

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_real_analysis_backend.ps1
```

The backend warms the model in the background. `GET /health` reports
`model_status: warming` until it changes to `ready`. Set
`QURAN_ASR_PRELOAD=0` to disable startup warm-up.

Configure another endpoint at build time:

```bash
flutter run --dart-define=RECITATION_API_URL=https://your-api.example.com
```
