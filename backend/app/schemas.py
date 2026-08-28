from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


Operation = Literal[
    "auto",
    "context",
    "question_answering",
    "claim_verification",
    "numeric_verification",
    "severity",
]


class AnalyzeRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    text: str = Field(min_length=1, max_length=4_000)
    previous_context: str | None = Field(default=None, max_length=4_000)
    language: Literal["Sinhala", "Singlish", "English", "Auto"] = "Auto"
    operation: Operation = "auto"
    top_k: int | None = Field(default=None, ge=1, le=10)

    @field_validator("text")
    @classmethod
    def reject_blank_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("text cannot be blank")
        return value


class ContextResult(BaseModel):
    label: str
    confidence: float = Field(ge=0, le=1)


class EvidenceItem(BaseModel):
    passage_id: str | None = None
    text: str
    source_url: str | None = None
    language: str | None = None
    score: float | None = None


class TruthResult(BaseModel):
    label: str
    confidence: float | None = Field(default=None, ge=0, le=1)
    raw_nli_label: str | None = None


class SeverityResult(BaseModel):
    label: str
    confidence: float = Field(ge=0, le=1)
    final_decision: str
    needs_review: bool


class AnalyzeResponse(BaseModel):
    request_id: str
    route: str
    status: str
    language: str
    context: ContextResult | None = None
    answer: str | None = None
    truth: TruthResult | None = None
    severity: SeverityResult | None = None
    evidence: list[EvidenceItem] = Field(default_factory=list)
    details: dict[str, Any] = Field(default_factory=dict)
    safety_message: str


class HealthResponse(BaseModel):
    status: str
    version: str
    model_root_exists: bool
    components: dict[str, str]
