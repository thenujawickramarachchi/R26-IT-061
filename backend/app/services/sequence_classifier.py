from __future__ import annotations

import threading
from pathlib import Path

from .model_utils import ensure_directory, label_for_id, resolve_device


class LazySequenceClassifier:
    def __init__(
        self,
        model_path: Path,
        device: str,
        max_length: int,
    ) -> None:
        self.model_path = model_path
        self.requested_device = device
        self.max_length = max_length
        self._load_lock = threading.RLock()
        self._inference_lock = threading.RLock()
        self._tokenizer = None
        self._model = None
        self._torch = None
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

    def predict(self, text: str) -> dict[str, object]:
        self.load()
        assert self._model is not None
        assert self._tokenizer is not None
        assert self._torch is not None
        assert self.device is not None

        with self._inference_lock, self._torch.inference_mode():
            batch = self._tokenizer(
                text,
                truncation=True,
                max_length=self.max_length,
                return_tensors="pt",
            )
            batch = {key: value.to(self.device) for key, value in batch.items()}
            logits = self._model(**batch).logits[0]
            probabilities = self._torch.softmax(logits, dim=-1)
            label_id = int(self._torch.argmax(probabilities).item())
            confidence = float(probabilities[label_id].item())

        return {
            "label": label_for_id(self._model.config, label_id),
            "label_id": label_id,
            "confidence": confidence,
            "probabilities": [float(value) for value in probabilities.cpu().tolist()],
        }

    def close(self) -> None:
        self._model = None
        self._tokenizer = None
        if self._torch is not None and self._torch.cuda.is_available():
            self._torch.cuda.empty_cache()
