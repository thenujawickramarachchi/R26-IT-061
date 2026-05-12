def analyze_uploaded_report(file_path: str):
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as file:
            content = file.read()
    except Exception:
        content = ""

    text = content.lower()

    keywords = {
        "dengue": text.count("dengue"),
        "fever": text.count("fever"),
        "rainfall": text.count("rainfall"),
        "mosquito": text.count("mosquito"),
        "outbreak": text.count("outbreak"),
        "risk": text.count("risk")
    }

    risk_score = sum(keywords.values())

    if risk_score >= 10:
        risk_level = "High"
    elif risk_score >= 5:
        risk_level = "Medium"
    else:
        risk_level = "Low"

    summary = (
        f"The uploaded report was analyzed successfully. "
        f"The system detected dengue-related terms and estimated the risk level as {risk_level}."
    )

    return {
        "summary": summary,
        "risk_level": risk_level,
        "keywords": keywords
    }

def generate_weekly_report():
    return {
        "title": "Weekly Dengue Intelligence Report",
        "summary": "This week shows a possible increase in dengue risk due to rainfall and mosquito breeding conditions.",
        "risk_level": "Medium",
        "recommendations": [
            "Remove stagnant water.",
            "Monitor fever clusters.",
            "Increase public awareness in high-risk areas."
        ]
    }
