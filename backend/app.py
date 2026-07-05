from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import joblib
import os

app = FastAPI(title="Colombo Dengue Outbreak Prediction API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Base paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(
    BASE_DIR,
    "..",
    "models",
    "colombo_dengue_rf_future_year_model.pkl"
)

DATA_PATH = os.path.join(
    BASE_DIR,
    "..",
    "data",
    "Colombo_Dengue_Clean_Model_Only_2022_2025.csv"
)

# Load model and dataset
model = joblib.load(MODEL_PATH)
history_df = pd.read_csv(DATA_PATH)

# Features used in final model training
FEATURES = [
    "year",
    "week",
    "month",
    "rainfall_mm",
    "humidity_pct",
    "temp_max_c",
    "temp_min_c",
    "temp_mean_c",
    "dengue_lag_1",
    "dengue_lag_2",
    "rainfall_lag_1",
    "humidity_lag_1"
]


class ManualDengueInput(BaseModel):
    year: int
    week: int
    month: int
    rainfall_mm: float
    humidity_pct: float
    temp_max_c: float
    temp_min_c: float
    temp_mean_c: float
    dengue_lag_1: float
    dengue_lag_2: float
    rainfall_lag_1: float
    humidity_lag_1: float


class AutoDengueInput(BaseModel):
    year: int
    week: int


@app.get("/")
def home():
    return {
        "message": "Colombo Dengue Outbreak Prediction API is running",
        "model": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "accuracy": "84.31%",
        "weighted_f1": "82.11%"
    }


@app.post("/predict")
def predict_manual(data: ManualDengueInput):
    """
    Manual prediction endpoint.
    Use this for Swagger/API testing when all 12 feature values are provided.
    """

    input_df = pd.DataFrame([data.model_dump()])
    input_df = input_df[FEATURES]

    prediction = model.predict(input_df)[0]
    probabilities = model.predict_proba(input_df)[0]

    probability_output = {
        class_name: round(float(prob) * 100, 2)
        for class_name, prob in zip(model.classes_, probabilities)
    }

    return {
        "predicted_outbreak_level": prediction,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "manual"
    }


@app.post("/predict-auto")
def predict_auto(data: AutoDengueInput):
    """
    Automated prediction endpoint.
    User only enters year and week.
    Backend automatically gets weather and lag values from dataset.
    """

    year = data.year
    week = data.week

    df = history_df.copy()
    df = df.sort_values(["year", "week"]).reset_index(drop=True)

    # Create lag features
    df["dengue_lag_1"] = df["dengue_cases"].shift(1)
    df["dengue_lag_2"] = df["dengue_cases"].shift(2)
    df["rainfall_lag_1"] = df["rainfall_mm"].shift(1)
    df["humidity_lag_1"] = df["humidity_pct"].shift(1)

    # Fill missing weather values
    numeric_cols = [
        "rainfall_mm",
        "humidity_pct",
        "temp_max_c",
        "temp_min_c",
        "temp_mean_c",
        "dengue_lag_1",
        "dengue_lag_2",
        "rainfall_lag_1",
        "humidity_lag_1"
    ]

    df[numeric_cols] = df[numeric_cols].fillna(df[numeric_cols].median(numeric_only=True))

    # Find selected year and week
    selected_row = df[(df["year"] == year) & (df["week"] == week)]

    if selected_row.empty:
        raise HTTPException(
            status_code=404,
            detail="No data found for the selected year and week. Please use a year/week available in the dataset or provide manual input."
        )

    input_df = selected_row[FEATURES]

    prediction = model.predict(input_df)[0]
    probabilities = model.predict_proba(input_df)[0]

    probability_output = {
        class_name: round(float(prob) * 100, 2)
        for class_name, prob in zip(model.classes_, probabilities)
    }

    actual_level = selected_row["outbreak_level"].values[0] if "outbreak_level" in selected_row.columns else None

    return {
        "year": year,
        "week": week,
        "predicted_outbreak_level": prediction,
        "actual_outbreak_level": actual_level,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "automated_from_dataset"
    }


@app.get("/available-weeks")
def available_weeks():
    """
    Shows available year/week values from the dataset.
    Useful for testing predict-auto endpoint.
    """

    available = history_df[["year", "week"]].drop_duplicates().sort_values(["year", "week"])

    return {
        "available_weeks": available.to_dict(orient="records")
    }