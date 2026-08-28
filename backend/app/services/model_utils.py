from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from typing import Any


def normalize_text(text: Any) -> str:
    value = unicodedata.normalize("NFKC", str(text or ""))
    value = re.sub(r"\s+", " ", value).strip().lower()
    return value


def resolve_device(requested: str) -> str:
    requested = requested.strip().lower()
    if requested in {"cpu", "cuda"}:
        if requested == "cuda":
            import torch

            if not torch.cuda.is_available():
                return "cpu"
        return requested

    import torch

    return "cuda" if torch.cuda.is_available() else "cpu"


def ensure_directory(path: Path, required_files: list[str]) -> None:
    if not path.is_dir():
        raise FileNotFoundError(f"Model component directory not found: {path}")
    missing = [name for name in required_files if not (path / name).is_file()]
    if missing:
        raise FileNotFoundError(
            f"Model component {path.name} is missing: {', '.join(missing)}"
        )


def label_for_id(config: Any, label_id: int) -> str:
    mapping = getattr(config, "id2label", {}) or {}
    return str(mapping.get(label_id, mapping.get(str(label_id), f"LABEL_{label_id}")))


def clean_label(label: str) -> str:
    return label.strip().replace("-", "_").replace(" ", "_").lower()
