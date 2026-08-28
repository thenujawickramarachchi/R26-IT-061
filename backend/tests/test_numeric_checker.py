from __future__ import annotations

import json

import pandas as pd

from app.services.numeric_checker import NumericWerChecker, _content_numbers


def test_content_numbers_ignore_dates_and_years():
    text = "2022-09-10 to 2022-09-16 kalaye dengue cases 53k report una."
    assert _content_numbers(text) == [53]


def test_exact_curated_claim(tmp_path):
    component = tmp_path / "numeric_wer_checker_v1"
    component.mkdir()
    (component / "numeric_checker_metadata.json").write_text(
        json.dumps({"version": 1}),
        encoding="utf-8",
    )
    pd.DataFrame(
        [
            {
                "claim_text": "Sri Lanka recorded 53 dengue cases during 2022-09-10 to 2022-09-16.",
                "truth_label": "Supported",
                "reference_evidence_text": "The correct current-week count is 53.",
                "source_url": "https://example.test/report",
            }
        ]
    ).to_csv(component / "numeric_wer_reference_lookup.csv", index=False)

    checker = NumericWerChecker(component)
    result = checker.check(
        "Sri Lanka recorded 53 dengue cases during 2022-09-10 to 2022-09-16."
    )
    assert result["label"] == "Supported"
    assert result["match_type"] == "exact_curated_claim"
