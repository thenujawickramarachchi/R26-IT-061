from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings loaded from environment variables or a local .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Sri Lankan Dengue NLP API"
    app_version: str = "1.0.0"
    environment: str = "development"
    model_root: Path = Path("./Dengue_NLP_Model")
    model_device: str = "auto"
    api_key: str | None = None
    allowed_origins: str = "*"

    max_input_characters: int = Field(default=4_000, ge=100, le=20_000)
    context_max_length: int = Field(default=256, ge=32, le=512)
    sequence_max_length: int = Field(default=256, ge=32, le=512)
    rag_max_length: int = Field(default=256, ge=32, le=512)
    rag_top_k: int = Field(default=5, ge=1, le=10)

    context_confidence_threshold: float = Field(default=0.70, ge=0, le=1)
    nli_confidence_threshold: float = Field(default=0.75, ge=0, le=1)
    rag_score_threshold: float = Field(default=0.75, ge=-1, le=1)
    severity_confidence_threshold: float = Field(default=0.70, ge=0, le=1)

    preload_context_model: bool = False

    @property
    def cors_origins(self) -> list[str]:
        if self.allowed_origins.strip() == "*":
            return ["*"]
        return [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]

    def component_path(self, component_name: str) -> Path:
        return self.model_root.expanduser().resolve() / component_name
