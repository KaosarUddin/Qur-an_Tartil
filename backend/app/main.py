from __future__ import annotations

from hashlib import sha256
from typing import Annotated

from fastapi import FastAPI, File, Form, UploadFile
from pydantic import BaseModel, Field

app = FastAPI(
    title="Quran Tarteel AI API",
    version="0.1.0",
    description="MVP API. Word-level scores are simulated until the Quranic ASR/pronunciation model is integrated.",
)


class FeedbackIssue(BaseModel):
    type: str
    title: str
    detail: str
    expected: str | None = None
    rule: str | None = None
    suggestion: str


class WordResult(BaseModel):
    word: str
    status: str
    score: float
    tip: str
    issues: list[FeedbackIssue] = Field(default_factory=list)


class RecitationResponse(BaseModel):
    surah: int
    ayah: int
    overall_score: float
    words: list[WordResult]
    engine: str = "mock-v1"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "engine": "mock-v1"}


def _sample_letter(word: str, offset: int) -> str | None:
    """Pick a letter for deterministic demo copy, ignoring Quran marks."""
    letters = [character for character in word if "\u0621" <= character <= "\u064a"]
    return letters[offset % len(letters)] if letters else None


def _demo_issue(word: str, marker: int, index: int) -> FeedbackIssue:
    letter = _sample_letter(word, marker + index)
    expected = letter or word
    if marker == 8:
        return FeedbackIssue(
            type="missing_letter",
            title="Possible missing letter",
            detail=f'The alignment was weakest around “{expected}”.',
            expected=expected,
            suggestion="Recite the word slowly and make every written letter audible.",
        )
    if marker in (6, 9):
        return FeedbackIssue(
            type="pronunciation",
            title="Letter pronunciation",
            detail=f'Pay attention to the articulation point of “{expected}”.',
            expected=expected,
            suggestion="Listen to the reference, then repeat the letter and the full word.",
        )
    return FeedbackIssue(
        type="tajweed",
        title="Tajweed timing",
        detail="The timing or nasal quality may need attention.",
        rule="Madd / ghunnah",
        suggestion="Compare the held sound with the reference recitation and repeat slowly.",
    )


@app.post("/v1/recitation/analyze", response_model=RecitationResponse)
async def analyze_recitation(
    surah: Annotated[int, Form()],
    ayah: Annotated[int, Form()],
    expected_text: Annotated[str, Form()],
    audio: Annotated[UploadFile | None, File()] = None,
) -> RecitationResponse:
    """Return deterministic demo feedback for the selected Ayah.

    The endpoint shape is intentionally production-like so the Flutter app
    will not need to change when this mock is replaced with real inference.
    """
    audio_bytes = await audio.read() if audio else b""
    seed = sha256(audio_bytes + expected_text.encode("utf-8")).digest()
    tokens = expected_text.split()
    words: list[WordResult] = []

    for i, token in enumerate(tokens):
        marker = seed[i % len(seed)] % 10
        issues: list[FeedbackIssue] = []
        if marker <= 5:
            status, score, tip = "correct", 0.94, "Clear pronunciation."
        elif marker <= 7:
            status, score, tip = "improve", 0.76, "One detail may need attention."
            issues.append(_demo_issue(token, marker, i))
        else:
            status, score, tip = "incorrect", 0.49, "Retry this word; alignment confidence is low."
            issues.append(_demo_issue(token, marker, i))
        words.append(
            WordResult(word=token, status=status, score=score, tip=tip, issues=issues)
        )

    overall = sum(w.score for w in words) / max(len(words), 1)
    return RecitationResponse(
        surah=surah,
        ayah=ayah,
        overall_score=round(overall, 4),
        words=words,
    )
