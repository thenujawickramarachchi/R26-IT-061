from __future__ import annotations

from .model_utils import clean_label
from .sequence_classifier import LazySequenceClassifier


class ContextRouter:
    def __init__(self, classifier: LazySequenceClassifier, threshold: float) -> None:
        self.classifier = classifier
        self.threshold = threshold

    @property
    def loaded(self) -> bool:
        return self.classifier.loaded

    def predict(self, current_text: str, previous_context: str | None) -> dict[str, object]:
        model_input = (
            f"[CURRENT]\n{current_text.strip()}\n"
            f"[PREVIOUS]\n{(previous_context or '<NONE>').strip()}"
        )
        result = self.classifier.predict(model_input)
        normalized = clean_label(str(result["label"]))
        aliases = {
            "sufficient_context": "sufficient_context",
            "needs_clarification": "needs_clarification",
            "out_of_scope": "out_of_scope",
            "requires_current_data": "requires_current_data",
        }
        label = aliases.get(normalized, normalized)
        if float(result["confidence"]) < self.threshold:
            label = "needs_clarification"
        return {**result, "label": label}
