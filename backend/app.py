from flask import Flask, jsonify, request
from flask_cors import CORS
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
import shap

BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR / "models"

app = Flask(__name__)
CORS(app)

model = joblib.load(MODEL_DIR / "random_forest_dengue_model.pkl")
label_encoder = joblib.load(MODEL_DIR / "label_encoder.pkl")
model_features = joblib.load(MODEL_DIR / "model_features.pkl")

feature_importance_df = pd.read_csv(MODEL_DIR / "feature_importance.csv")
ml_df = pd.read_csv(MODEL_DIR / "Dengue_ML_Ready.csv")
metrics_df = pd.read_csv(MODEL_DIR / "model_comparison_results.csv")

X_BACKGROUND = ml_df[model_features].copy()
X_BACKGROUND = X_BACKGROUND.apply(pd.to_numeric, errors="coerce").fillna(0)
BACKGROUND_SAMPLE = X_BACKGROUND.tail(min(100, len(X_BACKGROUND)))

explainer = shap.TreeExplainer(model)

FEATURE_LABELS = {
    "wind_speed_kmh": "Wind Speed",
    "visibility": "Visibility",
    "feelslike": "Feels Like Temp",
    "week": "Epidemiological Week",
    "cloudcover": "Cloud Cover",
    "humidity_pct": "Humidity",
    "rainfall_mm": "Rainfall",
    "temp_mean_c": "Mean Temperature",
    "temp_max_c": "Max Temperature",
    "temp_min_c": "Min Temperature",
    "precipprob": "Precipitation Probability",
    "precipcover": "Precipitation Cover",
    "dew": "Dew Point",
    "sealevelpressure": "Sea Level Pressure",
    "solarradiation": "Solar Radiation",
    "solarenergy": "Solar Energy",
    "uvindex": "UV Index",
    "dengue_cases": "Dengue Cases",
    "month": "Month",
    "year": "Year",
}


MOH_AREAS = [
    {"name": "Colombo Municipal Council", "risk": "High", "cases": 162, "lat": 6.9271, "lng": 79.8612},
    {"name": "Dehiwala", "risk": "High", "cases": 128, "lat": 6.8566, "lng": 79.8650},
    {"name": "Maharagama", "risk": "Medium", "cases": 95, "lat": 6.8480, "lng": 79.9265},
    {"name": "Nugegoda", "risk": "Medium", "cases": 82, "lat": 6.8649, "lng": 79.8997},
    {"name": "Kaduwela", "risk": "Low", "cases": 44, "lat": 6.9358, "lng": 79.9842},
    {"name": "Homagama", "risk": "Low", "cases": 31, "lat": 6.8440, "lng": 80.0024},
]


def label_for(feature):
    return FEATURE_LABELS.get(feature, feature.replace("_", " ").title())


def normalize_payload(payload: dict):
    latest = ml_df.tail(1).iloc[0].to_dict()
    row, missing = [], []

    for feature in model_features:
        value = payload.get(feature, latest.get(feature, 0.0))

        if feature not in payload:
            missing.append(feature)

        try:
            row.append(float(value))
        except Exception:
            raise ValueError(f"Invalid numeric value for feature: {feature}")

    return np.array([row], dtype=float), missing


def risk_color(risk):
    return {
        "High": "#E53935",
        "Medium": "#FB8C00",
        "Low": "#43A047",
    }.get(risk, "#607D8B")


def interventions(risk, top_drivers):
    drivers = [d["label"] for d in top_drivers[:3]]

    if risk == "High":
        return [
            {
                "title": "Urgent MOH field inspection",
                "priority": "Critical",
                "confidence": 0.92,
                "reason": f"High-risk drivers detected: {', '.join(drivers)}.",
            },
            {
                "title": "Source reduction within 24 hours",
                "priority": "Critical",
                "confidence": 0.89,
                "reason": "Remove stagnant-water breeding sites before next transmission cycle.",
            },
            {
                "title": "Targeted public alert",
                "priority": "High",
                "confidence": 0.86,
                "reason": "Notify households, schools and construction sites in high-risk areas.",
            },
        ]

    if risk == "Medium":
        return [
            {
                "title": "Increase surveillance frequency",
                "priority": "High",
                "confidence": 0.84,
                "reason": f"Risk is influenced by {', '.join(drivers)}.",
            },
            {
                "title": "Community cleanup campaign",
                "priority": "Medium",
                "confidence": 0.80,
                "reason": "Reduce breeding sites before risk escalates.",
            },
            {
                "title": "Monitor climate triggers",
                "priority": "Medium",
                "confidence": 0.76,
                "reason": "Watch rainfall, humidity, temperature and wind changes.",
            },
        ]

    return [
        {
            "title": "Routine monitoring",
            "priority": "Normal",
            "confidence": 0.78,
            "reason": "Current pattern is within low-risk range.",
        },
        {
            "title": "Maintain public awareness",
            "priority": "Normal",
            "confidence": 0.72,
            "reason": "Prevent breeding-site accumulation.",
        },
    ]


def local_xai(payload, risk):
    x, _ = normalize_payload(payload)
    x = x[0]

    stats = ml_df[model_features].apply(pd.to_numeric, errors="coerce").fillna(0).agg(["mean", "std"]).replace(0, 1)
    imp_map = dict(zip(feature_importance_df["Feature"], feature_importance_df["Importance"]))

    rows = []

    for feature, value in zip(model_features, x):
        mean = float(stats.loc["mean", feature])
        std = float(stats.loc["std", feature]) or 1.0
        importance = float(imp_map.get(feature, 0.01))
        deviation = (float(value) - mean) / std
        contribution = importance * deviation
        direction = "increases" if contribution >= 0 else "decreases"

        rows.append({
            "feature": feature,
            "label": label_for(feature),
            "value": round(float(value), 3),
            "baseline": round(mean, 3),
            "importance": round(importance, 5),
            "contribution": round(float(contribution), 5),
            "abs_contribution": round(abs(float(contribution)), 5),
            "direction": direction,
            "explanation": f"{label_for(feature)} is {round(abs(deviation), 2)} standard deviations from the historical average and {direction} the {risk} prediction.",
        })

    return sorted(rows, key=lambda r: r["abs_contribution"], reverse=True)[:10]


def get_shap_values(payload):
    x_array, _ = normalize_payload(payload)
    x_df = pd.DataFrame(x_array, columns=model_features)

    shap_values = explainer.shap_values(x_df)

    predicted_encoded = int(model.predict(x_array)[0])
    risk = label_encoder.inverse_transform([predicted_encoded])[0]

    class_index = list(model.classes_).index(predicted_encoded)

    if isinstance(shap_values, list):
        values = shap_values[class_index][0]
    else:
        shap_values = np.array(shap_values)

        if shap_values.ndim == 3:
            values = shap_values[0, :, class_index]
        elif shap_values.ndim == 2:
            values = shap_values[0]
        else:
            raise ValueError(f"Unsupported SHAP local shape: {shap_values.shape}")

    rows = []

    for feature, value, shap_value in zip(model_features, x_df.iloc[0], values):
        direction = "increases" if shap_value > 0 else "decreases"

        rows.append({
            "feature": feature,
            "label": label_for(feature),
            "value": round(float(value), 3),
            "shap_value": round(float(shap_value), 5),
            "abs_shap": round(abs(float(shap_value)), 5),
            "direction": direction,
            "explanation": f"{label_for(feature)} {direction} the {risk} risk prediction based on SHAP analysis.",
        })

    rows = sorted(rows, key=lambda r: r["abs_shap"], reverse=True)

    return risk, rows


def predict_core(payload):
    x, missing = normalize_payload(payload)

    encoded = model.predict(x)[0]
    risk = label_encoder.inverse_transform([int(encoded)])[0]

    probabilities, confidence = {}, 0.0

    if hasattr(model, "predict_proba"):
        proba = model.predict_proba(x)[0]

        for cls_index, prob in zip(model.classes_, proba):
            label = label_encoder.inverse_transform([int(cls_index)])[0]
            probabilities[label] = round(float(prob), 4)

        confidence = round(float(max(proba)), 4)

    explanation = local_xai(payload, risk)

    return risk, confidence, probabilities, missing, explanation


@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "model": "Random Forest",
        "features": model_features,
    })


@app.get("/sample-input")
def sample_input():
    latest = ml_df.tail(1).iloc[0]
    return jsonify({f: float(latest[f]) for f in model_features})


@app.post("/predict")
def predict():
    try:
        payload = request.get_json(force=True) or {}
        risk, confidence, probabilities, missing, explanation = predict_core(payload)

        return jsonify({
            "risk_level": risk,
            "risk_color": risk_color(risk),
            "confidence": round(float(confidence), 4),
            "probabilities": probabilities,
            "missing_features_filled_with_latest_dataset_values": missing,
            "xai_local": explanation,
            "top_reason": "Top drivers: " + ", ".join([x["label"] for x in explanation[:3]]),
            "recommendations": interventions(risk, explanation),
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 400


@app.get("/xai/global")
def xai_global():
    top = feature_importance_df.head(12).copy()
    top["Label"] = top["Feature"].map(label_for)
    return jsonify({"features": top.to_dict(orient="records")})


@app.get("/xai/shap/global")
def shap_global():
    try:
        sample = BACKGROUND_SAMPLE.copy()
        shap_values = explainer.shap_values(sample)

        if isinstance(shap_values, list):
            abs_values = np.mean([np.abs(v) for v in shap_values], axis=(0, 1))
        else:
            shap_values = np.array(shap_values)

            if shap_values.ndim == 3:
                abs_values = np.mean(np.abs(shap_values), axis=(0, 2))
            elif shap_values.ndim == 2:
                abs_values = np.mean(np.abs(shap_values), axis=0)
            else:
                raise ValueError(f"Unsupported SHAP global shape: {shap_values.shape}")

        rows = []

        for feature, value in zip(model_features, abs_values):
            rows.append({
                "feature": feature,
                "label": label_for(feature),
                "mean_abs_shap": round(float(value), 5),
                "explanation": f"{label_for(feature)} influences dengue risk prediction based on SHAP analysis.",
            })

        rows = sorted(rows, key=lambda r: r["mean_abs_shap"], reverse=True)

        return jsonify({
            "method": "SHAP TreeExplainer",
            "features": rows[:12],
        })

    except Exception as e:
        print("SHAP GLOBAL ERROR:", e)
        return jsonify({"error": str(e)}), 400


@app.post("/xai/shap/local")
def shap_local():
    try:
        payload = request.get_json(force=True) or {}

        x_array, _ = normalize_payload(payload)

        predicted_encoded = int(model.predict(x_array)[0])
        risk = label_encoder.inverse_transform([predicted_encoded])[0]

        confidence = 0.0
        probabilities = {}

        if hasattr(model, "predict_proba"):
            proba = model.predict_proba(x_array)[0]

            for cls_index, prob in zip(model.classes_, proba):
                label = label_encoder.inverse_transform([int(cls_index)])[0]
                probabilities[label] = round(float(prob), 4)

            confidence = round(float(max(proba)) * 100, 2)

        _, shap_rows = get_shap_values(payload)

        return jsonify({
            "risk_level": risk,
            "confidence": confidence,
            "probabilities": probabilities,
            "method": "SHAP TreeExplainer",
            "explanations": shap_rows[:10],
        })

    except Exception as e:
        print("SHAP LOCAL ERROR:", e)
        return jsonify({"error": str(e)}), 400


@app.post("/xai/local")
def xai_local_endpoint():
    payload = request.get_json(force=True) or {}
    risk, confidence, probabilities, _, explanation = predict_core(payload)

    return jsonify({
        "risk_level": risk,
        "confidence": round(float(confidence) * 100, 2),
        "probabilities": probabilities,
        "explanations": explanation,
    })


@app.get("/history")
def history():
    possible_cols = [
        "year",
        "week",
        "month",
        "dengue_cases",
        "outbreak_level",
        "rainfall_mm",
        "humidity_pct",
        "temp_mean_c",
        "wind_speed_kmh",
    ]

    cols = [c for c in possible_cols if c in ml_df.columns]
    data = ml_df[cols].tail(16).fillna(0).to_dict(orient="records")

    return jsonify({"weekly": data})

@app.get("/xai/risk-timeline")
def risk_timeline():
    try:
        recent = ml_df.tail(6).copy()

        timeline = []

        for _, row in recent.iterrows():
            payload = {}

            for feature in model_features:
                try:
                    payload[feature] = float(row.get(feature, 0))
                except (ValueError, TypeError):
                    payload[feature] = 0.0

            x, _ = normalize_payload(payload)

            encoded = model.predict(x)[0]
            risk = label_encoder.inverse_transform([int(encoded)])[0]

            confidence = 0.0

            if hasattr(model, "predict_proba"):
                proba = model.predict_proba(x)[0]
                confidence = round(float(max(proba)) * 100, 2)

            timeline.append({
                "week": f"W-{len(timeline)+1}",
                "risk": risk,
                "confidence": confidence,
            })

        return jsonify({
            "timeline": timeline
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 400


@app.get("/dashboard")
def dashboard():
    latest = ml_df.tail(1).iloc[0]
    payload = {f: float(latest[f]) for f in model_features}

    risk, confidence, probabilities, _, explanation = predict_core(payload)

    return jsonify({
        "title": "Dengue Analytics",
        "district": "Colombo District",
        "risk_level": risk,
        "confidence": confidence,
        "probabilities": probabilities,
        "current": {
            "cases": int(latest.get("dengue_cases", 0)),
            "rainfall_mm": round(float(latest.get("rainfall_mm", 0)), 1),
            "humidity_pct": round(float(latest.get("humidity_pct", 0)), 1),
            "temp_mean_c": round(float(latest.get("temp_mean_c", 0)), 1),
            "wind_speed_kmh": round(float(latest.get("wind_speed_kmh", 0)), 1),
        },
        "top_xai": explanation[:4],
    })


@app.get("/metrics")
def metrics():
    return jsonify({"models": metrics_df.to_dict(orient="records")})


@app.get("/moh-risk-map")
def moh_risk_map():
    return jsonify({"areas": MOH_AREAS})


@app.get("/notifications")
def notifications():
    return jsonify({
        "notifications": [
            {
                "type": "alert",
                "title": "High Dengue Risk Alert",
                "body": "Maharagama is now at a high dengue risk level. Increase mosquito control activities.",
                "time": "5 min ago",
            },
            {
                "type": "weather",
                "title": "Weather Update",
                "body": "Heavy rainfall expected tomorrow in Colombo.",
                "time": "1 hour ago",
            },
            {
                "type": "tips",
                "title": "Dengue Prevention Tips",
                "body": "Remove stagnant water and clean gutters weekly.",
                "time": "Yesterday",
            },
            {
                "type": "insight",
                "title": "XAI Insight",
                "body": "Rainfall and humidity are the strongest current SHAP risk drivers.",
                "time": "2 days ago",
            },
        ]
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)