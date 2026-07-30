from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import joblib
import os
from datetime import date, timedelta, datetime

app = FastAPI(title="Colombo Dengue Outbreak Prediction API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Base paths - Hugging Face Space root folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(BASE_DIR, "colombo_dengue_rf_future_year_model.pkl")
DATA_PATH = os.path.join(BASE_DIR, "Colombo_Dengue_Clean_Model_Only_2022_2025.csv")

# Load model and historical dataset
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
    "humidity_lag_1",
]

WEATHER_COLUMNS = [
    "rainfall_mm",
    "humidity_pct",
    "temp_max_c",
    "temp_min_c",
    "temp_mean_c",
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
    "temp_mean_c",
]

missing_required = [col for col in REQUIRED_COLUMNS if col not in history_df.columns]
if missing_required:
    raise RuntimeError(f"Historical dataset is missing required columns: {missing_required}")

# Clean data types
history_df["year"] = history_df["year"].astype(int)
history_df["week"] = history_df["week"].astype(int)
history_df["month"] = history_df["month"].astype(int)

for col in ["dengue_cases"] + WEATHER_COLUMNS:
    history_df[col] = pd.to_numeric(history_df[col], errors="coerce")

# Fill missing numeric values using median
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
            detail="Invalid year/week. Please enter a valid ISO week number.",
        )


def get_previous_year_week(year: int, week: int, offset: int):
    """Returns previous ISO year/week and handles year boundaries."""
    try:
        current_week_date = date.fromisocalendar(year, week, 1)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid year/week. Please enter a valid ISO week number.",
        )

    previous_date = current_week_date - timedelta(weeks=offset)
    previous_iso = previous_date.isocalendar()

    return int(previous_iso.year), int(previous_iso.week)


def prepare_history_with_lags():
    """
    Creates lag features for historical rows.
    This endpoint is mainly used for testing past dataset weeks.
    """
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
        "humidity_lag_1",
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
    Method:
    - target week weather = historical average for the same week
    - dengue_lag_1 = historical average dengue cases for previous week
    - dengue_lag_2 = historical average dengue cases for two-week previous week
    - rainfall_lag_1 = historical average rainfall for previous week
    - humidity_lag_1 = historical average humidity for previous week
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
        "humidity_lag_1": round(humidity_lag_1, 2),
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


def risk_color(risk: str) -> str:
    return {
        "High": "#E53935",
        "Medium": "#FB8C00",
        "Low": "#43A047",
    }.get(risk, "#607D8B")


def get_interventions_for_risk(risk: str):
    if risk == "High":
        return [
            {
                "title": "Urgent MOH field inspection",
                "priority": "Critical",
                "confidence": 0.92,
                "reason": "High outbreak risk detected from historical dengue and climate patterns.",
            },
            {
                "title": "Source reduction within 24 hours",
                "priority": "Critical",
                "confidence": 0.89,
                "reason": "Remove stagnant-water breeding sites before the next transmission cycle.",
            },
            {
                "title": "Targeted public health alert",
                "priority": "High",
                "confidence": 0.86,
                "reason": "Notify households, schools, and high-risk locations.",
            },
        ]

    if risk == "Medium":
        return [
            {
                "title": "Increase surveillance frequency",
                "priority": "High",
                "confidence": 0.84,
                "reason": "Medium outbreak risk detected from seasonal dengue and climate patterns.",
            },
            {
                "title": "Community cleanup campaign",
                "priority": "Medium",
                "confidence": 0.80,
                "reason": "Reduce mosquito breeding sites before risk increases.",
            },
            {
                "title": "Monitor climate triggers",
                "priority": "Medium",
                "confidence": 0.76,
                "reason": "Monitor rainfall, humidity, and temperature changes.",
            },
        ]

    return [
        {
            "title": "Routine monitoring",
            "priority": "Normal",
            "confidence": 0.78,
            "reason": "Current pattern is within the low-risk range.",
        },
        {
            "title": "Maintain public awareness",
            "priority": "Normal",
            "confidence": 0.72,
            "reason": "Continue dengue prevention awareness activities.",
        },
    ]


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
            "/predict-dashboard",
            "/latest-dashboard",
            "/available-weeks",
            "/supported-future-weeks",
        ],
    }


@app.post("/predict")
def predict_manual(data: ManualDengueInput):
    """
    Manual prediction endpoint.
    Use this only when all 12 feature values are provided manually.
    """
    input_df = pd.DataFrame([to_dict(data)])
    input_df = input_df[FEATURES]

    prediction, probability_output = get_prediction_response(input_df)

    return {
        "predicted_outbreak_level": prediction,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "manual",
    }


@app.post("/predict-auto")
def predict_auto(data: AutoDengueInput):
    """
    Automated past-data prediction endpoint.
    User enters year and week from historical dataset.
    """
    year = data.year
    week = data.week

    df = prepare_history_with_lags()
    selected_row = df[(df["year"] == year) & (df["week"] == week)]

    if selected_row.empty:
        raise HTTPException(
            status_code=404,
            detail="No historical data found for the selected year and week.",
        )

    input_df = selected_row[FEATURES]
    prediction, probability_output = get_prediction_response(input_df)

    actual_level = (
        selected_row["outbreak_level"].values[0]
        if "outbreak_level" in selected_row.columns
        else None
    )

    return {
        "year": year,
        "week": week,
        "predicted_outbreak_level": prediction,
        "actual_outbreak_level": actual_level,
        "probabilities": probability_output,
        "model_used": "Random Forest with Lag Features",
        "input_type": "automated_from_historical_dataset",
    }


@app.post("/predict-future")
def predict_future(data: AutoDengueInput):
    """
    Future prediction endpoint using historical seasonal averages.
    User only enters:
    - prediction year
    - prediction week
    Backend automatically estimates all required model features using previous years'
    historical dengue and weather data.
    No manually created future_weather_forecast.csv is required.
    """
    year = data.year
    week = data.week

    input_df = build_historical_future_features(year, week)
    prediction, probability_output = get_prediction_response(input_df)

    _, prev1_week = get_previous_year_week(year, week, offset=1)
    _, prev2_week = get_previous_year_week(year, week, offset=2)

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
            "target_weather": f"Historical average weather values for Week {week}",
            "dengue_lag_1": f"Historical average dengue cases for previous Week {prev1_week}",
            "dengue_lag_2": f"Historical average dengue cases for two-week previous Week {prev2_week}",
            "rainfall_lag_1": f"Historical average rainfall for previous Week {prev1_week}",
            "humidity_lag_1": f"Historical average humidity for previous Week {prev1_week}",
        },
        "important_note": "This is a historical seasonal average based future risk estimation, not a real-time weather forecast based prediction.",
    }


@app.post("/predict-dashboard")
def predict_dashboard(data: AutoDengueInput):
    """
    Dashboard/mobile friendly prediction endpoint.
    This endpoint uses the hosted final ML model and returns output in a format
    suitable for dashboards, mobile apps, and group member integrations.
    """
    year = data.year
    week = data.week

    input_df = build_historical_future_features(year, week)
    prediction, probability_output = get_prediction_response(input_df)

    confidence = 0.0
    if probability_output:
        confidence = max(probability_output.values())

    return {
        "year": year,
        "week": week,
        "calculated_month": int(input_df.iloc[0]["month"]),
        "risk_level": prediction,
        "risk_color": risk_color(prediction),
        "confidence": round(float(confidence), 2),
        "probabilities": probability_output,
        "top_reason": "Prediction is mainly based on historical rainfall, humidity, temperature, and dengue lag patterns.",
        "recommendations": get_interventions_for_risk(prediction),
        "model_used": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "input_type": "dashboard_prediction_from_historical_seasonal_averages",
        "auto_generated_features": input_df.iloc[0].to_dict(),
        "important_note": "This endpoint uses the centralized hosted ML model. Inputs are generated automatically using historical seasonal averages.",
    }


@app.get("/latest-dashboard")
def latest_dashboard():
    """
    Latest dashboard prediction endpoint.
    This endpoint does not require year/week input.
    It automatically selects the latest available week from the historical dataset
    and returns a dashboard/mobile friendly prediction response.
    """
    df = prepare_history_with_lags()
    df = df.sort_values(["year", "week"]).reset_index(drop=True)

    latest_row = df.tail(1)

    if latest_row.empty:
        raise HTTPException(
            status_code=404,
            detail="No historical data found in the dataset.",
        )

    input_df = latest_row[FEATURES]
    prediction, probability_output = get_prediction_response(input_df)

    confidence = 0.0
    if probability_output:
        confidence = max(probability_output.values())

    actual_level = (
        latest_row["outbreak_level"].values[0]
        if "outbreak_level" in latest_row.columns
        else None
    )

    latest_year = int(latest_row["year"].values[0])
    latest_week = int(latest_row["week"].values[0])
    latest_month = int(latest_row["month"].values[0])

    return {
        "year": latest_year,
        "week": latest_week,
        "month": latest_month,
        "risk_level": prediction,
        "actual_outbreak_level": actual_level,
        "risk_color": risk_color(prediction),
        "confidence": round(float(confidence), 2),
        "probabilities": probability_output,
        "top_reason": "Latest dengue risk update is generated using the most recent available historical dataset record.",
        "recommendations": get_interventions_for_risk(prediction),
        "model_used": "Random Forest with Lag Features",
        "validation": "Future-Year Validation",
        "input_type": "latest_dashboard_prediction_from_historical_dataset",
        "latest_features_used": input_df.iloc[0].to_dict(),
        "important_note": "This endpoint automatically uses the latest available week from the uploaded historical dataset. No year/week input is required.",
    }

@app.get("/today-dashboard")
def today_dashboard():
    """
    Today dashboard prediction endpoint.
    This endpoint does not require user input.
    It automatically gets today's Sri Lanka date using UTC + 5:30,
    calculates the current ISO year/week, and returns a dashboard-friendly
    dengue risk prediction.
    """
    try:
        # Sri Lanka Time = UTC + 5 hours 30 minutes
        today = (datetime.utcnow() + timedelta(hours=5, minutes=30)).date()
        iso_calendar = today.isocalendar()

        current_year = int(iso_calendar.year)
        current_week = int(iso_calendar.week)
        current_month = int(today.month)

        input_df = build_historical_future_features(current_year, current_week)
        prediction, probability_output = get_prediction_response(input_df)

        confidence = 0.0
        if probability_output:
            confidence = max(probability_output.values())

        return {
            "date": today.isoformat(),
            "year": current_year,
            "week": current_week,
            "month": current_month,
            "risk_level": prediction,
            "risk_color": risk_color(prediction),
            "confidence": round(float(confidence), 2),
            "probabilities": probability_output,
            "top_reason": "Today's dengue risk update is generated using the current ISO week and historical seasonal dengue/weather patterns.",
            "recommendations": get_interventions_for_risk(prediction),
            "model_used": "Random Forest with Lag Features",
            "validation": "Future-Year Validation",
            "input_type": "today_dashboard_prediction_from_historical_seasonal_averages",
            "auto_generated_features": input_df.iloc[0].to_dict(),
            "important_note": "This endpoint uses today's Sri Lanka date, calculates the current epidemiological week, and automatically generates ML features using historical seasonal averages.",
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Today dashboard prediction failed: {str(e)}"
        )

@app.get("/trend/weekly-summary")
def weekly_trend_summary(weeks: int = 12):
    """
    Weekly trend analysis endpoint.
    This endpoint returns the latest 8-12 weeks of dengue and weather data
    for dashboard trend analysis charts.
    """
    if weeks < 1 or weeks > 52:
        raise HTTPException(
            status_code=400,
            detail="weeks must be between 1 and 52.",
        )

    required_trend_columns = [
        "year",
        "week",
        "month",
        "dengue_cases",
        "rainfall_mm",
        "humidity_pct",
        "temp_mean_c",
    ]

    missing_columns = [
        col for col in required_trend_columns
        if col not in history_df.columns
    ]

    if missing_columns:
        raise HTTPException(
            status_code=500,
            detail=f"Dataset is missing required trend columns: {missing_columns}",
        )

    trend_df = history_df[required_trend_columns].copy()
    trend_df = trend_df.sort_values(["year", "week"]).tail(weeks)

    trend_df = trend_df.fillna(0)

    weekly_summary = []

    for _, row in trend_df.iterrows():
        weekly_summary.append({
            "year": int(row["year"]),
            "week": int(row["week"]),
            "month": int(row["month"]),
            "label": f"{int(row['year'])}-W{int(row['week'])}",
            "dengue_cases": round(float(row["dengue_cases"]), 2),
            "rainfall_mm": round(float(row["rainfall_mm"]), 2),
            "humidity_pct": round(float(row["humidity_pct"]), 2),
            "temp_mean_c": round(float(row["temp_mean_c"]), 2),
        })

    return {
        "title": "Weekly Dengue and Weather Trend Summary",
        "district": "Colombo District",
        "weeks_returned": len(weekly_summary),
        "requested_weeks": weeks,
        "weekly_summary": weekly_summary,
        "chart_fields": {
            "x_axis": "label",
            "line_series": [
                "dengue_cases",
                "rainfall_mm",
                "humidity_pct",
                "temp_mean_c"
            ]
        },
        "important_note": "This endpoint returns the latest available weekly records from the uploaded historical dataset for trend analysis charts."
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


@app.get("/supported-future-weeks")
def supported_future_weeks():
    """
    Shows supported input format for future prediction.
    Since historical averages are used, any valid ISO week can be estimated.
    """
    return {
        "supported_input_format": {
            "year": "Any future year, e.g., 2026 or 2027",
            "week": "Valid ISO week number, usually 1-52 or 1-53 depending on the year",
        },
        "example_inputs": [
            {"year": 2026, "week": 40},
            {"year": 2026, "week": 45},
            {"year": 2027, "week": 10},
        ],
        "mode": "historical_seasonal_average_estimation",
    }