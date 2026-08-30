from __future__ import annotations

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


class FakePipeline:
    def __init__(self, _settings: Settings) -> None:
        self.closed = False

    def status(self) -> dict[str, str]:
        return {
            "context": "available",
            "clinical_nli": "available",
            "numeric": "available",
            "rag": "available",
            "severity": "available",
        }

    def analyze(self, text, previous_context, language, operation, top_k):
        return {
            "request_id": "test-request",
            "route": "clarification",
            "status": "needs_clarification",
            "language": "Sinhala",
            "context": {"label": "needs_clarification", "confidence": 0.99},
            "answer": "කරුණාකර සම්පූර්ණ ප්‍රශ්නය ලබා දෙන්න.",
            "truth": None,
            "severity": None,
            "evidence": [],
            "details": {},
            "safety_message": "Research prototype only.",
        }

    def close(self) -> None:
        self.closed = True


def build_client(tmp_path, api_key=None) -> TestClient:
    settings = Settings(
        model_root=tmp_path,
        api_key=api_key,
        _env_file=None,
    )
    return TestClient(create_app(settings, pipeline_factory=FakePipeline))


def test_health_does_not_require_models(tmp_path):
    with build_client(tmp_path) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["components"]["context"] == "available"


def test_analyze_returns_structured_response(tmp_path):
    with build_client(tmp_path) as client:
        response = client.post(
            "/v1/analyze",
            json={"text": "අවශ්‍ය නැහැ", "language": "Sinhala"},
        )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "needs_clarification"
    assert body["context"]["label"] == "needs_clarification"


def test_blank_input_is_rejected(tmp_path):
    with build_client(tmp_path) as client:
        response = client.post("/v1/analyze", json={"text": "   "})
    assert response.status_code == 422


def test_optional_api_key(tmp_path):
    with build_client(tmp_path, api_key="secret") as client:
        missing = client.post("/v1/analyze", json={"text": "dengue"})
        accepted = client.post(
            "/v1/analyze",
            json={"text": "dengue"},
            headers={"X-API-Key": "secret"},
        )
    assert missing.status_code == 401
    assert accepted.status_code == 200
