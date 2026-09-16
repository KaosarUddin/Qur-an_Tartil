# Experimental Quran ASR model

The default inference model is:

- `rabah2026/wav2vec2-large-xlsr-53-arabic-quran-v_final`
- Source: <https://huggingface.co/rabah2026/wav2vec2-large-xlsr-53-arabic-quran-v_final>
- Declared license: Apache-2.0
- Base architecture: Wav2Vec2 CTC

The weights are not included in this repository. Hugging Face downloads them
to its local cache on the first recorded-audio analysis.

The model card describes Quranic Arabic transcription, not certified learner
pronunciation or Tajweed assessment. This project therefore labels its result
as an **experimental match** and uses the model only to produce an Arabic
transcript for alignment. Character differences can be false positives and
must not be treated as religious judgments.

Expected Tajweed labels come from Quran Foundation's Uthmani Tajweed endpoint:

<https://api-docs.quran.foundation/docs/content_apis_versioned/4.0.0/quran-verses-uthmani-tajweed/>

Those labels describe the expected written rule. They do not show whether a
learner performed the acoustic rule correctly.
