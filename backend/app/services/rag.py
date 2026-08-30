from __future__ import annotations

import threading
from pathlib import Path

from .model_utils import ensure_directory, resolve_device


class RagRetriever:
    def __init__(self, model_path: Path, device: str, max_length: int) -> None:
        self.model_path = model_path
        self.requested_device = device
        self.max_length = max_length
        self._load_lock = threading.RLock()
        self._inference_lock = threading.RLock()
        self._model = None
        self._tokenizer = None
        self._corpus = None
        self._embeddings = None
        self._torch = None
        self._np = None
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
                [
                    "config.json",
                    "model.safetensors",
                    "tokenizer.json",
                    "qa_corpus_embeddings.npy",
                    "qa_knowledge_corpus.csv",
                ],
            )
            import numpy as np
            import pandas as pd
            import torch
            import torch.nn.functional as functional
            from transformers import AutoModel, AutoTokenizer

            self.device = resolve_device(self.requested_device)
            self._np = np
            self._torch = torch
            self._functional = functional
            self._tokenizer = AutoTokenizer.from_pretrained(
                self.model_path,
                local_files_only=True,
            )
            self._model = AutoModel.from_pretrained(
                self.model_path,
                local_files_only=True,
            )
            self._model.to(self.device)
            self._model.eval()
            self._embeddings = np.load(
                self.model_path / "qa_corpus_embeddings.npy",
            ).astype("float32")
            self._corpus = pd.read_csv(
                self.model_path / "qa_knowledge_corpus.csv",
            ).fillna("")
            if len(self._corpus) != self._embeddings.shape[0]:
                raise ValueError("RAG corpus and embedding row counts do not match")

    def _average_pool(self, hidden_states, attention_mask):
        masked = hidden_states.masked_fill(
            ~attention_mask[..., None].bool(),
            0.0,
        )
        return masked.sum(dim=1) / attention_mask.sum(dim=1)[..., None]

    def retrieve(
        self,
        query: str,
        top_k: int,
        preferred_language: str | None = None,
    ) -> list[dict[str, object]]:
        self.load()
        assert self._model is not None
        assert self._tokenizer is not None
        assert self._embeddings is not None
        assert self._corpus is not None
        assert self._torch is not None
        assert self._np is not None
        assert self.device is not None

        top_k = min(max(top_k, 1), len(self._corpus))
        with self._inference_lock, self._torch.inference_mode():
            batch = self._tokenizer(
                f"query: {query.strip()}",
                truncation=True,
                max_length=self.max_length,
                return_tensors="pt",
            )
            batch = {key: value.to(self.device) for key, value in batch.items()}
            output = self._model(**batch)
            embedding = self._average_pool(
                output.last_hidden_state,
                batch["attention_mask"],
            )
            embedding = self._functional.normalize(embedding, p=2, dim=1)
            query_vector = embedding[0].detach().cpu().numpy().astype("float32")

        scores = self._embeddings @ query_vector
        ordered_indices = self._np.argsort(-scores)
        indices = ordered_indices[:top_k]

        if (
            preferred_language
            and "language" in self._corpus.columns
            and "intent_label" in self._corpus.columns
        ):
            corpus_languages = (
                self._corpus["language"].astype(str).str.casefold().to_numpy()
            )
            intent_labels = (
                self._corpus["intent_label"].astype(str).str.casefold().to_numpy()
            )
            preferred_key = preferred_language.casefold()
            selected_indices: list[int] = []

            # Use cross-language semantic ranking to identify the intent, then
            # select the strongest passage for that intent in the requested language.
            for global_index in ordered_indices:
                global_index = int(global_index)
                intent_key = intent_labels[global_index]
                matching_indices = self._np.flatnonzero(
                    (corpus_languages == preferred_key)
                    & (intent_labels == intent_key)
                )
                if not len(matching_indices):
                    continue
                best_match = int(
                    matching_indices[self._np.argmax(scores[matching_indices])]
                )
                if best_match not in selected_indices:
                    selected_indices.append(best_match)
                if len(selected_indices) >= top_k:
                    break

            # Fill any remaining evidence slots with the best passages in the
            # requested language, while keeping the intent-matched result first.
            if len(selected_indices) < top_k:
                for global_index in ordered_indices:
                    global_index = int(global_index)
                    if (
                        corpus_languages[global_index] == preferred_key
                        and global_index not in selected_indices
                    ):
                        selected_indices.append(global_index)
                    if len(selected_indices) >= top_k:
                        break

            if selected_indices:
                indices = self._np.asarray(selected_indices[:top_k], dtype=int)
        results: list[dict[str, object]] = []
        for index in indices:
            row = self._corpus.iloc[int(index)]
            results.append(
                {
                    "passage_id": str(row.get("passage_id", f"PASSAGE_{index}")) or None,
                    "text": str(row.get("answer", row.get("text", ""))),
                    "source_url": str(row.get("source_url", "")) or None,
                    "language": str(row.get("language", "")) or None,
                    "score": float(scores[int(index)]),
                }
            )
        return results

    def close(self) -> None:
        self._model = None
        self._tokenizer = None
        self._corpus = None
        self._embeddings = None
        if self._torch is not None and self._torch.cuda.is_available():
            self._torch.cuda.empty_cache()


