# Quran Tartil

A clean Flutter + FastAPI starter for a Quran learning app inspired by the *category* of AI Quran tutors, built with original code and UI.

## What works in this MVP

- Home dashboard
- All 114 surahs with 6,236 Arabic ayahs available offline
- Uthmani-script ayah reader with surah metadata
- Audio-listen UI placeholder
- Microphone recording using `record`
- AI Check flow connected to a FastAPI endpoint
- Word-level feedback UI: correct / improve / incorrect
- Learning progress screen
- Prayer times placeholder screen
- Qibla placeholder screen
- Light/dark theme support

The first backend returns deterministic demo scores. This is intentional: it lets the entire mobile product flow work before we train/integrate Quranic ASR + forced alignment + pronunciation scoring.

## Folder layout

```text
quran_tutor_mvp/
  lib/
    main.dart
    app_theme.dart
    models/
    data/
    services/
    screens/
    widgets/
  backend/
    app/main.py
    requirements.txt
  assets/quran/
    quran-uthmani.txt
    quran-data.xml
  tool/
    fetch_quran.dart
```

## Run the Flutter app

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. In this folder, generate the native iOS/Android project shells once, then run:

```bash
flutter create .
flutter pub get
flutter run
```

The app uses `http://10.0.2.2:8000` on an Android emulator and `http://127.0.0.1:8000` on desktop and iOS.

## Quran text data

The bundled Uthmani Quran text and metadata come from the [Tanzil Project](https://tanzil.net/). The text contains all 114 surahs and 6,236 ayahs and is distributed verbatim under the Creative Commons Attribution 3.0 license. Tanzil's required copyright and license notice is retained in `assets/quran/quran-uthmani.txt`.

The basmala is included at the start of every surah except At-Tawbah (Surah 9), following the source text and standard Mushaf convention. The basmala within An-Naml 27:30 is also preserved. Surahs 95 and 97 retain Tanzil's documented Uthmani idgham spelling.

To fetch and validate a fresh verbatim copy from Tanzil:

```bash
dart run tool/fetch_quran.dart
```

## Run the backend

```bash
cd backend
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Then visit `http://127.0.0.1:8000/docs` for the API docs.

## Production roadmap

Replace the mock `/v1/recitation/analyze` implementation with:

1. Audio normalization / VAD
2. Ayah-specific constrained ASR
3. Forced alignment between expected Quran tokens and speech
4. Phoneme-level scoring
5. Tajweed-rule features (madd, ghunnah, ikhfa, idgham, qalqalah, etc.)
6. Confidence calibration
7. Human scholar/teacher validation before presenting prescriptive Tajweed feedback

Use properly licensed translation, audio, and font sources before publishing those additional resources.
