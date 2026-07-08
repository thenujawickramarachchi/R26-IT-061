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

# Base paths - Hugging Face Space / deployment root folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(BASE_DIR, "colombo_dengue_rf_future_year_model.pkl")
DATA_PATH = os.path.join(BASE_DIR, "Colombo_Dengue_Clean_Model_Only_2022_2025.csv")

# Load model and historical dataset only
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

WEATHER_COLUMNS = [
    "rainfall_mm",
    "humidity_pct",
    "temp_max_c",
    "temp_min_c",
    "temp_mean_c"
]

REQUIRED_COLUMNS = [
    "year",
    "week",
    "month",
    "dengue_cases",
    "rainfall_mm",
    "humidity_pct",
    "temp_max_c",
    "temp_min_c",
    "temp_mean_c"
]

missing_required = [col for col in REQUIRED_COLUMNS if col not in history_df.columns]
if missing_required:
    raise RuntimeError(f"Historical dataset is missing required columns: {missing_required}")

# Clean basic data types once at startup
history_df["year"] = history_df["year"].astype(int)
history_df["week"] = history_df["week"].astype(int)
history_df["month"] = history_df["month"].astype(int)

for col in ["dengue_cases"] + WEATHER_COLUMNS:
    history_df[col] = pd.to_numeric(history_df[col], errors="coerce")

# Fill any missing numeric values using median so averages do not break
for col in ["dengue_cases"] + WEATHER_COLUMNS:
    history_df[col] = history_df[col].fillna(history_df[col].median())


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
    """Convert ISO year/week into month."""
    try:
        return date.fromisocalendar(year, week, 1).month
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid year/week. Please enter a valid ISO week number."
        )


def get_previous_year_week(year: int, week: int, offset: int):
    """Returns previous ISO year/week. Handles year boundary automatically."""
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
    """Creates lag features for historical rows for /predict-auto."""
    df = history_df.copy()
    df = df.sort_values(["year", "week"]).reset_index(drop=True)

    df["dengue_lag_1"] = df["dengue_cases"].shift(1)
    df["dengue_lag_2"] = df["dengue_cases"].shift(2)
    df["rainfall_lag_1"] = df["rainfall_mm"].shift(1)
    df["humidity_lag_1"] = df["humidity_pct"].shift(1)

    numeric_cols = WEATHER_COLUMNS + [
        "dengue_lag_1",
        "dengue_lag_2",
        "rainfall_lag_1",
        "humidity_lag_1"
    ]

    df[numeric_cols] = df[numeric_cols].fillna(df[numeric_cols].median(numeric_only=True))
    return df


def historical_average_for_week_or_month(column: str, week: int, month: int) -> float:
    """
    Gets a historical seasonal estimate.
    Priority:
    1. Average of the same ISO week across historical years
    2. Average of the same month across historical years
    3. Overall historical average
    """
    same_week = history_df[history_df["week"] == week]
    if not same_week.empty and same_week[column].notna().any():
        return float(same_week[column].mean())

    same_month = history_df[history_df["month"] == month]
    if not same_month.empty and same_month[column].notna().any():
        return float(same_month[column].mean())

    return float(history_df[column].mean())


def build_historical_future_features(year: int, week: int) -> pd.DataFrame:
    """
    Builds all 12 model features without future_weather_forecast.csv.

    This uses historical seasonal averages from the official historical dataset:
    - target week weather = average weather for the same week across previous years
    - dengue_lag_1 = average dengue cases for previous week across previous years
    - dengue_lag_2 = average dengue cases for two-week previous week across previous years
    - rainfall_lag_1 = average rainfall for previous week across previous years
    - humidity_lag_1 = average humidity for previous week across previous years
    """
    month = get_month_from_year_week(year, week)

    prev1_year, prev1_week = get_previous_year_week(year, week, offset=1)
    prev2_year, prev2_week = get_previous_year_week(year, week, offset=2)

    prev1_month = get_month_from_year_week(prev1_year, prev1_week)
    prev2_month = get_month_from_year_week(prev2_year, prev2_week)

    rainfall_mm = historical_average_for_week_or_month("rainfall_mm", week, month)
    humidity_pct = historical_average_for_week_or_month("humidity_pct", week, month)
    temp_max_c = historical_average_for_week_or_month("temp_max_c", week, month)
    temp_min_c = historical_average_for_week_or_month("temp_min_c", week, month)
    temp_mean_c = historical_average_for_week_or_month("temp_mean_c", week, month)

    dengue_lag_1 = historical_average_for_week_or_month("dengue_cases", prev1_week, prev1_month)
    dengue_lag_2 = historical_average_for_week_or_month("dengue_cases", prev2_week, prev2_month)
    rainfall_lag_1 = historical_average_for_week_or_month("rainfall_mm", prev1_week, prev1_month)
    humidity_lag_1 = historical_average_for_week_or_month("humidity_pct", prev1_week, prev1_month)

    input_df = pd.DataFrame([{
        "year": int(year),
        "week": int(week),
        "month": int(month),
        "rainfall_mm": round(rainfall_mm, 2),
        "humidity_pct": round(humidity_pct, 2),
        "temp_max_c": round(temp_max_c, 2),
        "temp_min_c": round(temp_min_c, 2),
        "temp_mean_c": round(temp_mean_c, 2),
        "dengue_lag_1": round(dengue_lag_1, 2),
        "dengue_lag_2": round(dengue_lag_2, 2),
        "rainfall_lag_1": round(rainfall_lag_1, 2),
        "humidity_lag_1": round(humidity_lag_1, 2)
    }])

    return input_df[FEATURES]


def get_probability_output(input_df: pd.DataFrame):
    if not hasattr(model, "predict_proba"):
        return None

    probabilities = model.predict_proba(input_df)[0]

    return {
        str(class_name): round(float(probability) * 100, 2)
        for class_name, probability in zip(model.classes_, probabilities)
    }


def get_prediction_response(input_df: pd.DataFrame):
    prediction = model.predict(input_df)[0]
    probability_output = get_probability_output(input_df)

    return str(prediction), probability_output


@app.get("/")
def home():
    return {
        "message": "Colombo Dengue Outbreak Prediction API is running",
        "model": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "accuracy": "84.31%",
        "weighted_f1": "82.11%",
        "future_prediction_mode": "Historical seasonal average estimation",
        "note": "future_weather_forecast.csv is not used. Future inputs are estimated from historical weekly/monthly averages.",
        "available_endpoints": [
            "/predict",
            "/predict-auto",
            "/predict-future",
            "/available-weeks",
            "/supported-future-weeks"
        ]
    }


@app.post("/predict")
def predict_manual(data: ManualDengueInput):
    """Manual prediction endpoint when all 12 feature values are provided."""
    input_df = pd.DataFrame([to_dict(data)])
    input_df = input_df[FEATURES]

    prediction, probability_output = get_prediction_response(input_df)

    return {
        "predicted_outbreak_level": prediction,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "manual"
    }


@app.post("/predict-auto")
def predict_auto(data: AutoDengueInput):
    """Automated past-data prediction endpoint for historical dataset testing."""
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
    prediction, probability_output = get_prediction_response(input_df)
    actual_level = selected_row["outbreak_level"].values[0] if "outbreak_level" in selected_row.columns else None

    return {
        "year": year,
        "week": week,
        "predicted_outbreak_level": prediction,
        "actual_outbreak_level": actual_level,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "automated_from_historical_dataset"
    }


@app.post("/predict-future")
def predict_future(data: AutoDengueInput):
    """
    Future prediction endpoint using historical seasonal averages only.

    User only enters:
    - prediction year
    - prediction week

    The backend automatically estimates all model features using previous years' historical data.
    No manually created future_weather_forecast.csv is required.
    """
    year = data.year
    week = data.week

    input_df = build_historical_future_features(year, week)
    prediction, probability_output = get_prediction_response(input_df)

    prev1_year, prev1_week = get_previous_year_week(year, week, offset=1)
    prev2_year, prev2_week = get_previous_year_week(year, week, offset=2)

    return {
        "year": year,
        "week": week,
        "calculated_month": int(input_df.iloc[0]["month"]),
        "predicted_outbreak_level": prediction,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "input_type": "future_prediction_from_historical_seasonal_averages",
        "auto_generated_features": input_df.iloc[0].to_dict(),
        "data_sources_used": {
            "target_weather": f"Historical average for Week {week} from official historical dataset",
            "dengue_lag_1": f"Historical average dengue cases for previous Week {prev1_week}",
            "dengue_lag_2": f"Historical average dengue cases for two-week previous Week {prev2_week}",
            "rainfall_lag_1": f"Historical average rainfall for previous Week {prev1_week}",
            "humidity_lag_1": f"Historical average humidity for previous Week {prev1_week}"
        },
        "important_note": "This is a historical seasonal average based future risk estimation, not a real-time weather forecast based prediction."
    }


@app.get("/available-weeks")
def available_weeks():
    """Shows available year/week values from the historical dataset."""
    available = history_df[["year", "week"]].drop_duplicates().sort_values(["year", "week"])
    return {
        "available_weeks": available.to_dict(orient="records")
    }


@app.get("/supported-future-weeks")
def supported_future_weeks():
    """
    Shows supported ISO weeks for future prediction.
    Since historical averages are used, any valid ISO week can be estimated.
    """
    return {
        "supported_input_format": {
            "year": "Any future year, e.g., 2026 or 2027",
            "week": "Valid ISO week number, usually 1-52 or 1-53 depending on the year"
        },
        "example_inputs": [
            {"year": 2026, "week": 40},
            {"year": 2026, "week": 45},
            {"year": 2027, "week": 10}
        ],
        "mode": "historical_seasonal_average_estimation"
    }
