from __future__ import annotations

import math
import re
import threading
from pathlib import Path
from typing import Any

from .model_utils import ensure_directory, normalize_text


DATE_PATTERN = re.compile(r"\b\d{4}-\d{2}-\d{2}\b")
NUMBER_PATTERN = re.compile(r"(?<![\d-])\d{1,3}(?:,\d{3})+|(?<![\d-])\d+(?:\.\d+)?")


def _number(value: str) -> int | float:
    cleaned = value.replace(",", "")
    parsed = float(cleaned)
    return int(parsed) if parsed.is_integer() else parsed


def _content_numbers(text: str) -> list[int | float]:
    without_dates = DATE_PATTERN.sub(" ", text)
    values: list[int | float] = []
    for match in NUMBER_PATTERN.finditer(without_dates):
        value = _number(match.group(0))
        if isinstance(value, int) and 1900 <= value <= 2100:
            continue
        values.append(value)
    return values


class NumericWerChecker:
    TEXT_COLUMNS = ["claim_text", "claim", "user_text", "text", "extracted_claim"]
    EVIDENCE_COLUMNS = [
        "reference_evidence_text",
        "reference_evidence",
        "answer",
        "evidence",
        "corrected_answer",
    ]
    COUNT_COLUMNS = [
        "official_count",
        "current_week_cases",
        "observed_sum",
        "reference_count",
        "correct_count",
        "expected_count",
    ]

    def __init__(self, component_path: Path) -> None:
        self.component_path = component_path
        self._load_lock = threading.RLock()
        self._data = None
        self._normalized_claims: list[str] = []

    @property
    def loaded(self) -> bool:
        return self._data is not None

    def load(self) -> None:
        if self.loaded:
            return
        with self._load_lock:
            if self.loaded:
                return
            ensure_directory(
                self.component_path,
                ["numeric_wer_reference_lookup.csv", "numeric_checker_metadata.json"],
            )
            import pandas as pd

            self._data = pd.read_csv(
                self.component_path / "numeric_wer_reference_lookup.csv"
            ).fillna("")
            self._normalized_claims = [
                normalize_text(self._first_value(row, self.TEXT_COLUMNS))
                for _, row in self._data.iterrows()
            ]

    @staticmethod
    def _first_value(row: Any, columns: list[str]) -> str:
        for column in columns:
            if column in row.index:
                value = str(row.get(column, "")).strip()
                if value:
                    return value
        return ""

    def _candidate_score(self, query: str, row: Any, normalized_claim: str) -> float:
        normalized_query = normalize_text(query)
        if normalized_query == normalized_claim and normalized_claim:
            return 100.0

        query_dates = set(DATE_PATTERN.findall(query))
        row_text = " ".join(str(value) for value in row.values)
        row_dates = set(DATE_PATTERN.findall(row_text))
        date_score = 8.0 * len(query_dates & row_dates)

        query_tokens = set(re.findall(r"\w+", normalized_query, flags=re.UNICODE))
        row_tokens = set(re.findall(r"\w+", normalize_text(row_text), flags=re.UNICODE))
        union = query_tokens | row_tokens
        token_score = (len(query_tokens & row_tokens) / len(union)) if union else 0.0
        return date_score + token_score

    def _official_count(self, row: Any, evidence: str) -> int | float | None:
        for column in self.COUNT_COLUMNS:
            if column in row.index:
                value = row.get(column, "")
                if value != "" and not (isinstance(value, float) and math.isnan(value)):
                    try:
                        return _number(str(value))
                    except ValueError:
                        pass

        patterns = [
            r"correct current-week count (?:is|eka)\s*([\d,]+)",
            r"current-week (?:dengue )?cases?\s*(?:is|are|eka|:)\s*([\d,]+)",
            r"observed sum(?: එක)?\s*(?:is|eka|:)\s*([\d,]+)",
            r"reports?\s*([\d,]+)\s*current-week",
            r"correct[^\d]{0,30}([\d,]+)",
        ]
        for pattern in patterns:
            match = re.search(pattern, evidence, flags=re.IGNORECASE)
            if match:
                return _number(match.group(1))
        numbers = _content_numbers(evidence)
        return numbers[-1] if numbers else None

    def check(self, text: str) -> dict[str, object]:
        self.load()
        assert self._data is not None
        if self._data.empty:
            return {"label": "Needs Review", "reason": "Official lookup is empty"}

        scored: list[tuple[float, int]] = []
        for index, (_, row) in enumerate(self._data.iterrows()):
            scored.append((self._candidate_score(text, row, self._normalized_claims[index]), index))
        scored.sort(reverse=True)
        best_score, best_index = scored[0]
        row = self._data.iloc[best_index]
        evidence = self._first_value(row, self.EVIDENCE_COLUMNS)
        source_url = str(row.get("source_url", "")).strip() or None
        exact_match = normalize_text(text) == self._normalized_claims[best_index]

        if exact_match and "truth_label" in row.index and str(row["truth_label"]).strip():
            return {
                "label": str(row["truth_label"]).strip(),
                "confidence": 1.0,
                "evidence": evidence,
                "source_url": source_url,
                "match_type": "exact_curated_claim",
            }

        claimed_numbers = _content_numbers(text)
        official_count = self._official_count(row, evidence)
        if best_score < 1.0 or official_count is None:
            return {
                "label": "Needs Review",
                "confidence": None,
                "evidence": evidence,
                "source_url": source_url,
                "match_type": "insufficient_numeric_match",
            }

        asks_for_count = bool(
            re.search(
                r"how many|what (?:is|was) (?:the )?(?:count|total)|"
                r"kiyada|kochchara|කීය|කීයක්|කොපමණ",
                text,
                flags=re.IGNORECASE,
            )
        )
        if not claimed_numbers and asks_for_count:
            return {
                "label": "Supported",
                "confidence": min(0.99, 0.70 + min(best_score, 10.0) / 40.0),
                "official_count": official_count,
                "evidence": evidence,
                "source_url": source_url,
                "match_type": "official_count_question",
            }
        if not claimed_numbers:
            return {
                "label": "Needs Review",
                "confidence": None,
                "evidence": evidence,
                "source_url": source_url,
                "match_type": "missing_claimed_count",
            }

        claimed_count = claimed_numbers[-1]
        supported = float(claimed_count) == float(official_count)
        return {
            "label": "Supported" if supported else "Misinformation",
            "confidence": min(0.99, 0.70 + min(best_score, 10.0) / 40.0),
            "claimed_count": claimed_count,
            "official_count": official_count,
            "evidence": evidence,
            "source_url": source_url,
            "match_type": "structured_lookup",
        }
