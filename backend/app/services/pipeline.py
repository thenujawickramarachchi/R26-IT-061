from __future__ import annotations

import re
import uuid
from pathlib import Path
from typing import Any

from app.config import Settings

from .context_router import ContextRouter
from .model_utils import clean_label
from .nli import ClinicalNliVerifier
from .numeric_checker import NumericWerChecker
from .rag import RagRetriever
from .sequence_classifier import LazySequenceClassifier


SAFETY_MESSAGE = (
    "Research prototype only. It does not replace professional medical advice "
    "or official public-health decisions. Urgent warning signs require prompt "
    "medical assessment."
)


class DenguePipeline:
    COMPONENTS = {
        "context": "context_classifier_v1",
        "clinical_nli": "clinical_nli_v1",
        "numeric": "numeric_wer_checker_v1",
        "rag": "qa_rag_retriever_v1",
        "severity": "severity_classifier_v2",
    }

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.context_classifier = LazySequenceClassifier(
            settings.component_path(self.COMPONENTS["context"]),
            settings.model_device,
            settings.context_max_length,
        )
        self.context_router = ContextRouter(
            self.context_classifier,
            settings.context_confidence_threshold,
        )
        self.rag = RagRetriever(
            settings.component_path(self.COMPONENTS["rag"]),
            settings.model_device,
            settings.rag_max_length,
        )
        self.nli = ClinicalNliVerifier(
            settings.component_path(self.COMPONENTS["clinical_nli"]),
            settings.model_device,
            settings.sequence_max_length,
            settings.nli_confidence_threshold,
        )
        self.severity_classifier = LazySequenceClassifier(
            settings.component_path(self.COMPONENTS["severity"]),
            settings.model_device,
            settings.sequence_max_length,
        )
        self.numeric = NumericWerChecker(
            settings.component_path(self.COMPONENTS["numeric"])
        )
        if settings.preload_context_model:
            self.context_classifier.load()

    def status(self) -> dict[str, str]:
        paths = {
            name: self.settings.component_path(component)
            for name, component in self.COMPONENTS.items()
        }
        loaded = {
            "context": self.context_classifier.loaded,
            "clinical_nli": self.nli.loaded,
            "numeric": self.numeric.loaded,
            "rag": self.rag.loaded,
            "severity": self.severity_classifier.loaded,
        }
        return {
            name: (
                "missing"
                if not path.is_dir()
                else "loaded"
                if loaded[name]
                else "available"
            )
            for name, path in paths.items()
        }

    @staticmethod
    def detect_language(text: str, requested: str) -> str:
        if requested != "Auto":
            return requested
        if re.search(r"[\u0D80-\u0DFF]", text):
            return "Sinhala"
        singlish_markers = {
            "eka", "ekak", "hari", "waradi", "nam", "nadda", "da",
            "kiyada", "wenawa", "karanna", "puluwanda", "dengue",
        }
        words = set(re.findall(r"[a-z]+", text.lower()))
        return "Singlish" if len(words & singlish_markers) >= 2 else "English"

    @staticmethod
    def _message(kind: str, language: str) -> str:
        messages = {
            "clarify": {
                "Sinhala": "කරුණාකර ඩෙංගු සම්බන්ධ සම්පූර්ණ ප්‍රශ්නය හෝ ප්‍රකාශය ලබා දෙන්න.",
                "Singlish": "Dengue sambandha complete prashnaya ho claim eka denna.",
                "English": "Please provide the complete dengue question or claim.",
            },
            "out_of_scope": {
                "Sinhala": "මෙම යෙදුම ඩෙංගු සම්බන්ධ ප්‍රශ්න පමණක් සකසයි.",
                "Singlish": "Me application eka dengue sambandha prashna witharai handle karanne.",
                "English": "This application handles dengue-related questions only.",
            },
            "review": {
                "Sinhala": "විශ්වාසදායක පිළිතුරක් සඳහා නිල මූලාශ්‍රයක් හෝ මානව සමාලෝචනයක් අවශ්‍යයි.",
                "Singlish": "Reliable answer ekakata official source ho human review ekak one.",
                "English": "An official source or human review is required for a reliable answer.",
            },
        }
        return messages[kind].get(language, messages[kind]["English"])

    @staticmethod
    def _looks_numeric(text: str) -> bool:
        return bool(
            re.search(r"\d", text)
            and re.search(
                r"case|count|total|sum|week|report|වාර්තා|රෝගී|එකතුව|ganana|kiyada",
                text,
                flags=re.IGNORECASE,
            )
        )

    @staticmethod
    def _looks_question(text: str) -> bool:
        return bool(
            "?" in text
            or re.search(
                r"^(what|when|where|why|how|is|are|can|should|does|did|do)\b",
                text.strip(),
                flags=re.IGNORECASE,
            )
            or re.search(r"(ද|ද\?|කුමක්|කවදා|කොහොම|ඇයි|කි(?:ය|ී)ද|puluwanda|harida|da\??)$", text.strip(), flags=re.IGNORECASE)
        )

    @staticmethod
    def _looks_severity_report(text: str) -> bool:
        return bool(
            re.search(
                r"outbreak|surveillance|admissions|hospital pressure|emergency declared|"
                r"rapid(?:ly)? increasing|cases? (?:rose|increased|fell)|"
                r"epidemic threshold|weekly report|high.risk (?:area|moh)|"
                r"රෝගීන්.*(?:ඉහළ|වැඩි|අඩු)|හදිසි තත්ත්ව|වාර්තාව",
                text,
                flags=re.IGNORECASE,
            )
        )

    def _base_response(self, request_id: str, route: str, language: str) -> dict[str, Any]:
        return {
            "request_id": request_id,
            "route": route,
            "status": "ok",
            "language": language,
            "context": None,
            "answer": None,
            "truth": None,
            "severity": None,
            "evidence": [],
            "details": {},
            "safety_message": SAFETY_MESSAGE,
        }

    def analyze(
        self,
        text: str,
        previous_context: str | None,
        language: str,
        operation: str,
        top_k: int | None,
    ) -> dict[str, Any]:
        request_id = str(uuid.uuid4())
        resolved_text = (
            f"{previous_context.strip()} {text.strip()}"
            if previous_context and previous_context.strip()
            else text
        )
        language = self.detect_language(resolved_text, language)
        top_k = top_k or self.settings.rag_top_k
        response = self._base_response(request_id, operation, language)

        context = self.context_router.predict(text, previous_context)
        response["context"] = {
            "label": str(context["label"]),
            "confidence": float(context["confidence"]),
        }

        if operation == "context":
            response["route"] = "context"
            return response

        context_label = str(context["label"])
        if operation == "auto" and context_label == "needs_clarification":
            response.update(
                route="clarification",
                status="needs_clarification",
                answer=self._message("clarify", language),
            )
            return response
        if operation == "auto" and context_label == "out_of_scope":
            response.update(
                route="out_of_scope",
                status="out_of_scope",
                answer=self._message("out_of_scope", language),
            )
            return response

        if operation == "numeric_verification" or (
            operation == "auto"
            and (context_label == "requires_current_data" or self._looks_numeric(resolved_text))
        ):
            result = self.numeric.check(resolved_text)
            response["route"] = "numeric_verification"
            response["truth"] = {
                "label": str(result.get("label", "Needs Review")),
                "confidence": result.get("confidence"),
                "raw_nli_label": None,
            }
            response["answer"] = str(result.get("evidence") or self._message("review", language))
            if result.get("source_url"):
                response["evidence"] = [
                    {
                        "passage_id": None,
                        "text": str(result.get("evidence", "")),
                        "source_url": str(result["source_url"]),
                        "language": None,
                        "score": result.get("confidence"),
                    }
                ]
            response["details"] = {
                key: value
                for key, value in result.items()
                if key not in {"label", "confidence", "evidence", "source_url"}
            }
            if result.get("label") == "Needs Review":
                response["status"] = "needs_review"
            return response

        if operation == "severity" or (
            operation == "auto" and self._looks_severity_report(resolved_text)
        ):
            result = self.severity_classifier.predict(resolved_text)
            label = str(result["label"]).replace("_", " ").title()
            confidence = float(result["confidence"])
            needs_review = confidence < self.settings.severity_confidence_threshold
            response["route"] = "severity"
            response["severity"] = {
                "label": label,
                "confidence": confidence,
                "final_decision": "Needs Review" if needs_review else label,
                "needs_review": needs_review,
            }
            if needs_review:
                response["status"] = "needs_review"
                response["answer"] = self._message("review", language)
            return response

        passages = self.rag.retrieve(resolved_text, top_k, language)
        response["evidence"] = passages
        best = passages[0] if passages else None
        retrieval_is_safe = bool(
            best and float(best["score"]) >= self.settings.rag_score_threshold
        )

        is_question = self._looks_question(resolved_text)
        if operation == "question_answering" or (operation == "auto" and is_question):
            response["route"] = "question_answering"
            if retrieval_is_safe:
                response["answer"] = str(best["text"])
            else:
                response["status"] = "needs_review"
                response["answer"] = self._message("review", language)
            return response

        response["route"] = "claim_verification"
        if not retrieval_is_safe:
            response["status"] = "needs_review"
            response["answer"] = self._message("review", language)
            response["truth"] = {
                "label": "Needs Review",
                "confidence": None,
                "raw_nli_label": None,
            }
            return response

        selected_passage = best
        selected_truth = None
        fallback_truth = None
        selected_rank = 1

        # A relevant passage may describe the topic without explicitly proving
        # or contradicting the claim. Check the top three intent-aware passages
        # and use the first decisive NLI result; otherwise keep Needs Review.
        for rank, passage in enumerate(passages[:3], start=1):
            candidate_truth = self.nli.verify(
                resolved_text,
                str(passage["text"]),
            )
            if fallback_truth is None:
                fallback_truth = candidate_truth
            if candidate_truth["label"] != "Needs Review":
                selected_passage = passage
                selected_truth = candidate_truth
                selected_rank = rank
                break

        truth = selected_truth or fallback_truth
        assert truth is not None
        response["truth"] = truth
        response["answer"] = str(selected_passage["text"])
        response["details"] = {
            "nli_evidence_rank": selected_rank,
            "nli_evidence_passage_id": selected_passage.get("passage_id"),
            "nli_passages_checked": min(3, len(passages)),
        }

        selected_id = selected_passage.get("passage_id")
        if selected_rank > 1:
            response["evidence"] = [selected_passage] + [
                passage
                for passage in passages
                if passage.get("passage_id") != selected_id
            ]

        if truth["label"] == "Needs Review":
            response["status"] = "needs_review"
        return response

    def close(self) -> None:
        self.context_classifier.close()
        self.rag.close()
        self.nli.close()
        self.severity_classifier.close()



