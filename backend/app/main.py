from __future__ import annotations

from hashlib import sha256
from typing import Annotated

from fastapi import FastAPI, File, Form, UploadFile
from pydantic import BaseModel

app = FastAPI(
    title="Quran Tarteel AI API",
    version="0.1.0",
    description="MVP API. Word-level scores are simulated until the Quranic ASR/pronunciation model is integrated.",
)


class WordResult(BaseModel):
    word: str
    status: str
    score: float
    tip: str


class RecitationResponse(BaseModel):
    surah: int
    ayah: int
    overall_score: float
    words: list[WordResult]
    engine: str = "mock-v0"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "engine": "mock-v0"}


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
        if marker <= 5:
            status, score, tip = "correct", 0.94, "Clear pronunciation."
        elif marker <= 7:
            status, score, tip = "improve", 0.76, "Repeat slowly and compare with a trusted teacher recitation."
        else:
            status, score, tip = "incorrect", 0.49, "Retry this word; alignment confidence is low."
        words.append(WordResult(word=token, status=status, score=score, tip=tip))

    overall = sum(w.score for w in words) / max(len(words), 1)
    return RecitationResponse(
        surah=surah,
        ayah=ayah,
        overall_score=round(overall, 4),
        words=words,
    )
