from __future__ import annotations

import os
import re
import subprocess
import threading
import unicodedata
from dataclasses import dataclass, field
from functools import lru_cache
from html.parser import HTMLParser
from urllib.request import Request, urlopen


MODEL_ID = os.getenv(
    "QURAN_ASR_MODEL",
    "rabah2026/wav2vec2-large-xlsr-53-arabic-quran-v_final",
)
ENGINE_NAME = "quran-asr-arabic-experimental-v1"
SAMPLE_RATE = 16_000
MAX_AUDIO_SECONDS = 180


@dataclass(frozen=True)
class DetectedIssue:
    type: str
    title: str
    detail: str
    suggestion: str
    expected: str | None = None
    observed: str | None = None
    rule: str | None = None


@dataclass(frozen=True)
class EvaluatedWord:
    word: str
    status: str
    score: float
    tip: str
    observed: str | None = None
    issues: tuple[DetectedIssue, ...] = ()
    rules: tuple[str, ...] = ()


@dataclass(frozen=True)
class AnalysisResult:
    transcript: str
    words: tuple[EvaluatedWord, ...]
    overall_score: float
    extra_words: tuple[str, ...] = ()


_ARABIC_MARKS = re.compile(
    "[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]"
)
_NON_ARABIC = re.compile("[^\u0621-\u063a\u0641-\u064a\u066e-\u06d3]+")
_END_MARKS = re.compile("[\u06dd\u06de\u06e9\u0660-\u0669]")


def normalize_arabic(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    value = _ARABIC_MARKS.sub("", value)
    value = _END_MARKS.sub("", value)
    value = value.translate(
        str.maketrans(
            {
                "أ": "ا",
                "إ": "ا",
                "آ": "ا",
                "ٱ": "ا",
                "ى": "ي",
                "ئ": "ي",
                "ؤ": "و",
                "ة": "ه",
            }
        )
    )
    return _NON_ARABIC.sub("", value)


def _edit_distance(left: str, right: str) -> int:
    previous = list(range(len(right) + 1))
    for row, left_character in enumerate(left, start=1):
        current = [row]
        for column, right_character in enumerate(right, start=1):
            current.append(
                min(
                    previous[column] + 1,
                    current[column - 1] + 1,
                    previous[column - 1]
                    + (left_character != right_character),
                )
            )
        previous = current
    return previous[-1]


def word_similarity(expected: str, observed: str) -> float:
    expected_normalized = normalize_arabic(expected)
    observed_normalized = normalize_arabic(observed)
    longest = max(len(expected_normalized), len(observed_normalized), 1)
    return max(
        0.0,
        1.0 - _edit_distance(expected_normalized, observed_normalized) / longest,
    )


def _align_words(
    expected: list[str], observed: list[str]
) -> tuple[list[int | None], list[int]]:
    rows = len(expected) + 1
    columns = len(observed) + 1
    costs = [[0.0] * columns for _ in range(rows)]
    directions = [[""] * columns for _ in range(rows)]
    for row in range(1, rows):
        costs[row][0] = float(row)
        directions[row][0] = "delete"
    for column in range(1, columns):
        costs[0][column] = float(column)
        directions[0][column] = "insert"

    for row in range(1, rows):
        for column in range(1, columns):
            diagonal = costs[row - 1][column - 1] + (
                1.0 - word_similarity(expected[row - 1], observed[column - 1])
            )
            delete = costs[row - 1][column] + 1.0
            insert = costs[row][column - 1] + 1.0
            costs[row][column], directions[row][column] = min(
                (diagonal, "diagonal"),
                (delete, "delete"),
                (insert, "insert"),
                key=lambda item: item[0],
            )

    mapping: list[int | None] = [None] * len(expected)
    extras: list[int] = []
    row, column = len(expected), len(observed)
    while row > 0 or column > 0:
        direction = directions[row][column]
        if direction == "diagonal":
            mapping[row - 1] = column - 1
            row -= 1
            column -= 1
        elif direction == "delete":
            row -= 1
        else:
            extras.append(column - 1)
            column -= 1
    extras.reverse()
    return mapping, extras


def _letter_issues(expected: str, observed: str) -> list[DetectedIssue]:
    expected_letters = normalize_arabic(expected)
    observed_letters = normalize_arabic(observed)
    rows = len(expected_letters) + 1
    columns = len(observed_letters) + 1
    costs = [[0] * columns for _ in range(rows)]
    directions = [[""] * columns for _ in range(rows)]
    for row in range(1, rows):
        costs[row][0] = row
        directions[row][0] = "delete"
    for column in range(1, columns):
        costs[0][column] = column
        directions[0][column] = "insert"
    for row in range(1, rows):
        for column in range(1, columns):
            equal = expected_letters[row - 1] == observed_letters[column - 1]
            candidates = (
                (costs[row - 1][column - 1] + (not equal), "equal" if equal else "replace"),
                (costs[row - 1][column] + 1, "delete"),
                (costs[row][column - 1] + 1, "insert"),
            )
            costs[row][column], directions[row][column] = min(
                candidates, key=lambda item: item[0]
            )

    issues: list[DetectedIssue] = []
    row, column = len(expected_letters), len(observed_letters)
    while row > 0 or column > 0:
        direction = directions[row][column]
        if direction == "equal":
            row -= 1
            column -= 1
        elif direction == "replace":
            issues.append(
                DetectedIssue(
                    type="pronunciation",
                    title="Possible letter substitution",
                    detail=(
                        f'The recognizer heard “{observed_letters[column - 1]}” '
                        f'instead of “{expected_letters[row - 1]}”.'
                    ),
                    expected=expected_letters[row - 1],
                    observed=observed_letters[column - 1],
                    suggestion="Repeat the two letter sounds slowly, then recite the word again.",
                )
            )
            row -= 1
            column -= 1
        elif direction == "delete":
            issues.append(
                DetectedIssue(
                    type="missing_letter",
                    title="Possible missing letter",
                    detail=f'The letter “{expected_letters[row - 1]}” was not recognized.',
                    expected=expected_letters[row - 1],
                    suggestion="Make the letter audible and preserve its articulation point.",
                )
            )
            row -= 1
        else:
            issues.append(
                DetectedIssue(
                    type="extra_letter",
                    title="Possible additional sound",
                    detail=f'The recognizer heard an additional “{observed_letters[column - 1]}”.',
                    observed=observed_letters[column - 1],
                    suggestion="Repeat the word without inserting a sound between its letters.",
                )
            )
            column -= 1
    issues.reverse()
    return issues[:3]


def evaluate_transcript(
    expected_text: str,
    transcript: str,
    rules_by_word: list[list[str]] | None = None,
) -> AnalysisResult:
    expected_words = [word for word in expected_text.split() if normalize_arabic(word)]
    observed_words = [word for word in transcript.split() if normalize_arabic(word)]
    mapping, extra_indexes = _align_words(expected_words, observed_words)
    evaluated: list[EvaluatedWord] = []

    for index, expected_word in enumerate(expected_words):
        observed_index = mapping[index]
        rules = tuple(rules_by_word[index]) if rules_by_word and index < len(rules_by_word) else ()
        if observed_index is None:
            evaluated.append(
                EvaluatedWord(
                    word=expected_word,
                    status="incorrect",
                    score=0.0,
                    tip="This word was not recognized in the recording.",
                    issues=(
                        DetectedIssue(
                            type="missing_word",
                            title="Possible missing word",
                            detail="No matching spoken word was found.",
                            expected=expected_word,
                            suggestion="Recite the complete word and compare it with the reference.",
                        ),
                    ),
                    rules=rules,
                )
            )
            continue

        observed_word = observed_words[observed_index]
        score = word_similarity(expected_word, observed_word)
        if score >= 0.9:
            status, tip = "correct", "The recognized letters match this word."
        elif score >= 0.6:
            status, tip = "improve", "Some recognized letters need attention."
        else:
            status, tip = "incorrect", "The recognized word differs significantly."
        evaluated.append(
            EvaluatedWord(
                word=expected_word,
                observed=observed_word,
                status=status,
                score=round(score, 4),
                tip=tip,
                issues=tuple(_letter_issues(expected_word, observed_word)),
                rules=rules,
            )
        )

    overall = (
        sum(word.score for word in evaluated) / len(evaluated) if evaluated else 0.0
    )
    extras = tuple(observed_words[index] for index in extra_indexes)
    return AnalysisResult(
        transcript=transcript.strip(),
        words=tuple(evaluated),
        overall_score=round(overall, 4),
        extra_words=extras,
    )


_RULE_LABELS = {
    "ghunnah": "Ghunnah",
    "idgham_ghunnah": "Idgham with ghunnah",
    "idgham_wo_ghunnah": "Idgham without ghunnah",
    "idgham_mutajanisayn": "Idgham mutajanisayn",
    "idgham_mutaqaribayn": "Idgham mutaqaribayn",
    "idgham_shafawi": "Idgham shafawi",
    "ikhafa": "Ikhfa",
    "ikhafa_shafawi": "Ikhfa shafawi",
    "iqlab": "Iqlab",
    "madda_normal": "Madd: 2 counts",
    "madda_permissible": "Madd: 2, 4, or 6 counts",
    "madda_necessary": "Madd: 6 counts",
    "madda_obligatory": "Madd: 4 or 5 counts",
    "qalaqah": "Qalqalah",
    "ham_wasl": "Hamzat al-wasl",
    "laam_shamsiyah": "Lam shamsiyyah",
    "slnt": "Silent letter",
}


class _TajweedMarkupParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.words: list[tuple[str, list[str]]] = []
        self._characters: list[str] = []
        self._rules: set[str] = set()
        self._active_rules: list[str] = []
        self._skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "span" and values.get("class") == "end":
            self._skip_depth += 1
        elif tag == "tajweed":
            rule = values.get("class")
            if rule:
                self._active_rules.append(rule)

    def handle_endtag(self, tag: str) -> None:
        if tag == "span" and self._skip_depth:
            self._skip_depth -= 1
        elif tag == "tajweed" and self._active_rules:
            self._active_rules.pop()

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        for character in data:
            if character.isspace():
                self._finish_word()
                continue
            self._characters.append(character)
            self._rules.update(self._active_rules)

    def close(self) -> None:
        super().close()
        self._finish_word()

    def _finish_word(self) -> None:
        word = "".join(self._characters)
        if normalize_arabic(word):
            labels = sorted({_RULE_LABELS.get(rule, rule.replace("_", " ").title()) for rule in self._rules})
            self.words.append((word, labels))
        self._characters.clear()
        self._rules.clear()


def parse_tajweed_rules(markup: str, expected_text: str) -> list[list[str]]:
    parser = _TajweedMarkupParser()
    parser.feed(markup)
    parser.close()
    expected_words = [word for word in expected_text.split() if normalize_arabic(word)]
    markup_words = [word for word, _ in parser.words]
    mapping, _ = _align_words(expected_words, markup_words)
    return [
        parser.words[markup_index][1] if markup_index is not None else []
        for markup_index in mapping
    ]


@lru_cache(maxsize=1024)
def fetch_tajweed_markup(surah: int, ayah: int) -> str | None:
    url = (
        "https://api.quran.com/api/v4/quran/verses/uthmani_tajweed"
        f"?verse_key={surah}:{ayah}"
    )
    try:
        import json

        request = Request(url, headers={"User-Agent": "Quran-Tarteel/0.2"})
        with urlopen(request, timeout=8) as response:
            payload = json.load(response)
        verses = payload.get("verses", [])
        return verses[0].get("text_uthmani_tajweed") if verses else None
    except Exception:
        return None


class QuranAsrEngine:
    def __init__(self) -> None:
        self._load_lock = threading.Lock()
        self._processor = None
        self._model = None
        self._torch = None
        self._device = None

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        self._load()

    def transcribe(self, audio_bytes: bytes) -> str:
        samples = self._decode_audio(audio_bytes)
        self._load()
        inputs = self._processor(
            samples,
            sampling_rate=SAMPLE_RATE,
            return_tensors="pt",
            padding=True,
        )
        input_values = inputs.input_values.to(self._device)
        attention_mask = getattr(inputs, "attention_mask", None)
        if attention_mask is not None:
            attention_mask = attention_mask.to(self._device)
        with self._torch.inference_mode():
            logits = self._model(
                input_values,
                attention_mask=attention_mask,
            ).logits
        predicted_ids = self._torch.argmax(logits, dim=-1)
        return self._processor.batch_decode(predicted_ids)[0].strip()

    def _load(self) -> None:
        if self._model is not None:
            return
        with self._load_lock:
            if self._model is not None:
                return
            try:
                import torch
                from transformers import AutoProcessor, Wav2Vec2ForCTC
            except ImportError as error:
                raise RuntimeError(
                    "The real ASR dependencies are not installed. "
                    "Install backend/requirements-ml.txt."
                ) from error

            device = "cuda" if torch.cuda.is_available() else "cpu"
            try:
                processor = AutoProcessor.from_pretrained(
                    MODEL_ID,
                    local_files_only=True,
                )
                model = Wav2Vec2ForCTC.from_pretrained(
                    MODEL_ID,
                    local_files_only=True,
                )
            except OSError:
                processor = AutoProcessor.from_pretrained(MODEL_ID)
                model = Wav2Vec2ForCTC.from_pretrained(MODEL_ID)
            model.to(device)
            model.eval()
            self._torch = torch
            self._processor = processor
            self._model = model
            self._device = device

    @staticmethod
    def _decode_audio(audio_bytes: bytes):
        if not audio_bytes:
            raise ValueError("The recording is empty.")
        command = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            "pipe:0",
            "-ac",
            "1",
            "-ar",
            str(SAMPLE_RATE),
            "-f",
            "f32le",
            "pipe:1",
        ]
        completed = subprocess.run(
            command,
            input=audio_bytes,
            capture_output=True,
            check=False,
            timeout=45,
        )
        if completed.returncode != 0:
            detail = completed.stderr.decode("utf-8", errors="replace").strip()
            raise ValueError(f"The recording could not be decoded. {detail}")

        import numpy as np

        samples = np.frombuffer(completed.stdout, dtype=np.float32)
        if len(samples) < SAMPLE_RATE // 4:
            raise ValueError("The recording is too short to analyze.")
        if len(samples) > SAMPLE_RATE * MAX_AUDIO_SECONDS:
            raise ValueError(
                f"The recording is longer than {MAX_AUDIO_SECONDS} seconds."
            )
        return samples


quran_asr_engine = QuranAsrEngine()
