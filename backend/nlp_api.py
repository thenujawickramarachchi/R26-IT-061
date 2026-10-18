"""NLP routes backed by the local Dengue_NLP_Model artifact bundle.

Models are loaded on the first analysis request rather than at API startup.  This
keeps the existing prediction API usable on machines that only need the RF model.
"""
from __future__ import annotations

import json
import os
import re
import uuid
from functools import lru_cache
from typing import Any

import numpy as np
import pandas as pd
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field


router = APIRouter(prefix="/v1", tags=["Dengue NLP"])
MODEL_ROOT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "Dengue_NLP_Model",
    "Dengue_NLP_Model",
)
SAFETY_MESSAGE = (
    "Research prototype only. This result does not replace professional medical "
    "advice or official public-health decisions. Seek urgent medical assessment "
    "for warning signs or severe symptoms."
)


class AnalyzeRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    previous_context: str | None = Field(default=None, max_length=5000)


def _language(text: str) -> str:
    if re.search(r"[\u0D80-\u0DFF]", text):
        return "Sinhala"
    # Singlish is Latin-script Sinhala and cannot be determined perfectly without
    # a dedicated detector. The trained multilingual models receive the raw text.
    return "English"


def _softmax(values: Any) -> np.ndarray:
    values = np.asarray(values, dtype=float)
    shifted = values - values.max()
    probabilities = np.exp(shifted)
    return probabilities / probabilities.sum()


@lru_cache(maxsize=1)
def _service() -> "DengueNlpService":
    try:
        return DengueNlpService(MODEL_ROOT)
    except ImportError as error:
        raise HTTPException(
            status_code=503,
            detail=(
                "NLP dependencies are not installed. Run `pip install -r "
                f"requirements.txt` in the backend folder. ({error})"
            ),
        ) from error
    except (FileNotFoundError, OSError, ValueError) as error:
        raise HTTPException(status_code=503, detail=f"NLP model bundle could not be loaded: {error}") from error


class DengueNlpService:
    """Executes the bundle's trained classifiers and local RAG retriever."""

    def __init__(self, root: str) -> None:
        import torch
        from transformers import AutoModel, AutoModelForSequenceClassification, AutoTokenizer

        self.torch = torch
        self.root = root
        self.context_tokenizer = AutoTokenizer.from_pretrained(
            os.path.join(root, "context_classifier_v1"), local_files_only=True
        )
        self.context_model = AutoModelForSequenceClassification.from_pretrained(
            os.path.join(root, "context_classifier_v1"), local_files_only=True
        ).eval()
        self.severity_tokenizer = AutoTokenizer.from_pretrained(
            os.path.join(root, "severity_classifier_v2"), local_files_only=True
        )
        self.severity_model = AutoModelForSequenceClassification.from_pretrained(
            os.path.join(root, "severity_classifier_v2"), local_files_only=True
        ).eval()
        self.retriever_tokenizer = AutoTokenizer.from_pretrained(
            os.path.join(root, "qa_rag_retriever_v1"), local_files_only=True
        )
        self.retriever_model = AutoModel.from_pretrained(
            os.path.join(root, "qa_rag_retriever_v1"), local_files_only=True
        ).eval()
        self.nli_tokenizer = AutoTokenizer.from_pretrained(
            os.path.join(root, "clinical_nli_v1"), local_files_only=True
        )
        self.nli_model = AutoModelForSequenceClassification.from_pretrained(
            os.path.join(root, "clinical_nli_v1"), local_files_only=True
        ).eval()
        self.corpus = pd.read_csv(os.path.join(root, "qa_rag_retriever_v1", "qa_knowledge_corpus.csv"))
        self.corpus_embeddings = np.load(
            os.path.join(root, "qa_rag_retriever_v1", "qa_corpus_embeddings.npy")
        ).astype(np.float32)

    def _classify(self, tokenizer: Any, model: Any, text: str, text_pair: str | None = None) -> tuple[str, float]:
        encoded = tokenizer(text, text_pair, truncation=True, max_length=512, return_tensors="pt")
        with self.torch.no_grad():
            logits = model(**encoded).logits[0].detach().cpu().numpy()
        probabilities = _softmax(logits)
        index = int(probabilities.argmax())
        return str(model.config.id2label[index]), float(probabilities[index])

    def _embed_query(self, text: str) -> np.ndarray:
        encoded = self.retriever_tokenizer(
            f"query: {text}", truncation=True, max_length=512, return_tensors="pt"
        )
        with self.torch.no_grad():
            hidden = self.retriever_model(**encoded).last_hidden_state
        mask = encoded["attention_mask"].unsqueeze(-1).expand(hidden.size()).float()
        embedding = (hidden * mask).sum(1) / mask.sum(1).clamp(min=1e-9)
        vector = embedding[0].detach().cpu().numpy().astype(np.float32)
        return vector / max(float(np.linalg.norm(vector)), 1e-12)

    def analyze(self, text: str, previous_context: str | None) -> dict[str, Any]:
        combined_text = f"{previous_context.strip()}\n{text}" if previous_context else text
        context_label, context_confidence = self._classify(
            self.context_tokenizer, self.context_model, combined_text
        )
        severity_label, severity_confidence = self._classify(
            self.severity_tokenizer, self.severity_model, combined_text
        )
        if severity_confidence < 0.70:
            severity_label = "Needs Review"

        query_embedding = self._embed_query(combined_text)
        # The bundle contains normalised E5 corpus vectors, so dot product is
        # cosine similarity. It is deliberately a closed-corpus retrieval.
        scores = self.corpus_embeddings @ query_embedding
        indices = np.argsort(scores)[-5:][::-1]
        evidence = []
        for index in indices:
            row = self.corpus.iloc[int(index)]
            evidence.append({
                "text": str(row["answer"]),
                "source_url": str(row["source_url"]),
                "score": round(float(scores[index]), 4),
            })

        truth_label, truth_confidence = self._classify(
            self.nli_tokenizer, self.nli_model, evidence[0]["text"], text
        )
        truth_map = {
            "entailment": "Supported",
            "neutral": "Needs Review",
            "contradiction": "Misinformation",
        }
        truth_label = truth_map.get(truth_label.lower(), "Needs Review")
        if truth_confidence < 0.75:
            truth_label = "Needs Review"

        status = "ok"
        route = "qa_rag"
        if context_confidence < 0.70 or context_label == "needs_clarification":
            status, route = "needs_review", "clarification"
        elif context_label == "out_of_scope":
            status, route = "out_of_scope", "context_classifier"
        elif context_label == "requires_current_data":
            status, route = "needs_review", "current_data_check"
        elif truth_label == "Needs Review":
            status = "needs_review"

        return {
            "request_id": str(uuid.uuid4()),
            "status": status,
            "route": route,
            "language": _language(combined_text),
            "context": {"label": context_label, "confidence": round(context_confidence, 4)},
            "truth": {"label": truth_label, "confidence": round(truth_confidence, 4)},
            "severity": {"label": severity_label, "confidence": round(severity_confidence, 4)},
            "answer": evidence[0]["text"],
            "evidence": evidence,
            "safety_message": SAFETY_MESSAGE,
        }


@router.post("/analyze")
def analyze(request: AnalyzeRequest) -> dict[str, Any]:
    """Analyze Sinhala, Singlish, or English dengue text with the local bundle."""
    return _service().analyze(request.text.strip(), request.previous_context)
