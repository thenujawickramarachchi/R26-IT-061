def check_misinformation(claim: str):
    text = claim.lower()

    misinformation_rules = [
        ("papaya leaf cure", "Papaya leaf is not a confirmed instant cure for dengue."),
        ("papaya leaf can cure", "Papaya leaf is not a confirmed cure for dengue."),
        ("instant cure", "Dengue has no instant cure. Medical monitoring is important."),
        ("no need doctor", "Dengue can become severe; medical advice is recommended."),
        ("antibiotics cure dengue", "Antibiotics do not cure dengue because dengue is viral."),
        ("aspirin dengue", "Aspirin can increase bleeding risk in dengue and should not be used without medical advice."),
        ("ibuprofen dengue", "Ibuprofen can increase bleeding risk in dengue and should not be used without medical advice."),
    ]

    for keyword, explanation in misinformation_rules:
        if keyword in text:
            return {
                "status": "Misinformation",
                "confidence": 0.90,
                "explanation": explanation,
                "recommendation": "Verify dengue information using official health sources and seek medical advice."
            }

    unverified_words = ["cure", "medicine", "treatment", "home remedy", "viral post"]
    if any(word in text for word in unverified_words):
        return {
            "status": "Unverified",
            "confidence": 0.65,
            "explanation": "This health claim needs verification from trusted medical sources.",
            "recommendation": "Do not follow medical claims without checking official health guidance."
        }

    return {
        "status": "Reliable or General",
        "confidence": 0.72,
        "explanation": "No strong misinformation pattern was detected.",
        "recommendation": "Use official health guidance for final decisions."
    }
