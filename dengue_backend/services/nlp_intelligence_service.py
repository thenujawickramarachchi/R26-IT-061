KNOWN_LOCATIONS = [
    "colombo", "dehiwala", "mount lavinia", "moratuwa", "maharagama",
    "kaduwela", "homagama", "kotte", "nugegoda", "battaramulla",
    "gampaha", "kalutara", "kandy", "galle", "matara"
]

TEMPORAL_WORDS = {
    "today": "The message refers to current dengue conditions.",
    "this week": "The message refers to this week's dengue situation.",
    "last week": "The message compares with last week's dengue situation.",
    "next week": "The message asks about near-future dengue risk.",
    "last month": "The message refers to last month's dengue trend.",
    "recent": "The message suggests a recent dengue trend.",
    "increased": "The text suggests an increasing dengue trend.",
    "decreased": "The text suggests a decreasing dengue trend."
}

SOURCE_KB = [
    {
        "title": "Dengue Symptoms Knowledge",
        "keywords": ["symptom", "fever", "headache", "rash", "joint pain"],
        "evidence": "Common dengue symptoms include high fever, headache, joint pain, muscle pain, rash, vomiting, and tiredness."
    },
    {
        "title": "Dengue Prevention Knowledge",
        "keywords": ["prevent", "prevention", "mosquito", "breeding", "water"],
        "evidence": "Dengue prevention focuses on removing stagnant water, reducing mosquito breeding sites, and avoiding mosquito bites."
    },
    {
        "title": "Dengue Risk Factors Knowledge",
        "keywords": ["risk", "rainfall", "humidity", "temperature", "outbreak"],
        "evidence": "Dengue risk can increase with rainfall, humidity, stagnant water, and mosquito breeding conditions."
    }
]

def extract_locations(text: str):
    lowered = text.lower()
    return [loc.title() for loc in KNOWN_LOCATIONS if loc in lowered]

def analyze_temporal_context(text: str):
    lowered = text.lower()
    insights = [message for key, message in TEMPORAL_WORDS.items() if key in lowered]
    if not insights:
        return "No clear time-based dengue trend was detected."
    return " ".join(insights)

def retrieve_evidence(text: str):
    lowered = text.lower()
    matched = []

    for source in SOURCE_KB:
        score = sum(1 for keyword in source["keywords"] if keyword in lowered)
        if score > 0:
            matched.append({
                "source": source["title"],
                "evidence": source["evidence"],
                "score": score
            })

    if not matched:
        matched.append({
            "source": "General Dengue Knowledge",
            "evidence": "Dengue intelligence should be interpreted using health reports, climate conditions, and verified medical guidance.",
            "score": 1
        })

    matched.sort(key=lambda item: item["score"], reverse=True)
    return matched[:2]

def calculate_confidence(evidence_count: int, location_count: int, has_temporal: bool):
    confidence = 0.62
    confidence += min(evidence_count * 0.10, 0.20)
    confidence += min(location_count * 0.05, 0.10)
    if has_temporal:
        confidence += 0.08
    return round(min(confidence, 0.95), 2)
