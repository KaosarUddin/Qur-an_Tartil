from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from hashlib import sha256
import os
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .recitation_analysis import (
    ENGINE_NAME,
    evaluate_transcript,
    fetch_tajweed_markup,
    parse_tajweed_rules,
    quran_asr_engine,
)


@asynccontextmanager
async def lifespan(application: FastAPI):
    if os.getenv("QURAN_ASR_PRELOAD", "1") == "1":
        application.state.model_error = None
        application.state.model_warmup = asyncio.create_task(
            _warm_model(application)
        )
    yield


async def _warm_model(application: FastAPI) -> None:
    try:
        await asyncio.to_thread(quran_asr_engine.load)
    except Exception as error:
        application.state.model_error = str(error)

app = FastAPI(
    title="Quran Tarteel AI API",
    version="0.2.0",
    description=(
        "Experimental Quran-specific ASR alignment API. Tajweed rule labels "
        "describe the expected text and are not yet audio-validated grades."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://kaosaruddin.github.io",
        *[
            origin.strip()
            for origin in os.getenv("RECITATION_ALLOWED_ORIGINS", "").split(",")
            if origin.strip()
        ],
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


class FeedbackIssue(BaseModel):
    type: str
    title: str
    detail: str
    expected: str | None = None
    observed: str | None = None
    rule: str | None = None
    suggestion: str


class WordResult(BaseModel):
    word: str
    status: str
    score: float
    tip: str
    observed: str | None = None
    issues: list[FeedbackIssue] = Field(default_factory=list)
    rules: list[str] = Field(default_factory=list)


class RecitationResponse(BaseModel):
    surah: int
    ayah: int
    overall_score: float
    words: list[WordResult]
    engine: str = "mock-v1"
    transcript: str | None = None
    extra_words: list[str] = Field(default_factory=list)
    assessment_notice: str | None = None


@app.get("/health")
def health() -> dict[str, str]:
    model_error = getattr(app.state, "model_error", None)
    return {
        "status": "ok",
        "engine": ENGINE_NAME,
        "model_status": (
            "ready"
            if quran_asr_engine.is_loaded
            else "failed"
            if model_error
            else "warming"
            if os.getenv("QURAN_ASR_PRELOAD", "1") == "1"
            else "cold"
        ),
    }


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
    tajweed_markup: Annotated[str | None, Form()] = None,
    audio: Annotated[UploadFile | None, File()] = None,
) -> RecitationResponse:
    """Align a Quran-specific ASR transcript with the selected Ayah."""
    audio_bytes = await audio.read() if audio else b""

    markup = tajweed_markup or await asyncio.to_thread(
        fetch_tajweed_markup, surah, ayah
    )
    rules_by_word = (
        parse_tajweed_rules(markup, expected_text) if markup else None
    )

    if audio_bytes:
        try:
            transcript = await asyncio.to_thread(
                quran_asr_engine.transcribe, audio_bytes
            )
            analysis = evaluate_transcript(
                expected_text,
                transcript,
                rules_by_word,
            )
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
        except RuntimeError as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except Exception as error:
            raise HTTPException(
                status_code=500,
                detail="The Quran ASR engine could not analyze this recording.",
            ) from error

        return RecitationResponse(
            surah=surah,
            ayah=ayah,
            overall_score=analysis.overall_score,
            words=[
                WordResult(
                    word=word.word,
                    observed=word.observed,
                    status=word.status,
                    score=word.score,
                    tip=word.tip,
                    issues=[
                        FeedbackIssue(
                            type=issue.type,
                            title=issue.title,
                            detail=issue.detail,
                            expected=issue.expected,
                            observed=issue.observed,
                            rule=issue.rule,
                            suggestion=issue.suggestion,
                        )
                        for issue in word.issues
                    ],
                    rules=list(word.rules),
                )
                for word in analysis.words
            ],
            engine=ENGINE_NAME,
            transcript=analysis.transcript,
            extra_words=list(analysis.extra_words),
            assessment_notice=(
                "Experimental Quran ASR match. Word and letter differences "
                "come from speech recognition and can contain false positives. "
                "Listed Tajweed rules are expected rules, not measured performance."
            ),
        )

    # Keep a no-recording demo so the UI can still be explored offline.
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
        rules = rules_by_word[i] if rules_by_word and i < len(rules_by_word) else []
        words.append(
            WordResult(
                word=token,
                status=status,
                score=score,
                tip=tip,
                issues=issues,
                rules=rules,
            )
        )

    overall = sum(w.score for w in words) / max(len(words), 1)
    return RecitationResponse(
        surah=surah,
        ayah=ayah,
        overall_score=round(overall, 4),
        words=words,
        assessment_notice=(
            "Demo only: no recording was uploaded, so these scores and issues "
            "were generated examples."
        ),
    )
