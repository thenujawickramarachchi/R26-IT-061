import os
import pickle
from typing import Dict, Any
import pandas as pd

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MODEL_PATHS = [
    os.path.join(BASE_DIR, "ml_models", "random_forest_dengue_model.pkl"),
    os.path.join(BASE_DIR, "random_forest_dengue_model.pkl"),
]

FEATURE_PATHS = [
    os.path.join(BASE_DIR, "ml_models", "model_features.pkl"),
    os.path.join(BASE_DIR, "model_features.pkl"),
]

ENCODER_PATHS = [
    os.path.join(BASE_DIR, "ml_models", "label_encoder.pkl"),
    os.path.join(BASE_DIR, "label_encoder.pkl"),
]

DATASET_PATHS = [
    os.path.join(BASE_DIR, "ml_models", "Dengue_ML_Ready.csv"),
    os.path.join(BASE_DIR, "Dengue_ML_Ready.csv"),
]

def _first_existing(paths):
    for path in paths:
        if os.path.exists(path):
            return path
    return None

def _load_pickle(paths):
    path = _first_existing(paths)
    if path is None:
        return None
    with open(path, "rb") as file:
        return pickle.load(file)

def _get_default_feature_values(features):
    dataset_path = _first_existing(DATASET_PATHS)

    if dataset_path:
        try:
            df = pd.read_csv(dataset_path)
            defaults = {}
            for feature in features:
                if feature in df.columns:
                    defaults[feature] = float(pd.to_numeric(df[feature], errors="coerce").median())
                else:
                    defaults[feature] = 0.0
            return defaults
        except Exception:
            pass

    return {
        "year": 2024, "week": 1, "month": 1,
        "temp_max_c": 31.8, "temp_min_c": 24.4, "temp_mean_c": 28.7,
        "feelslikemax": 39.7, "feelslikemin": 25.3, "feelslike": 32.3,
        "dew": 23.0, "humidity_pct": 77.5, "rainfall_mm": 69.8,
        "precipprob": 44.6, "precipcover": 4.3, "wind_speed_kmh": 5.0,
        "winddir": 175.6, "sealevelpressure": 1008.0, "cloudcover": 50.7,
        "visibility": 3.8, "solarradiation": 208.0, "solarenergy": 18.0,
        "uvindex": 7.2,
    }

def _risk_rank(label: str) -> int:
    order = {"Low": 0, "Medium": 1, "High": 2}
    return order.get(str(label), 0)

def _predict(model, encoder, features, values: Dict[str, Any]):
    row = pd.DataFrame([[values.get(feature, 0) for feature in features]], columns=features)
    encoded_pred = model.predict(row)[0]

    if encoder is not None:
        try:
            label = encoder.inverse_transform([encoded_pred])[0]
        except Exception:
            label = str(encoded_pred)
    else:
        label = str(encoded_pred)

    probability = None
    if hasattr(model, "predict_proba"):
        try:
            proba = model.predict_proba(row)[0]
            probability = round(float(max(proba)) * 100, 2)
        except Exception:
            probability = None

    return str(label), probability

def simulate_counterfactual_risk(payload):
    model = _load_pickle(MODEL_PATHS)
    features = _load_pickle(FEATURE_PATHS)
    encoder = _load_pickle(ENCODER_PATHS)

    if model is None or features is None:
        return {
            "error": True,
            "message": "ML model files not found. Make sure ml_models folder contains random_forest_dengue_model.pkl, model_features.pkl, label_encoder.pkl, and Dengue_ML_Ready.csv."
        }

    base_values = _get_default_feature_values(features)

    for key in [
        "year", "week", "month", "temp_max_c", "temp_min_c", "temp_mean_c",
        "humidity_pct", "rainfall_mm", "wind_speed_kmh", "cloudcover",
        "visibility", "uvindex"
    ]:
        value = getattr(payload, key, None)
        if value is not None:
            base_values[key] = value

    # Align related derived weather values
    base_values["feelslike"] = base_values.get("temp_mean_c", 0) + 3
    base_values["feelslikemax"] = base_values.get("temp_max_c", 0) + 6
    base_values["feelslikemin"] = base_values.get("temp_min_c", 0) + 1
    base_values["dew"] = base_values.get("temp_min_c", 0) - 1

    simulated_values = dict(base_values)
    simulated_values["rainfall_mm"] = max(0, simulated_values["rainfall_mm"] + (payload.rainfall_change or 0))
    simulated_values["humidity_pct"] = min(100, max(0, simulated_values["humidity_pct"] + (payload.humidity_change or 0)))
    simulated_values["wind_speed_kmh"] = max(0, simulated_values["wind_speed_kmh"] + (payload.wind_change or 0))

    temp_delta = payload.temperature_change or 0
    for key in ["temp_max_c", "temp_min_c", "temp_mean_c", "feelslike", "feelslikemax", "feelslikemin", "dew"]:
        simulated_values[key] = simulated_values.get(key, 0) + temp_delta

    original_label, original_conf = _predict(model, encoder, features, base_values)
    simulated_label, simulated_conf = _predict(model, encoder, features, simulated_values)

    original_rank = _risk_rank(original_label)
    simulated_rank = _risk_rank(simulated_label)

    if simulated_rank > original_rank:
        change = "Increased"
    elif simulated_rank < original_rank:
        change = "Decreased"
    else:
        change = "No major change"

    reasons = []
    if (payload.rainfall_change or 0) > 0:
        reasons.append("Rainfall increased, which can increase mosquito breeding conditions.")
    elif (payload.rainfall_change or 0) < 0:
        reasons.append("Rainfall decreased, which may reduce mosquito breeding conditions.")

    if (payload.humidity_change or 0) > 0:
        reasons.append("Humidity increased, which can support mosquito survival.")
    elif (payload.humidity_change or 0) < 0:
        reasons.append("Humidity decreased, which may reduce mosquito survival.")

    if (payload.temperature_change or 0) > 0:
        reasons.append("Temperature increased, which can influence mosquito activity and dengue transmission.")
    elif (payload.temperature_change or 0) < 0:
        reasons.append("Temperature decreased, which can reduce transmission suitability.")

    if (payload.wind_change or 0) > 0:
        reasons.append("Wind speed increased, which may affect mosquito movement and exposure patterns.")
    elif (payload.wind_change or 0) < 0:
        reasons.append("Wind speed decreased, which may affect mosquito movement and exposure patterns.")

    if not reasons:
        reasons.append("No counterfactual weather change was applied.")

    if simulated_label == "High":
        recommendation = "Increase field inspections, remove stagnant water, strengthen public awareness, and prepare early response actions."
    elif simulated_label == "Medium":
        recommendation = "Monitor dengue indicators closely and continue preventive actions in vulnerable areas."
    else:
        recommendation = "Maintain routine surveillance and prevention activities."

    return {
        "error": False,
        "original_risk": original_label,
        "original_confidence": original_conf,
        "simulated_risk": simulated_label,
        "simulated_confidence": simulated_conf,
        "risk_change": change,
        "main_reasons": reasons,
        "recommendation": recommendation,
        "simulated_values": {
            "rainfall_mm": round(simulated_values["rainfall_mm"], 2),
            "humidity_pct": round(simulated_values["humidity_pct"], 2),
            "temp_mean_c": round(simulated_values["temp_mean_c"], 2),
            "wind_speed_kmh": round(simulated_values["wind_speed_kmh"], 2),
        }
    }
