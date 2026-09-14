# Quran Tarteel

A clean Flutter + FastAPI starter for a Quran learning app inspired by the *category* of AI Quran tutors, built with original code and UI.

## What works in this MVP

- Home dashboard
- All 114 surahs with 6,236 Arabic ayahs available offline
- Uthmani and Indo-Pak script ayah reader with surah metadata
- Optional colour-coded Tajweed reading mode with a rule legend
- Practice screen preserves the selected Uthmani, Tajweed, or Indo-Pak style
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

## Website and Windows download

The browser build is deployed from `main` with GitHub Pages at [kaosaruddin.github.io/Qur-an_Tartil](https://kaosaruddin.github.io/Qur-an_Tartil/). On the website, microphone recording and replay work in supported browsers, while analysis uses the clearly labelled local demo result until a public HTTPS analysis backend is configured.

Pushing a version tag such as `v0.1.0` builds a complete Windows ZIP and publishes it under [GitHub Releases](https://github.com/KaosarUddin/Qur-an_Tartil/releases). Extract the entire ZIP before opening `quran_tutor_mvp.exe`; the executable needs the bundled `data` directory and DLL files beside it.

## Quran text data

The bundled Uthmani Quran text and metadata come from the [Tanzil Project](https://tanzil.net/). The text contains all 114 surahs and 6,236 ayahs and is distributed verbatim under the Creative Commons Attribution 3.0 license. Tanzil's required copyright and license notice is retained in `assets/quran/quran-uthmani.txt`.

The verbatim source asset includes the basmala at the start of each surah except At-Tawbah (Surah 9). At runtime, the reader separates it into a dedicated surah-opening header instead of treating it as part of Ayah 1. Al-Fatihah is the exception: its basmala remains numbered Ayah 1 under the bundled Hafs verse numbering. The basmala within An-Naml 27:30 is also preserved, and Surahs 95 and 97 retain Tanzil's documented Uthmani idgham spelling.

For the optional Tajweed-colour and Indo-Pak modes, the reader requests the selected surah from the [Quran Foundation Content API](https://api-docs.quran.com/docs/content_apis_versioned/4.0.0/quran-verses-by-script/). Indo-Pak mode also loads the official QuranWBW IndoPak Nastaleeq typeface from Quran Foundation's font CDN at runtime. Tajweed rules are transferred onto the matching Indo-Pak letters through per-ayah sequence alignment; unmatched letters remain uncoloured, and an ayah remains plain if the scripts do not meet the safety threshold. Responses and the font are held only in memory for the current app session, without modifying the source content, and fall back to the bundled Tanzil Uthmani text and system font if the network is unavailable. The app displays the required Quran Foundation attribution alongside online script modes. Tajweed colour schemes can vary between Mushaf editions; use the rule labels, rather than colour alone, as the guide.

To fetch and validate a fresh verbatim copy from Tanzil:

```bash
dart run tool/fetch_quran.dart
```

## Reference recitation audio

Ayah reference audio is streamed from the [Verse By Verse Quran Project](https://everyayah.com/) and recited by Mishary Rashid Alafasy. An internet connection is required. Per-ayah practice plays only the selected numbered ayah; a surah's separately displayed basmala is not merged into Ayah 1 playback.

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
