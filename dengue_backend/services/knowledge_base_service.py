DENGUE_KNOWLEDGE_BASE = [
    {
        "topic": "Dengue Symptoms",
        "keywords": ["symptom", "fever", "headache", "rash", "joint pain", "muscle pain", "vomiting", "pain"],
        "answer": (
            "Common dengue symptoms include high fever, severe headache, pain behind the eyes, "
            "joint and muscle pain, skin rash, nausea, vomiting, and tiredness. If symptoms continue "
            "or become severe, medical advice is recommended."
        ),
        "evidence": "Dengue symptoms commonly include fever, headache, joint pain, muscle pain, rash, and vomiting."
    },
    {
        "topic": "Dengue Prevention",
        "keywords": ["prevent", "prevention", "avoid", "mosquito", "bite", "net", "repellent"],
        "answer": (
            "Dengue can be prevented by avoiding mosquito bites and removing mosquito breeding places. "
            "Use mosquito nets, repellents, long-sleeved clothing, and keep the environment clean."
        ),
        "evidence": "Dengue prevention focuses on avoiding mosquito bites and reducing mosquito breeding sites."
    },
    {
        "topic": "Mosquito Breeding",
        "keywords": ["breeding", "stagnant water", "water", "containers", "drain", "flower pot", "tire"],
        "answer": (
            "Dengue mosquitoes breed in stagnant water. Remove water from containers, flower pots, "
            "old tires, blocked drains, buckets, and other places where water collects."
        ),
        "evidence": "Stagnant water provides breeding places for dengue mosquitoes."
    },
    {
        "topic": "Dengue Treatment",
        "keywords": ["treatment", "medicine", "cure", "home", "recover", "paracetamol", "doctor"],
        "answer": (
            "There is no specific antiviral cure for dengue. Patients should rest, drink enough fluids, "
            "and seek medical advice. Paracetamol may be used for fever if recommended, but aspirin "
            "and ibuprofen should be avoided unless advised by a doctor."
        ),
        "evidence": "Dengue treatment mainly includes rest, fluids, fever management, and medical monitoring."
    },
    {
        "topic": "Severe Dengue Warning Signs",
        "keywords": ["severe", "warning", "bleeding", "abdominal pain", "vomiting", "breathing", "danger", "hospital"],
        "answer": (
            "Warning signs of severe dengue include severe abdominal pain, persistent vomiting, bleeding, "
            "difficulty breathing, extreme tiredness, cold hands or feet, and restlessness. If these signs appear, "
            "seek medical attention immediately."
        ),
        "evidence": "Severe dengue warning signs include bleeding, persistent vomiting, abdominal pain, and breathing difficulty."
    },
    {
        "topic": "Dengue Transmission",
        "keywords": ["spread", "transmit", "person to person", "contagious", "mosquito bite"],
        "answer": (
            "Dengue usually spreads through the bite of infected Aedes mosquitoes. It does not normally spread "
            "directly from person to person like flu or cold."
        ),
        "evidence": "Dengue is mainly transmitted through infected mosquito bites."
    },
    {
        "topic": "Rainfall and Dengue Risk",
        "keywords": ["rain", "rainfall", "weather", "humidity", "temperature", "climate", "risk"],
        "answer": (
            "Rainfall can increase dengue risk because water can collect in containers and create mosquito breeding sites. "
            "High humidity and suitable temperature can also support mosquito survival and dengue transmission."
        ),
        "evidence": "Rainfall, humidity, and temperature can influence mosquito breeding and dengue transmission risk."
    },
    {
        "topic": "Dengue Diagnosis",
        "keywords": ["diagnosis", "test", "blood test", "ns1", "igm", "igg", "platelet"],
        "answer": (
            "Dengue can be diagnosed using clinical symptoms and blood tests such as NS1 antigen, IgM, IgG, "
            "and platelet count monitoring. A doctor should decide the correct test based on the illness stage."
        ),
        "evidence": "Dengue diagnosis commonly uses symptoms and blood tests such as NS1, IgM, IgG, and platelet count."
    },
    {
        "topic": "Platelet Count",
        "keywords": ["platelet", "platelets", "low platelet", "blood count"],
        "answer": (
            "Dengue can sometimes reduce platelet count. However, platelet count alone should not be used to judge severity. "
            "Doctors monitor platelet count together with symptoms and other clinical signs."
        ),
        "evidence": "Platelet count monitoring is commonly used during dengue illness."
    },
    {
        "topic": "Food and Fluids",
        "keywords": ["food", "drink", "fluid", "water", "juice", "eat"],
        "answer": (
            "Dengue patients should drink enough fluids to prevent dehydration. Water, oral rehydration solutions, "
            "soups, and fruit juices can help. If vomiting continues or the patient cannot drink, medical help is needed."
        ),
        "evidence": "Fluid intake is important during dengue illness to reduce dehydration risk."
    },
]


def search_dengue_knowledge(question: str):
    question_lower = question.lower()

    scored_results = []

    for item in DENGUE_KNOWLEDGE_BASE:
        score = 0

        for keyword in item["keywords"]:
            if keyword in question_lower:
                score += 1

        # Give small score if dengue appears
        if "dengue" in question_lower:
            score += 0.5

        if score > 0:
            scored_results.append({
                "topic": item["topic"],
                "answer": item["answer"],
                "evidence": item["evidence"],
                "score": score
            })

    scored_results.sort(key=lambda x: x["score"], reverse=True)

    return scored_results[:2]


def is_dengue_related(question: str):
    dengue_terms = [
        "dengue", "fever", "mosquito", "rainfall", "humidity", "rash",
        "platelet", "bleeding", "ns1", "igm", "igg", "aedes",
        "outbreak", "risk", "symptom", "prevention"
    ]

    question_lower = question.lower()

    return any(term in question_lower for term in dengue_terms)