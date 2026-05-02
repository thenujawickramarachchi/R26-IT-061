from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import joblib
import os

app = FastAPI(title="Dengue Outbreak Prediction API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model files from ../models folder
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(BASE_DIR, "models")

model = joblib.load(os.path.join(MODEL_DIR, "random_forest_dengue_model.pkl"))
label_encoder = joblib.load(os.path.join(MODEL_DIR, "label_encoder.pkl"))
model_features = joblib.load(os.path.join(MODEL_DIR, "model_features.pkl"))


class DengueInput(BaseModel):
    year: int
    week: int
    month: int
    temp_max_c: float
    temp_min_c: float
    temp_mean_c: float
    feelslikemax: float
    feelslikemin: float
    feelslike: float
    dew: float
    humidity_pct: float
    rainfall_mm: float
    precipprob: float
    precipcover: float
    wind_speed_kmh: float
    winddir: float
    sealevelpressure: float
    cloudcover: float
    visibility: float
    solarradiation: float
    solarenergy: float
    uvindex: float


@app.get("/")
def home():
    return {"message": "Dengue Outbreak Prediction API is running"}


@app.post("/predict")
def predict_outbreak(data: DengueInput):
    input_df = pd.DataFrame([data.model_dump()])

    # Ensure same feature order as training
    input_df = input_df[model_features]

    prediction = model.predict(input_df)
    predicted_label = label_encoder.inverse_transform(prediction)[0]

    probabilities = model.predict_proba(input_df)[0]
    probability_output = {
        label: round(float(prob), 4)
        for label, prob in zip(label_encoder.classes_, probabilities)
    }

    return {
        "predicted_outbreak_level": predicted_label,
        "probabilities": probability_output,
        "model_used": "Random Forest"
    }