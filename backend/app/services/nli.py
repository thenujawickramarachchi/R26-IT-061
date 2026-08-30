from __future__ import annotations

import threading
import json
from pathlib import Path

from .model_utils import clean_label, ensure_directory, label_for_id, resolve_device


class ClinicalNliVerifier:
    def __init__(self, model_path: Path, device: str, max_length: int, threshold: float) -> None:
        self.model_path = model_path
        self.requested_device = device
        self.max_length = max_length
        self.threshold = threshold
        self._load_lock = threading.RLock()
        self._inference_lock = threading.RLock()
        self._tokenizer = None
        self._model = None
        self._torch = None
        self._id2label: dict[int, str] = {}
        self.device: str | None = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        if self.loaded:
            return
        with self._load_lock:
            if self.loaded:
                return
            ensure_directory(
                self.model_path,
                ["config.json", "model.safetensors", "tokenizer.json"],
            )
            import torch
            from transformers import AutoModelForSequenceClassification, AutoTokenizer

            self.device = resolve_device(self.requested_device)
            self._torch = torch
            self._tokenizer = AutoTokenizer.from_pretrained(
                self.model_path,
                local_files_only=True,
            )
            self._model = AutoModelForSequenceClassification.from_pretrained(
                self.model_path,
                local_files_only=True,
            )
            self._model.to(self.device)
            self._model.eval()
            configured_labels = getattr(self._model.config, "id2label", {}) or {}
            self._id2label = {
                int(key): str(value)
                for key, value in configured_labels.items()
            }
            metadata_path = self.model_path / "clinical_nli_metadata.json"
            if metadata_path.is_file():
                metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
                metadata_labels = (
                    metadata.get("id2label")
                    or metadata.get("labels")
                    or metadata.get("label_mapping")
                )
                if isinstance(metadata_labels, dict):
                    self._id2label = {
                        int(key): str(value)
                        for key, value in metadata_labels.items()
                    }

            if not self._id2label or all(
                clean_label(value).startswith("label_")
                for value in self._id2label.values()
            ):
                self._id2label = {
                    0: "entailment",
                    1: "neutral",
                    2: "contradiction",
                }

    def verify(self, claim: str, evidence: str) -> dict[str, object]:
        self.load()
        assert self._tokenizer is not None
        assert self._model is not None
        assert self._torch is not None
        assert self.device is not None

        with self._inference_lock, self._torch.inference_mode():
            batch = self._tokenizer(
                evidence,
                claim,
                truncation=True,
                max_length=self.max_length,
                return_tensors="pt",
            )
            batch = {key: value.to(self.device) for key, value in batch.items()}
            probabilities = self._torch.softmax(self._model(**batch).logits[0], dim=-1)
            label_id = int(self._torch.argmax(probabilities).item())
            confidence = float(probabilities[label_id].item())
            raw_label = self._id2label.get(
                label_id,
                label_for_id(self._model.config, label_id),
            )

        normalized = clean_label(raw_label)
        if confidence < self.threshold or "neutral" in normalized:
            decision = "Needs Review"
        elif "entail" in normalized or "support" in normalized:
            decision = "Supported"
        elif "contrad" in normalized or "misinformation" in normalized:
            decision = "Misinformation"
        else:
            decision = "Needs Review"

        return {
            "label": decision,
            "confidence": confidence,
            "raw_nli_label": raw_label,
        }

    def close(self) -> None:
        self._model = None
        self._tokenizer = None
        if self._torch is not None and self._torch.cuda.is_available():
            self._torch.cuda.empty_cache()
