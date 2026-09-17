from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
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
    version="0.2.1",
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
    engine: str = ENGINE_NAME
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

    if not audio_bytes:
        raise HTTPException(
            status_code=422,
            detail="A recorded recitation is required. Demo scores are disabled.",
        )

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
