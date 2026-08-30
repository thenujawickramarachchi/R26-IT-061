from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from safetensors import safe_open

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import Settings  # noqa: E402


REQUIRED = {
    "context_classifier_v1": ["config.json", "model.safetensors", "tokenizer.json"],
    "clinical_nli_v1": ["config.json", "model.safetensors", "tokenizer.json"],
    "numeric_wer_checker_v1": [
        "numeric_checker_metadata.json",
        "numeric_wer_reference_lookup.csv",
    ],
    "qa_rag_retriever_v1": [
        "config.json",
        "model.safetensors",
        "tokenizer.json",
        "qa_corpus_embeddings.npy",
        "qa_knowledge_corpus.csv",
    ],
    "severity_classifier_v2": ["config.json", "model.safetensors", "tokenizer.json"],
}


def main() -> int:
    settings = Settings()
    root = settings.model_root.expanduser().resolve()
    print(f"Model root: {root}")
    failures: list[str] = []

    for component, names in REQUIRED.items():
        path = root / component
        if not path.is_dir():
            failures.append(f"Missing folder: {path}")
            continue
        for name in names:
            if not (path / name).is_file():
                failures.append(f"Missing file: {path / name}")

        config_path = path / "config.json"
        if config_path.is_file():
            try:
                json.loads(config_path.read_text(encoding="utf-8"))
            except Exception as error:  # noqa: BLE001
                failures.append(f"Invalid config {config_path}: {error}")

        weights_path = path / "model.safetensors"
        if weights_path.is_file():
            try:
                with safe_open(weights_path, framework="pt", device="cpu") as handle:
                    if not list(handle.keys()):
                        failures.append(f"No tensors in {weights_path}")
            except Exception as error:  # noqa: BLE001
                failures.append(f"Invalid weights {weights_path}: {error}")

    rag_path = root / "qa_rag_retriever_v1"
    if rag_path.is_dir():
        try:
            embeddings = np.load(rag_path / "qa_corpus_embeddings.npy", mmap_mode="r")
            corpus = pd.read_csv(rag_path / "qa_knowledge_corpus.csv")
            if embeddings.shape[0] != len(corpus):
                failures.append("RAG corpus and embeddings have different row counts")
            else:
                print(f"RAG: {len(corpus)} passages, embedding shape {embeddings.shape}")
        except Exception as error:  # noqa: BLE001
            failures.append(f"RAG verification failed: {error}")

    numeric_path = root / "numeric_wer_checker_v1" / "numeric_wer_reference_lookup.csv"
    if numeric_path.is_file():
        try:
            print(f"Numeric lookup: {len(pd.read_csv(numeric_path))} rows")
        except Exception as error:  # noqa: BLE001
            failures.append(f"Numeric lookup failed: {error}")

    if failures:
        print("\nMODEL BUNDLE CHECK FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("\nMODEL BUNDLE CHECK PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
