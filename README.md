# Quran Tartil

A clean Flutter + FastAPI starter for a Quran learning app inspired by the *category* of AI Quran tutors, built with original code and UI.

## What works in this MVP

- Home dashboard
- All 114 surahs with 6,236 Arabic ayahs available offline
- Uthmani-script ayah reader with surah metadata
- Optional colour-coded Tajweed reading mode with a rule legend
- Automatic reference recitation after each analysis
- Side-by-side playback of the reference recitation and learner recording
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

When Tajweed colours are enabled, the reader requests the selected surah's annotated Uthmani text from the [Quran Foundation Content API](https://api-docs.quran.com/docs/content_apis_versioned/4.0.0/quran-verses-uthmani-tajweed/). The response is held only in memory for the current app session, is displayed without modifying its text, and falls back to the bundled Tanzil text if the network is unavailable. The app displays the required Quran Foundation attribution alongside the colour legend. Tajweed colour schemes can vary between Mushaf editions; use the rule labels, rather than colour alone, as the guide.

To fetch and validate a fresh verbatim copy from Tanzil:

```bash
dart run tool/fetch_quran.dart
```

## Reference recitation audio

Ayah reference audio is streamed from the [Verse By Verse Quran Project](https://everyayah.com/) and recited by Mishary Rashid Alafasy. An internet connection is required. For the first ayah of surahs other than Al-Fatihah and At-Tawbah, the player queues that surah's basmala track before its first numbered ayah so playback matches the displayed Tanzil text.

The current percentage and word feedback are explicitly labeled as demo results. They are deterministic prototype output, not measured pronunciation or certified Tajweed accuracy. Review the audio provider's terms and obtain any additional permission needed before commercial distribution.

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
