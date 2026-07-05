from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import joblib
import os
from datetime import date, timedelta

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
    "colombo_dengue_rf_future_year_model.pkl"
)

DATA_PATH = os.path.join(
    BASE_DIR,
    "Colombo_Dengue_Clean_Model_Only_2022_2025.csv"
)

FUTURE_FORECAST_PATH = os.path.join(
    BASE_DIR,
    "future_weather_forecast.csv"
)

# Load model and datasets
model = joblib.load(MODEL_PATH)
history_df = pd.read_csv(DATA_PATH)
future_df = pd.read_csv(FUTURE_FORECAST_PATH)

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


def to_dict(data):
    """Supports both Pydantic v1 and v2."""
    if hasattr(data, "model_dump"):
        return data.model_dump()
    return data.dict()


def get_month_from_year_week(year: int, week: int) -> int:
    """
    Convert ISO year/week into month.
    Example: 2026 Week 40 starts in September, so month = 9.
    """
    try:
        return date.fromisocalendar(year, week, 1).month
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid year/week. Please enter a valid ISO week number."
        )


def get_previous_year_week(year: int, week: int, offset: int):
    """
    Returns previous ISO year/week.
    Handles year boundary automatically.
    Example: 2026 Week 1 previous week may be 2025 Week 52.
    """
    try:
        current_week_date = date.fromisocalendar(year, week, 1)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid year/week. Please enter a valid ISO week number."
        )

    previous_date = current_week_date - timedelta(weeks=offset)
    previous_iso = previous_date.isocalendar()

    return int(previous_iso.year), int(previous_iso.week)


def prepare_history_with_lags():
    """
    Creates lag features for historical rows.
    This keeps the original /predict-auto endpoint working for past dataset testing.
    """
    df = history_df.copy()
    df["year"] = df["year"].astype(int)
    df["week"] = df["week"].astype(int)
    df = df.sort_values(["year", "week"]).reset_index(drop=True)

    df["dengue_lag_1"] = df["dengue_cases"].shift(1)
    df["dengue_lag_2"] = df["dengue_cases"].shift(2)
    df["rainfall_lag_1"] = df["rainfall_mm"].shift(1)
    df["humidity_lag_1"] = df["humidity_pct"].shift(1)

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

    return df


def prepare_combined_data():
    """
    Combines historical data and future forecast data.

    For /predict-future:
    - target week weather is taken from future_weather_forecast.csv
    - dengue_lag_1 and dengue_lag_2 are taken from previous weeks
    - rainfall_lag_1 and humidity_lag_1 are taken from previous week
    """
    history = history_df.copy()
    future = future_df.copy()

    required_future_cols = [
        "year",
        "week",
        "rainfall_mm",
        "humidity_pct",
        "temp_max_c",
        "temp_min_c",
        "temp_mean_c",
        "dengue_cases"
    ]

    missing_cols = [col for col in required_future_cols if col not in future.columns]
    if missing_cols:
        raise HTTPException(
            status_code=500,
            detail=f"future_weather_forecast.csv is missing columns: {missing_cols}"
        )

    history["year"] = history["year"].astype(int)
    history["week"] = history["week"].astype(int)

    future["year"] = future["year"].astype(int)
    future["week"] = future["week"].astype(int)

    combined = pd.concat([history, future], ignore_index=True, sort=False)
    combined = combined.sort_values(["year", "week"]).reset_index(drop=True)

    return combined


def get_row_by_year_week(df: pd.DataFrame, year: int, week: int):
    row = df[(df["year"] == year) & (df["week"] == week)]

    if row.empty:
        return None

    return row.iloc[0]


def get_probability_output(input_df: pd.DataFrame):
    if not hasattr(model, "predict_proba"):
        return None

    probabilities = model.predict_proba(input_df)[0]

    return {
        str(class_name): round(float(probability) * 100, 2)
        for class_name, probability in zip(model.classes_, probabilities)
    }


@app.get("/")
def home():
    return {
        "message": "Colombo Dengue Outbreak Prediction API is running",
        "model": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "accuracy": "84.31%",
        "weighted_f1": "82.11%",
        "available_endpoints": [
            "/predict",
            "/predict-auto",
            "/predict-future",
            "/available-weeks",
            "/available-future-weeks"
        ]
    }


@app.post("/predict")
def predict_manual(data: ManualDengueInput):
    """
    Manual prediction endpoint.
    Use this for Swagger/API testing when all 12 feature values are provided.
    """

    input_df = pd.DataFrame([to_dict(data)])
    input_df = input_df[FEATURES]

    prediction = model.predict(input_df)[0]
    probability_output = get_probability_output(input_df)

    return {
        "predicted_outbreak_level": str(prediction),
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "manual"
    }


@app.post("/predict-auto")
def predict_auto(data: AutoDengueInput):
    """
    Automated past-data prediction endpoint.
    User only enters year and week.
    Backend automatically gets weather and lag values from historical dataset.
    This endpoint is mainly for testing past data such as 2025 Week 10.
    """

    year = data.year
    week = data.week

    df = prepare_history_with_lags()

    selected_row = df[(df["year"] == year) & (df["week"] == week)]

    if selected_row.empty:
        raise HTTPException(
            status_code=404,
            detail="No historical data found for the selected year and week."
        )

    input_df = selected_row[FEATURES]

    prediction = model.predict(input_df)[0]
    probability_output = get_probability_output(input_df)

    actual_level = selected_row["outbreak_level"].values[0] if "outbreak_level" in selected_row.columns else None

    return {
        "year": year,
        "week": week,
        "predicted_outbreak_level": str(prediction),
        "actual_outbreak_level": actual_level,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "automated_from_historical_dataset"
    }


@app.post("/predict-future")
def predict_future(data: AutoDengueInput):
    """
    Future prediction endpoint.

    User only enters:
    - prediction year
    - prediction week

    Backend automatically creates all 12 model features using:
    - target week weather forecast values
    - previous week dengue cases
    - two-week previous dengue cases
    - previous week rainfall
    - previous week humidity
    """

    year = data.year
    week = data.week

    combined_df = prepare_combined_data()

    target_row = get_row_by_year_week(combined_df, year, week)

    if target_row is None:
        raise HTTPException(
            status_code=404,
            detail=f"No forecast data found for Year {year}, Week {week}. Add that week to future_weather_forecast.csv."
        )

    prev1_year, prev1_week = get_previous_year_week(year, week, offset=1)
    prev2_year, prev2_week = get_previous_year_week(year, week, offset=2)

    prev1_row = get_row_by_year_week(combined_df, prev1_year, prev1_week)
    prev2_row = get_row_by_year_week(combined_df, prev2_year, prev2_week)

    if prev1_row is None:
        raise HTTPException(
            status_code=404,
            detail=f"Previous week data not found for Year {prev1_year}, Week {prev1_week}."
        )

    if prev2_row is None:
        raise HTTPException(
            status_code=404,
            detail=f"Two-week previous data not found for Year {prev2_year}, Week {prev2_week}."
        )

    target_weather_cols = [
        "rainfall_mm",
        "humidity_pct",
        "temp_max_c",
        "temp_min_c",
        "temp_mean_c"
    ]

    for col in target_weather_cols:
        if pd.isna(target_row[col]):
            raise HTTPException(
                status_code=400,
                detail=f"Missing target week weather value '{col}' for Year {year}, Week {week}."
            )

    if pd.isna(prev1_row["dengue_cases"]):
        raise HTTPException(
            status_code=400,
            detail=f"Missing dengue_cases for previous week Year {prev1_year}, Week {prev1_week}."
        )

    if pd.isna(prev2_row["dengue_cases"]):
        raise HTTPException(
            status_code=400,
            detail=f"Missing dengue_cases for two-week previous Year {prev2_year}, Week {prev2_week}."
        )

    if pd.isna(prev1_row["rainfall_mm"]):
        raise HTTPException(
            status_code=400,
            detail=f"Missing rainfall_mm for previous week Year {prev1_year}, Week {prev1_week}."
        )

    if pd.isna(prev1_row["humidity_pct"]):
        raise HTTPException(
            status_code=400,
            detail=f"Missing humidity_pct for previous week Year {prev1_year}, Week {prev1_week}."
        )

    calculated_month = get_month_from_year_week(year, week)

    input_df = pd.DataFrame([{
        "year": int(year),
        "week": int(week),
        "month": int(calculated_month),
        "rainfall_mm": float(target_row["rainfall_mm"]),
        "humidity_pct": float(target_row["humidity_pct"]),
        "temp_max_c": float(target_row["temp_max_c"]),
        "temp_min_c": float(target_row["temp_min_c"]),
        "temp_mean_c": float(target_row["temp_mean_c"]),
        "dengue_lag_1": float(prev1_row["dengue_cases"]),
        "dengue_lag_2": float(prev2_row["dengue_cases"]),
        "rainfall_lag_1": float(prev1_row["rainfall_mm"]),
        "humidity_lag_1": float(prev1_row["humidity_pct"])
    }])

    input_df = input_df[FEATURES]

    prediction = model.predict(input_df)[0]
    probability_output = get_probability_output(input_df)

    return {
        "year": year,
        "week": week,
        "calculated_month": calculated_month,
        "predicted_outbreak_level": str(prediction),
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "input_type": "future_prediction_from_forecast_csv",
        "auto_generated_features": input_df.iloc[0].to_dict(),
        "data_sources_used": {
            "target_weather": f"Year {year}, Week {week}",
            "dengue_lag_1": f"Year {prev1_year}, Week {prev1_week}",
            "dengue_lag_2": f"Year {prev2_year}, Week {prev2_week}",
            "rainfall_lag_1": f"Year {prev1_year}, Week {prev1_week}",
            "humidity_lag_1": f"Year {prev1_year}, Week {prev1_week}"
        }
    }


@app.get("/available-weeks")
def available_weeks():
    """
    Shows available year/week values from the historical dataset.
    Useful for testing /predict-auto.
    """

    available = history_df[["year", "week"]].drop_duplicates().sort_values(["year", "week"])

    return {
        "available_weeks": available.to_dict(orient="records")
    }


@app.get("/available-future-weeks")
def available_future_weeks():
    """
    Shows available year/week values from future_weather_forecast.csv.
    Useful for testing /predict-future.
    """

    available = future_df[["year", "week"]].drop_duplicates().sort_values(["year", "week"])

    return {
        "available_future_weeks": available.to_dict(orient="records")
    }
