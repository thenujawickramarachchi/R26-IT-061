#!/usr/bin/env python3
"""Acceptance tests for the Sri Lankan Dengue NLP Backend API v1.1.

The API server must already be running. This script uses only Python's
standard library, so it does not install or modify the backend environment.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


JsonObject = dict[str, Any]
Validator = Callable[[JsonObject], tuple[str, str]]
VALID_RESULTS = {"PASS", "WARN", "FAIL"}


@dataclass(frozen=True)
class ApiTest:
    name: str
    method: str
    path: str
    validator: Validator
    payload: JsonObject | None = None


def pass_if(condition: bool, success: str, failure: str) -> tuple[str, str]:
    return ("PASS", success) if condition else ("FAIL", failure)


def response_has_answer_and_evidence(response: JsonObject) -> bool:
    answer = str(response.get("answer") or "").strip()
    evidence = response.get("evidence")
    return bool(answer and isinstance(evidence, list) and evidence)


def validate_root(response: JsonObject) -> tuple[str, str]:
    return pass_if(
        bool(response.get("name") and response.get("version") and response.get("docs") == "/docs"),
        f"API root is available (version {response.get('version')}).",
        "Root response is missing name, version, or /docs.",
    )


def validate_health(response: JsonObject) -> tuple[str, str]:
    components = response.get("components")
    healthy_components = (
        isinstance(components, dict)
        and bool(components)
        and all(value in {"available", "loaded"} for value in components.values())
    )
    return pass_if(
        response.get("status") == "ok"
        and response.get("model_root_exists") is True
        and healthy_components,
        "Health check passed and every model component is available.",
        f"Health check failed or a component is missing: {components!r}",
    )


def validate_clarification(response: JsonObject) -> tuple[str, str]:
    context = response.get("context") or {}
    return pass_if(
        response.get("route") == "clarification"
        and response.get("status") == "needs_clarification"
        and context.get("label") == "needs_clarification",
        "Ambiguous Sinhala text correctly asks for dengue context.",
        f"Expected clarification, got route={response.get('route')!r}, status={response.get('status')!r}.",
    )


def validate_out_of_scope(response: JsonObject) -> tuple[str, str]:
    return pass_if(
        response.get("route") == "out_of_scope"
        and response.get("status") == "out_of_scope",
        "Non-dengue text is correctly rejected as out of scope.",
        f"Expected out_of_scope, got route={response.get('route')!r}, status={response.get('status')!r}.",
    )


def validate_qa(expected_language: str) -> Validator:
    def validator(response: JsonObject) -> tuple[str, str]:
        if response.get("route") != "question_answering":
            return "FAIL", f"Expected question_answering route, got {response.get('route')!r}."
        if response.get("language") != expected_language:
            return "FAIL", f"Expected {expected_language}, got {response.get('language')!r}."
        if response.get("status") == "needs_review":
            return "WARN", "The safety gate returned Needs Review; inspect retrieval evidence."
        if not response_has_answer_and_evidence(response):
            return "FAIL", "QA response has no answer or evidence."

        evidence = response.get("evidence") or []
        first_language = evidence[0].get("language") if evidence else None
        if first_language != expected_language:
            return "WARN", f"Answer exists, but first evidence language is {first_language!r}."
        return "PASS", f"{expected_language} QA returned a same-language evidence-backed answer."

    return validator


def validate_multiturn_misinformation(response: JsonObject) -> tuple[str, str]:
    truth = response.get("truth") or {}
    details = response.get("details") or {}
    return pass_if(
        response.get("route") == "claim_verification"
        and response.get("status") == "ok"
        and response.get("language") == "Sinhala"
        and truth.get("label") == "Misinformation"
        and bool(response.get("answer"))
        and details.get("nli_passages_checked", 0) >= 1,
        "Previous context was resolved and the unsafe dengue claim was contradicted.",
        (
            "Expected an OK Sinhala Misinformation result, got "
            f"route={response.get('route')!r}, status={response.get('status')!r}, "
            f"truth={truth.get('label')!r}."
        ),
    )


def validate_numeric(expected_label: str) -> Validator:
    def validator(response: JsonObject) -> tuple[str, str]:
        truth = response.get("truth") or {}
        return pass_if(
            response.get("route") == "numeric_verification"
            and response.get("status") == "ok"
            and truth.get("label") == expected_label
            and bool(response.get("answer")),
            f"Official-number checker returned {expected_label} with evidence.",
            (
                f"Expected numeric {expected_label}, got route={response.get('route')!r}, "
                f"status={response.get('status')!r}, truth={truth.get('label')!r}."
            ),
        )

    return validator


def validate_severity(response: JsonObject) -> tuple[str, str]:
    severity = response.get("severity") or {}
    allowed = {
        "Low Concern",
        "Moderate Concern",
        "High Concern",
        "Emergency Alert",
    }
    if response.get("route") != "severity" or severity.get("label") not in allowed:
        return "FAIL", f"Severity route or label is invalid: {severity!r}"
    confidence = severity.get("confidence")
    if not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
        return "FAIL", f"Severity confidence is invalid: {confidence!r}"
    if response.get("status") == "needs_review" or severity.get("needs_review") is True:
        return "WARN", "Severity output structure passed, but the safety threshold requires review."
    return "PASS", f"Severity route returned {severity.get('label')} with a valid confidence."


TESTS = [
    ApiTest("API root", "GET", "/", validate_root),
    ApiTest("Health and model bundle", "GET", "/health", validate_health),
    ApiTest(
        "Ambiguous Sinhala clarification",
        "POST",
        "/v1/analyze",
        validate_clarification,
        {
            "text": "අවශ්‍ය නැහැ",
            "language": "Sinhala",
            "operation": "auto",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Out-of-scope routing",
        "POST",
        "/v1/analyze",
        validate_out_of_scope,
        {
            "text": "football score එක මොකක්ද?",
            "language": "Auto",
            "operation": "auto",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Sinhala question answering",
        "POST",
        "/v1/analyze",
        validate_qa("Sinhala"),
        {
            "text": "ඩෙංගු රෝගියෙකු රෝහලට වහාම යා යුත්තේ කවදාද?",
            "language": "Sinhala",
            "operation": "question_answering",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Singlish question answering",
        "POST",
        "/v1/analyze",
        validate_qa("Singlish"),
        {
            "text": "Dengue suspect patient kenekta urine adu unoth ikman hospital assessment one da?",
            "language": "Singlish",
            "operation": "question_answering",
            "top_k": 5,
        },
    ),
    ApiTest(
        "English question answering",
        "POST",
        "/v1/analyze",
        validate_qa("English"),
        {
            "text": "Does a negative NS1 test completely rule out dengue?",
            "language": "English",
            "operation": "question_answering",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Multi-turn Sinhala misinformation",
        "POST",
        "/v1/analyze",
        validate_multiturn_misinformation,
        {
            "text": "අවශ්‍ය නැහැ",
            "previous_context": "මදුරු බෝවන ස්ථාන ඉවත් කිරීම",
            "language": "Sinhala",
            "operation": "auto",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Supported official weekly count",
        "POST",
        "/v1/analyze",
        validate_numeric("Supported"),
        {
            "text": "Did Sri Lanka record 1,148 dengue cases during 2025-01-04 to 2025-01-10?",
            "language": "English",
            "operation": "numeric_verification",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Distorted official weekly count",
        "POST",
        "/v1/analyze",
        validate_numeric("Misinformation"),
        {
            "text": "Sri Lanka recorded 2,268 dengue cases during 2026-01-12 to 2026-01-18.",
            "language": "English",
            "operation": "numeric_verification",
            "top_k": 5,
        },
    ),
    ApiTest(
        "Severity output contract",
        "POST",
        "/v1/analyze",
        validate_severity,
        {
            "text": "Dengue cases are rapidly increasing in Colombo with several new mosquito breeding sites reported.",
            "language": "English",
            "operation": "severity",
            "top_k": 5,
        },
    ),
]


def api_request(
    base_url: str,
    test: ApiTest,
    api_key: str | None,
    timeout: float,
) -> JsonObject:
    url = f"{base_url.rstrip('/')}{test.path}"
    headers = {"Accept": "application/json"}
    body: bytes | None = None
    if test.payload is not None:
        headers["Content-Type"] = "application/json; charset=utf-8"
        body = json.dumps(test.payload, ensure_ascii=False).encode("utf-8")
    if api_key:
        headers["X-API-Key"] = api_key

    request = Request(url, data=body, headers=headers, method=test.method)
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw)
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {details}") from exc
    except URLError as exc:
        raise RuntimeError(f"Could not connect to {url}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"API returned invalid JSON from {url}") from exc


def run_tests(base_url: str, api_key: str | None, timeout: float) -> JsonObject:
    results: list[JsonObject] = []
    print("\nSri Lankan Dengue NLP API - Acceptance Tests v1.1")
    print(f"Server: {base_url.rstrip('/')}")
    print("The first model request can take several minutes on CPU.\n")

    for index, test in enumerate(TESTS, start=1):
        started = time.perf_counter()
        print(f"[{index:02d}/{len(TESTS):02d}] {test.name} ... ", end="", flush=True)
        response: JsonObject | None = None
        try:
            response = api_request(base_url, test, api_key, timeout)
            outcome, message = test.validator(response)
            if outcome not in VALID_RESULTS:
                outcome, message = "FAIL", f"Invalid validator outcome: {outcome!r}"
        except Exception as exc:  # Keep running to produce a complete report.
            outcome, message = "FAIL", str(exc)

        duration = round(time.perf_counter() - started, 3)
        print(f"{outcome} ({duration:.2f}s)")
        print(f"       {message}")
        results.append(
            {
                "name": test.name,
                "method": test.method,
                "path": test.path,
                "outcome": outcome,
                "message": message,
                "duration_seconds": duration,
                "request": test.payload,
                "response": response,
            }
        )

    counts = {result: sum(row["outcome"] == result for row in results) for result in sorted(VALID_RESULTS)}
    overall = "PASS" if counts["FAIL"] == 0 else "FAIL"
    report = {
        "suite": "Sri Lankan Dengue NLP API Acceptance Tests",
        "suite_version": "1.1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "base_url": base_url.rstrip("/"),
        "overall": overall,
        "summary": counts,
        "results": results,
        "notes": [
            "WARN is a safe Needs Review result or a non-critical retrieval-language mismatch.",
            "The severity test validates the API contract, not clinical label accuracy.",
        ],
    }

    print("\nSummary")
    print(f"PASS: {counts['PASS']}  WARN: {counts['WARN']}  FAIL: {counts['FAIL']}")
    print(f"OVERALL: {overall}")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--url",
        default="http://127.0.0.1:8000",
        help="API base URL (default: http://127.0.0.1:8000)",
    )
    parser.add_argument(
        "--api-key",
        default=None,
        help="Optional X-API-Key value when API_KEY is enabled in .env.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=600.0,
        help="Timeout per request in seconds (default: 600).",
    )
    parser.add_argument(
        "--output",
        default="api_acceptance_results.json",
        help="JSON report path (default: api_acceptance_results.json).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = run_tests(args.url, args.api_key, args.timeout)
    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8-sig",
    )
    print(f"Report saved: {output_path}")
    return 0 if report["overall"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
