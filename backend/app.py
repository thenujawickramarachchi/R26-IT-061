from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from fastapi.middleware.cors import CORSMiddleware

import pandas as pd
import numpy as np
import joblib
import shap

import os
import json
import math
import urllib.error
import urllib.request

from functools import lru_cache
from threading import Lock
from datetime import date, timedelta, datetime
from zoneinfo import ZoneInfo
from supabase import create_client, Client
from typing import Dict


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="Colombo Dengue Outbreak Prediction API",
    description=(
        "Centralized dengue outbreak prediction, dashboard, "
        "SHAP explainability, RL intervention recommendation "
        "and PHI warning API."
    ),
    version="4.2.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# BASE PATHS
# ============================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_FILE = "colombo_dengue_rf_final_2022_2025.pkl"
DATA_FILE = "Colombo_Dengue_Model_Ready_2007_2026_Weather_Filled.csv"

MODEL_PATH = os.path.join(
    BASE_DIR,
    MODEL_FILE,
)

DATA_PATH = os.path.join(
    BASE_DIR,
    DATA_FILE,
)

# Final production model training window.
PRODUCTION_TRAIN_START_YEAR = 2022
PRODUCTION_TRAIN_END_YEAR = 2025

# Unseen future-year evaluation used before deployment.
EVALUATION_TRAIN_PERIOD = "2022-2024"
EVALUATION_TEST_PERIOD = "2025"
EVALUATION_ACCURACY = "86.54%"
EVALUATION_WEIGHTED_F1 = "84.31%"


# ============================================================
# SUPABASE CONFIGURATION
# ============================================================

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

_supabase_client = None


def get_supabase_client() -> Client:
    """
    Creates the Supabase client only when a database endpoint is used.
    This prevents the whole ML API from failing at startup when
    Supabase secrets have not yet been configured.
    """
    global _supabase_client

    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise HTTPException(
            status_code=503,
            detail=(
                "Supabase is not configured. Add SUPABASE_URL and "
                "SUPABASE_SERVICE_ROLE_KEY to Hugging Face Space Secrets."
            ),
        )

    if _supabase_client is None:
        try:
            _supabase_client = create_client(
                SUPABASE_URL,
                SUPABASE_SERVICE_ROLE_KEY,
            )
        except Exception as error:
            raise HTTPException(
                status_code=503,
                detail=f"Supabase connection failed: {str(error)}",
            )

    return _supabase_client


# ============================================================
# RL Q-TABLE CONFIGURATION
# ============================================================

Q_TABLE_FILE = os.getenv(
    "Q_TABLE_FILE",
    "q_table_real.npy",
)

Q_TABLE_PATH = os.path.join(
    BASE_DIR,
    Q_TABLE_FILE,
)

# Local/Hugging Face file storage is kept only as a cache/fallback.
# The production source of truth for learned Q-values is Supabase.
Q_TABLE_PERSIST_DIR = "/data"
Q_TABLE_PERSIST_PATH = (
    os.path.join(Q_TABLE_PERSIST_DIR, Q_TABLE_FILE)
    if os.path.isdir(Q_TABLE_PERSIST_DIR)
    and os.access(Q_TABLE_PERSIST_DIR, os.W_OK)
    else Q_TABLE_PATH
)

RL_Q_TABLE_STATE_TABLE = os.getenv(
    "RL_Q_TABLE_STATE_TABLE",
    "rl_q_table_state",
)
RL_Q_TABLE_STATE_ID = int(
    os.getenv("RL_Q_TABLE_STATE_ID", "1")
)

RL_LEARNING_RATE = float(
    os.getenv("RL_LEARNING_RATE", "0.10")
)
RL_DISCOUNT_FACTOR = float(
    os.getenv("RL_DISCOUNT_FACTOR", "0.90")
)
RL_REWARD_SCALE = float(
    os.getenv("RL_REWARD_SCALE", "10.0")
)

REQUIRE_RL_MODEL = (
    os.getenv("REQUIRE_RL_MODEL", "false")
    .strip()
    .lower()
    == "true"
)

_q_table_lock = Lock()

# ============================================================
# LOAD ML MODEL AND HISTORICAL DATASET
# ============================================================

if not os.path.exists(MODEL_PATH):
    raise RuntimeError(
        f"ML model file not found: {MODEL_FILE}"
    )

if not os.path.exists(DATA_PATH):
    raise RuntimeError(
        f"Historical dataset file not found: {DATA_FILE}"
    )

model = joblib.load(MODEL_PATH)
history_df = pd.read_csv(DATA_PATH)


# ============================================================
# LOAD RL Q-TABLE
# ============================================================

rl_q_table = None
rl_q_table_load_error = None
rl_q_table_source = None
rl_q_table_version = 0
rl_q_table_persistence_error = None


def validate_rl_q_table(table_data):
    table = np.asarray(table_data, dtype=float)

    if table.ndim != 4 or table.shape != (3, 3, 3, 5):
        raise RuntimeError(
            "Unexpected RL Q-table shape. "
            f"Expected (3, 3, 3, 5), got {table.shape}."
        )

    if not np.isfinite(table).all():
        raise RuntimeError(
            "RL Q-table contains non-finite numeric values."
        )

    return table


def try_load_rl_q_table_from_supabase():
    """
    Load the latest learned Q-table from permanent Supabase storage.

    Startup must remain safe for the existing ML endpoints, so database
    failures are returned as a soft error and local q_table_real.npy is
    used as a fallback.
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        return None, 0, "Supabase secrets are not configured."

    try:
        client = get_supabase_client()
        response = (
            client
            .table(RL_Q_TABLE_STATE_TABLE)
            .select("id,version,q_table,shape,updated_at")
            .eq("id", RL_Q_TABLE_STATE_ID)
            .limit(1)
            .execute()
        )

        if not response.data:
            return None, 0, None

        record = response.data[0]
        table = validate_rl_q_table(record.get("q_table"))
        version = int(record.get("version") or 0)

        return table, version, None

    except Exception as error:
        return None, 0, str(error)


def persist_rl_q_table_to_supabase(table, current_version: int):
    """
    Persist the complete Q-table as JSONB in Supabase.

    The row uses a fixed primary key so each successful feedback update
    replaces the previous production Q-table state while incrementing
    its version.
    """
    client = get_supabase_client()
    validated = validate_rl_q_table(table)
    new_version = int(current_version) + 1

    record = {
        "id": RL_Q_TABLE_STATE_ID,
        "version": new_version,
        "q_table": validated.tolist(),
        "shape": list(validated.shape),
        "updated_at": datetime.now(
            ZoneInfo("Asia/Colombo")
        ).isoformat(),
    }

    response = (
        client
        .table(RL_Q_TABLE_STATE_TABLE)
        .upsert(record)
        .execute()
    )

    if response.data is None:
        raise RuntimeError(
            "Supabase did not confirm the Q-table persistence operation."
        )

    return new_version


# Permanent Supabase state has priority after a Space restart/rebuild.
supabase_q_table, supabase_q_version, supabase_q_error = (
    try_load_rl_q_table_from_supabase()
)

if supabase_q_table is not None:
    rl_q_table = supabase_q_table
    rl_q_table_version = supabase_q_version
    rl_q_table_source = "supabase_persistent_state"
    print(
        "RL Q-table restored from Supabase: "
        f"version={rl_q_table_version} shape={rl_q_table.shape}"
    )

else:
    if supabase_q_error:
        rl_q_table_persistence_error = supabase_q_error
        print(
            "Supabase Q-table restore unavailable; "
            "using local Q-table fallback: "
            f"{supabase_q_error}"
        )

    try:
        load_path = (
            Q_TABLE_PERSIST_PATH
            if os.path.exists(Q_TABLE_PERSIST_PATH)
            else Q_TABLE_PATH
        )

        if not os.path.exists(load_path):
            raise FileNotFoundError(
                f"RL Q-table file not found: {Q_TABLE_FILE}"
            )

        rl_q_table = validate_rl_q_table(
            np.load(
                load_path,
                allow_pickle=True,
            )
        )
        rl_q_table_source = (
            "huggingface_persistent_storage_cache"
            if load_path.startswith("/data/")
            else "repository_q_table_seed"
        )

        print(
            "RL Q-table loaded from local fallback: "
            f"{load_path} shape={rl_q_table.shape}"
        )

    except Exception as error:
        rl_q_table_load_error = str(error)
        rl_q_table = None
        rl_q_table_source = None
        print(
            "RL Q-table could not be loaded. "
            "Fallback recommendations will remain available: "
            f"{error}"
        )

# ============================================================
# ML FEATURES
# ============================================================

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
    "outbreak_level",
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


# ============================================================
# SHAP FEATURE GROUPS
# ============================================================

SHAP_FEATURE_GROUPS = {

    "Rainfall": [
        "rainfall_mm",
        "rainfall_lag_1",
    ],

    "Humidity": [
        "humidity_pct",
        "humidity_lag_1",
    ],

    "Temperature": [
        "temp_max_c",
        "temp_min_c",
        "temp_mean_c",
    ],
}


SHAP_DISPLAY_VALUE_FEATURE = {
    "Rainfall": "rainfall_mm",
    "Humidity": "humidity_pct",
    "Temperature": "temp_mean_c",
}


# ============================================================
# VALIDATE DATASET
# ============================================================

missing_required = [
    col
    for col in REQUIRED_COLUMNS
    if col not in history_df.columns
]

if missing_required:

    raise RuntimeError(
        "Historical dataset is missing required columns: "
        f"{missing_required}"
    )


# ============================================================
# CLEAN HISTORICAL DATA
# ============================================================

history_df["year"] = pd.to_numeric(
    history_df["year"], errors="raise"
).astype(int)
history_df["week"] = pd.to_numeric(
    history_df["week"], errors="raise"
).astype(int)
history_df["month"] = pd.to_numeric(
    history_df["month"], errors="raise"
).astype(int)

NUMERIC_HISTORY_COLUMNS = [
    "dengue_cases",
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

for col in NUMERIC_HISTORY_COLUMNS:
    history_df[col] = pd.to_numeric(
        history_df[col],
        errors="coerce",
    )

if history_df[NUMERIC_HISTORY_COLUMNS].isna().any().any():
    missing_counts = (
        history_df[NUMERIC_HISTORY_COLUMNS]
        .isna()
        .sum()
    )
    missing_counts = missing_counts[missing_counts > 0].to_dict()
    raise RuntimeError(
        "Model-ready dataset contains missing/non-numeric values in "
        f"required numeric columns: {missing_counts}"
    )

history_df = history_df.sort_values(
    ["year", "week"]
).reset_index(drop=True)

# The production RF was trained on 2022-2025. Use the same recent
# period as the reference for automatically generated future features.
# This avoids overweighting 2007-2021 weather values that were imputed
# from 2022-2025 seasonal averages.
seasonal_reference_df = history_df[
    (history_df["year"] >= PRODUCTION_TRAIN_START_YEAR)
    & (history_df["year"] <= PRODUCTION_TRAIN_END_YEAR)
].copy()

if seasonal_reference_df.empty:
    raise RuntimeError(
        "No 2022-2025 rows are available for future-feature generation."
    )

# Extra safety check: ensure the loaded model expects the exact feature order.
if hasattr(model, "feature_names_in_"):
    loaded_model_features = list(model.feature_names_in_)
    if loaded_model_features != FEATURES:
        raise RuntimeError(
            "Loaded model feature order does not match API FEATURES. "
            f"Model expects {loaded_model_features}, API uses {FEATURES}."
        )


# ============================================================
# AREA PROXY RISK MODEL CONFIGURATION
# ============================================================

AREA_PROXY_MODEL_FILE = "best_area_proxy_model.pkl"
AREA_PROXY_METADATA_FILE = "best_area_proxy_model_metadata.json"
AREA_PROXY_DATA_FILE = (
    "Colombo_MOH_Area_Proxy_Context_Dataset_2015_2026_Final.csv"
)

AREA_PROXY_MODEL_PATH = os.path.join(
    BASE_DIR,
    AREA_PROXY_MODEL_FILE,
)

AREA_PROXY_METADATA_PATH = os.path.join(
    BASE_DIR,
    AREA_PROXY_METADATA_FILE,
)

AREA_PROXY_DATA_PATH = os.path.join(
    BASE_DIR,
    AREA_PROXY_DATA_FILE,
)

# Raw input feature order used during area model training.
# The saved artifact is the source of truth when feature_columns
# are available inside the .pkl file.
AREA_PROXY_DEFAULT_FEATURES = [
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
    "moh_area",
]

AREA_PROXY_NUMERIC_FEATURES = [
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

# Same-period/target-derived columns must never be passed to the
# area model. Lag features are intentionally allowed.
AREA_PROXY_FORBIDDEN_FEATURES = {
    "moh_dengue_cases",
    "moh_dengue_cases_proxy",
    "area_dengue_cases",
    "area_outbreak_level",
    "moh_outbreak_level_proxy",
    "dengue_cases",
}

# Keep this list separate from MOH_AREAS below. The existing MOH_AREAS
# list is already used by the RL / PHI workflow and must not be changed.
AREA_PROXY_MOH_AREAS = [
    "CMC",
    "Dehiwala",
    "Hanwella",
    "Homagama",
    "Kaduwela",
    "Kesbewa",
    "Kolonnawa",
    "Maharagama",
    "Moratuwa",
    "Padukka",
]

area_proxy_artifact = None
area_proxy_model = None
area_proxy_target_encoder = None
area_proxy_metadata = {}
area_proxy_df = None
area_proxy_feature_columns = AREA_PROXY_DEFAULT_FEATURES.copy()
area_proxy_load_error = None

try:
    if not os.path.exists(AREA_PROXY_MODEL_PATH):
        raise FileNotFoundError(
            f"Area proxy model file not found: {AREA_PROXY_MODEL_FILE}"
        )

    area_proxy_artifact = joblib.load(AREA_PROXY_MODEL_PATH)

    if isinstance(area_proxy_artifact, dict):
        area_proxy_model = area_proxy_artifact.get("model")
        area_proxy_target_encoder = area_proxy_artifact.get(
            "target_encoder"
        )

        saved_features = area_proxy_artifact.get("feature_columns")
        if saved_features:
            area_proxy_feature_columns = list(saved_features)
    else:
        # Backward-compatible fallback if a raw sklearn Pipeline
        # is saved instead of the artifact dictionary.
        area_proxy_model = area_proxy_artifact

    if area_proxy_model is None:
        raise RuntimeError(
            "Area proxy model could not be extracted from "
            f"{AREA_PROXY_MODEL_FILE}."
        )

    # Metadata is useful for metrics/methodology, but the model can
    # still operate if the JSON file is temporarily missing.
    if os.path.exists(AREA_PROXY_METADATA_PATH):
        with open(
            AREA_PROXY_METADATA_PATH,
            "r",
            encoding="utf-8",
        ) as metadata_file:
            area_proxy_metadata = json.load(metadata_file)
    else:
        print(
            "Area proxy metadata JSON not found. "
            "Documented fallback metrics will be used."
        )

    leakage_features = (
        set(area_proxy_feature_columns)
        & AREA_PROXY_FORBIDDEN_FEATURES
    )

    if leakage_features:
        raise RuntimeError(
            "Unsafe area proxy feature configuration. "
            "Direct leakage features found: "
            f"{sorted(leakage_features)}"
        )

    if "moh_area" not in area_proxy_feature_columns:
        raise RuntimeError(
            "Area proxy model feature list does not include moh_area."
        )

    if not os.path.exists(AREA_PROXY_DATA_PATH):
        raise FileNotFoundError(
            f"Area proxy dataset file not found: {AREA_PROXY_DATA_FILE}"
        )

    area_proxy_df = pd.read_csv(AREA_PROXY_DATA_PATH)

    required_area_columns = set(area_proxy_feature_columns) | {
        "year",
        "week",
        "month",
        "moh_area",
    }

    missing_area_columns = [
        column
        for column in required_area_columns
        if column not in area_proxy_df.columns
    ]

    if missing_area_columns:
        raise RuntimeError(
            "Area proxy dataset is missing required columns: "
            f"{missing_area_columns}"
        )

    area_proxy_df["moh_area"] = (
        area_proxy_df["moh_area"]
        .astype(str)
        .str.strip()
    )

    for column in AREA_PROXY_NUMERIC_FEATURES:
        if column in area_proxy_df.columns:
            area_proxy_df[column] = pd.to_numeric(
                area_proxy_df[column],
                errors="coerce",
            )

    required_numeric = [
        column
        for column in AREA_PROXY_NUMERIC_FEATURES
        if column in area_proxy_feature_columns
    ]

    if area_proxy_df[required_numeric].isna().any().any():
        missing_counts = (
            area_proxy_df[required_numeric]
            .isna()
            .sum()
        )
        missing_counts = missing_counts[
            missing_counts > 0
        ].to_dict()

        raise RuntimeError(
            "Area proxy dataset contains missing/non-numeric "
            "model features: "
            f"{missing_counts}"
        )

    duplicate_area_rows = area_proxy_df.duplicated(
        subset=["year", "week", "moh_area"]
    ).sum()

    if duplicate_area_rows:
        raise RuntimeError(
            "Area proxy dataset contains duplicate "
            "year-week-area rows: "
            f"{int(duplicate_area_rows)}"
        )

    # Additional safety: when sklearn exposes the raw input feature
    # names, require the API to use exactly the same order.
    if hasattr(area_proxy_model, "feature_names_in_"):
        loaded_area_features = list(
            area_proxy_model.feature_names_in_
        )
        if loaded_area_features != area_proxy_feature_columns:
            raise RuntimeError(
                "Loaded area proxy model feature order does not "
                "match saved feature_columns. "
                f"Model expects {loaded_area_features}, "
                f"artifact uses {area_proxy_feature_columns}."
            )

    print(
        "Area proxy Random Forest model loaded successfully: "
        f"{AREA_PROXY_MODEL_FILE}"
    )
    print(
        "Area proxy dataset loaded successfully: "
        f"{area_proxy_df.shape}"
    )
    print(
        "Area proxy input features: "
        f"{area_proxy_feature_columns}"
    )

except Exception as error:
    # Isolate failures in the new area model so the existing district
    # endpoints (especially /predict-future) can still start and work.
    area_proxy_load_error = str(error)
    area_proxy_model = None
    area_proxy_target_encoder = None
    area_proxy_df = None

    print(
        "Area proxy model initialization failed: "
        f"{area_proxy_load_error}"
    )


# ============================================================
# RL INTERVENTION CONFIGURATION
# ============================================================

RL_ACTIONS = [
    "Monitor Only",
    "Deploy Fumigation Teams",
    "Issue Public Health Alert",
    "Increase Hospital Readiness",
    "Community Cleanup Campaign",
]


MOH_AREAS = [
    "Colombo",
    "Dehiwala",
    "Moratuwa",
    "Kotte",
    "Kaduwela",
    "Kesbewa",
    "Kolonnawa",
    "Maharagama",
    "Homagama",
    "Avissawella",
]


# ============================================================
# REQUEST MODELS
# ============================================================

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


class AreaRiskInput(BaseModel):

    year: int = Field(
        ...,
        ge=2015,
        le=2100,
        examples=[2026],
    )

    week: int = Field(
        ...,
        ge=1,
        le=53,
        examples=[13],
    )

    area: str = Field(
        ...,
        min_length=1,
        examples=["Kaduwela"],
    )


class AreaRiskDataContext(BaseModel):

    dataset: str
    area_data_type: str
    moh_cases_source: str
    confidence_level: str


class AreaRiskResponse(BaseModel):

    year: int
    week: int
    area: str
    predicted_area_risk_level: str
    probabilities: Dict[str, float]
    model_used: str
    validation: str
    model_accuracy: float
    weighted_f1: float
    future_proxy_check_accuracy: float
    future_proxy_check_weighted_f1: float
    input_type: str
    important_note: str
    data_context: AreaRiskDataContext
    methodology_note: str


class InterventionInput(BaseModel):

    area: str
    cases: int
    rainfall: float
    temperature: float


class FeedbackInput(BaseModel):

    warning_history_id: int = Field(..., gt=0)
    cases_after: int = Field(..., ge=0)
    follow_up_days: int = Field(14, gt=0)
    outcome_status: str = Field(..., min_length=1)
    feedback_notes: str = ""


# ============================================================
# GENERAL HELPERS
# ============================================================

def to_dict(data):

    if hasattr(data, "model_dump"):
        return data.model_dump()

    return data.dict()


def get_month_from_year_week(
    year: int,
    week: int,
) -> int:

    try:

        return date.fromisocalendar(
            year,
            week,
            1,
        ).month

    except ValueError:

        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid year/week. "
                "Please enter a valid ISO week number."
            ),
        )


def get_previous_year_week(
    year: int,
    week: int,
    offset: int,
):

    try:

        current_week_date = date.fromisocalendar(
            year,
            week,
            1,
        )

    except ValueError:

        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid year/week. "
                "Please enter a valid ISO week number."
            ),
        )

    previous_date = (
        current_week_date
        - timedelta(weeks=offset)
    )

    previous_iso = previous_date.isocalendar()

    return (
        int(previous_iso.year),
        int(previous_iso.week),
    )


# ============================================================
# HISTORICAL DATA WITH LAGS
# ============================================================

def prepare_history_with_lags():
    """
    Return the model-ready historical dataset using the lag columns
    already stored in the uploaded CSV.

    The new model-ready dataset was created with lag features before
    training, so recomputing them here could alter the first available
    rows and make API inputs inconsistent with model training.
    """
    df = history_df.copy()

    df = df.sort_values(
        ["year", "week"]
    ).reset_index(drop=True)

    return df


def historical_average_for_week_or_month(
    column: str,
    week: int,
    month: int,
) -> float:
    """
    Generate seasonal reference values from the same 2022-2025 period
    used to train the final production model.
    """
    if column not in seasonal_reference_df.columns:
        raise RuntimeError(
            f"Seasonal reference column not found: {column}"
        )

    same_week = seasonal_reference_df[
        seasonal_reference_df["week"] == week
    ]

    if (
        not same_week.empty
        and same_week[column].notna().any()
    ):
        return float(
            same_week[column].mean()
        )

    same_month = seasonal_reference_df[
        seasonal_reference_df["month"] == month
    ]

    if (
        not same_month.empty
        and same_month[column].notna().any()
    ):
        return float(
            same_month[column].mean()
        )

    return float(
        seasonal_reference_df[column].mean()
    )


# ============================================================
# FUTURE FEATURE GENERATION
# ============================================================

def build_historical_future_features(
    year: int,
    week: int,
) -> pd.DataFrame:

    month = get_month_from_year_week(
        year,
        week,
    )

    prev1_year, prev1_week = (
        get_previous_year_week(
            year,
            week,
            offset=1,
        )
    )

    prev2_year, prev2_week = (
        get_previous_year_week(
            year,
            week,
            offset=2,
        )
    )

    prev1_month = get_month_from_year_week(
        prev1_year,
        prev1_week,
    )

    prev2_month = get_month_from_year_week(
        prev2_year,
        prev2_week,
    )

    rainfall_mm = (
        historical_average_for_week_or_month(
            "rainfall_mm",
            week,
            month,
        )
    )

    humidity_pct = (
        historical_average_for_week_or_month(
            "humidity_pct",
            week,
            month,
        )
    )

    temp_max_c = (
        historical_average_for_week_or_month(
            "temp_max_c",
            week,
            month,
        )
    )

    temp_min_c = (
        historical_average_for_week_or_month(
            "temp_min_c",
            week,
            month,
        )
    )

    temp_mean_c = (
        historical_average_for_week_or_month(
            "temp_mean_c",
            week,
            month,
        )
    )

    dengue_lag_1 = (
        historical_average_for_week_or_month(
            "dengue_cases",
            prev1_week,
            prev1_month,
        )
    )

    dengue_lag_2 = (
        historical_average_for_week_or_month(
            "dengue_cases",
            prev2_week,
            prev2_month,
        )
    )

    rainfall_lag_1 = (
        historical_average_for_week_or_month(
            "rainfall_mm",
            prev1_week,
            prev1_month,
        )
    )

    humidity_lag_1 = (
        historical_average_for_week_or_month(
            "humidity_pct",
            prev1_week,
            prev1_month,
        )
    )

    input_df = pd.DataFrame(
        [
            {
                "year": int(year),
                "week": int(week),
                "month": int(month),

                "rainfall_mm": round(
                    rainfall_mm,
                    2,
                ),

                "humidity_pct": round(
                    humidity_pct,
                    2,
                ),

                "temp_max_c": round(
                    temp_max_c,
                    2,
                ),

                "temp_min_c": round(
                    temp_min_c,
                    2,
                ),

                "temp_mean_c": round(
                    temp_mean_c,
                    2,
                ),

                "dengue_lag_1": round(
                    dengue_lag_1,
                    2,
                ),

                "dengue_lag_2": round(
                    dengue_lag_2,
                    2,
                ),

                "rainfall_lag_1": round(
                    rainfall_lag_1,
                    2,
                ),

                "humidity_lag_1": round(
                    humidity_lag_1,
                    2,
                ),
            }
        ]
    )

    return input_df[FEATURES]


# ============================================================
# ML PREDICTION HELPERS
# ============================================================

def get_probability_output(
    input_df: pd.DataFrame,
):

    if not hasattr(
        model,
        "predict_proba",
    ):
        return None

    probabilities = (
        model.predict_proba(input_df)[0]
    )

    return {
        str(class_name): round(
            float(probability) * 100,
            2,
        )

        for class_name, probability
        in zip(
            model.classes_,
            probabilities,
        )
    }


def get_prediction_response(
    input_df: pd.DataFrame,
):

    prediction = model.predict(
        input_df
    )[0]

    probability_output = (
        get_probability_output(
            input_df
        )
    )

    return (
        str(prediction),
        probability_output,
    )


# ============================================================
# AREA PROXY MODEL HELPERS
# ============================================================

def resolve_area_proxy_model_area(
    area: str,
) -> str:
    """Map a canonical database area to the closest model input label.

    Colombo/CMC is an explicit naming alias. Other unseen canonical
    areas are intentionally left unchanged; the saved OneHotEncoder
    uses handle_unknown="ignore", and historical numeric context is
    estimated from the broader proxy dataset with a clear methodology
    note rather than inventing an unsupported area-to-area mapping.
    """

    cleaned_area = " ".join(area.strip().split())

    area_lookup = {
        valid_area.casefold(): valid_area
        for valid_area in AREA_PROXY_MOH_AREAS
    }

    if cleaned_area.casefold() in area_lookup:
        return area_lookup[cleaned_area.casefold()]

    if cleaned_area.casefold() in {"colombo", "cmc", "cmu"}:
        return "CMC"

    return cleaned_area


def build_area_proxy_features(
    year: int,
    week: int,
    area: str,
):
    """Build the raw feature frame expected by the saved area pipeline.

    Exact trained-area rows are preferred. Missing future rows are
    estimated from earlier same-area patterns. If a canonical Supabase
    area was not one of the 10 proxy-model training categories, numeric
    context is estimated from earlier all-area proxy rows while the area
    label is passed through the encoder as an unseen category. This is
    still only proxy/context output, never official MOH surveillance.
    """

    if area_proxy_df is None:
        raise HTTPException(
            status_code=503,
            detail="Area proxy dataset is currently unavailable.",
        )

    month = get_month_from_year_week(year, week)
    model_area = resolve_area_proxy_model_area(area)

    selected_row = area_proxy_df[
        (area_proxy_df["year"] == year)
        & (area_proxy_df["week"] == week)
        & (
            area_proxy_df["moh_area"].str.casefold()
            == model_area.casefold()
        )
    ]

    if not selected_row.empty:
        row = selected_row.iloc[0]
        feature_values = {
            "year": int(year),
            "week": int(week),
            "month": int(month),
            "moh_area": model_area,
        }

        for feature in area_proxy_feature_columns:
            if feature in {"year", "week", "month", "moh_area"}:
                continue
            feature_values[feature] = float(row[feature])

        input_df = pd.DataFrame([feature_values])[
            area_proxy_feature_columns
        ]

        return (
            input_df,
            "area_proxy_prediction",
            "exact_proxy_context_row",
        )

    historical_area = area_proxy_df[
        (
            area_proxy_df["moh_area"].str.casefold()
            == model_area.casefold()
        )
        & (area_proxy_df["year"] < year)
    ].copy()

    unseen_area = historical_area.empty

    if unseen_area:
        historical_area = area_proxy_df[
            area_proxy_df["year"] < year
        ].copy()

    if historical_area.empty:
        raise HTTPException(
            status_code=404,
            detail=(
                "No earlier proxy/context records are available "
                f"before {year}."
            ),
        )

    reference_rows = historical_area[
        historical_area["week"] == week
    ].copy()

    if unseen_area:
        estimation_basis = (
            "historical_same_week_all_area_average_unseen_area"
        )
    else:
        estimation_basis = "historical_same_week_area_average"

    if reference_rows.empty:
        reference_rows = historical_area[
            historical_area["month"] == month
        ].copy()
        estimation_basis = (
            "historical_same_month_all_area_average_unseen_area"
            if unseen_area
            else "historical_same_month_area_average"
        )

    if reference_rows.empty:
        reference_rows = historical_area.copy()
        estimation_basis = (
            "historical_all_area_average_unseen_area"
            if unseen_area
            else "historical_area_average"
        )

    feature_values = {
        "year": int(year),
        "week": int(week),
        "month": int(month),
        "moh_area": model_area,
    }

    for feature in area_proxy_feature_columns:
        if feature in {"year", "week", "month", "moh_area"}:
            continue

        values = pd.to_numeric(
            reference_rows[feature],
            errors="coerce",
        ).dropna()

        if values.empty:
            values = pd.to_numeric(
                historical_area[feature],
                errors="coerce",
            ).dropna()

        if values.empty:
            raise HTTPException(
                status_code=500,
                detail=(
                    "Unable to estimate required area "
                    f"model feature: {feature}"
                ),
            )

        feature_values[feature] = float(values.mean())

    input_df = pd.DataFrame([feature_values])[
        area_proxy_feature_columns
    ]

    return (
        input_df,
        "historical_area_proxy_estimation",
        estimation_basis,
    )



def decode_area_proxy_class(
    raw_class,
) -> str:

    if area_proxy_target_encoder is not None:
        try:
            decoded = (
                area_proxy_target_encoder
                .inverse_transform(
                    [int(raw_class)]
                )[0]
            )
            return str(decoded)
        except Exception:
            pass

    target_mapping = area_proxy_metadata.get(
        "target_encoding",
        {},
    )

    try:
        mapping_key = str(int(raw_class))
    except Exception:
        mapping_key = str(raw_class)

    if mapping_key in target_mapping:
        return str(
            target_mapping[mapping_key]
        )

    # If a future artifact already outputs string labels,
    # this is the correct fallback.
    return str(raw_class)


def predict_area_proxy(
    input_df: pd.DataFrame,
):

    if area_proxy_model is None:
        raise HTTPException(
            status_code=503,
            detail={
                "message": (
                    "Area proxy prediction model is currently "
                    "unavailable."
                ),
                "load_error": area_proxy_load_error,
            },
        )

    raw_prediction = area_proxy_model.predict(
        input_df
    )[0]

    predicted_level = decode_area_proxy_class(
        raw_prediction
    )

    if not hasattr(
        area_proxy_model,
        "predict_proba",
    ):
        raise HTTPException(
            status_code=500,
            detail=(
                "Loaded area proxy model does not support "
                "probability prediction."
            ),
        )

    probability_values = (
        area_proxy_model.predict_proba(
            input_df
        )[0]
    )

    model_classes = getattr(
        area_proxy_model,
        "classes_",
        None,
    )

    if model_classes is None:
        if not hasattr(area_proxy_model, "named_steps"):
            raise HTTPException(
                status_code=500,
                detail=(
                    "Unable to determine area model classes."
                ),
            )

        classifier = area_proxy_model.named_steps.get(
            "classifier"
        )

        if classifier is None or not hasattr(
            classifier,
            "classes_",
        ):
            raise HTTPException(
                status_code=500,
                detail=(
                    "Unable to determine area model classes."
                ),
            )

        model_classes = classifier.classes_

    probability_output = {
        "High": 0.0,
        "Medium": 0.0,
        "Low": 0.0,
    }

    for raw_class, probability in zip(
        model_classes,
        probability_values,
    ):
        class_name = decode_area_proxy_class(
            raw_class
        )

        probability_output[class_name] = round(
            float(probability) * 100,
            2,
        )

    return (
        predicted_level,
        probability_output,
    )


def get_area_metadata_percent(
    keys,
    default_percentage: float,
) -> float:

    current_value = area_proxy_metadata

    try:
        for key in keys:
            current_value = current_value[key]

        numeric_value = float(current_value)

        # Colab metadata stores metrics as fractions such as 0.8635.
        if numeric_value <= 1.0:
            numeric_value *= 100

        return round(
            numeric_value,
            2,
        )

    except Exception:
        return round(
            default_percentage,
            2,
        )


def risk_color(
    risk: str,
) -> str:

    return {
        "High": "#E53935",
        "Medium": "#FB8C00",
        "Low": "#43A047",
    }.get(
        risk,
        "#607D8B",
    )


# ============================================================
# DASHBOARD INTERVENTIONS
# ============================================================

def get_interventions_for_risk(
    risk: str,
):

    if risk == "High":

        return [
            {
                "title": "Urgent MOH field inspection",
                "priority": "Critical",
                "confidence": 0.92,
                "reason": (
                    "High outbreak risk detected from "
                    "historical dengue and climate patterns."
                ),
            },
            {
                "title": "Source reduction within 24 hours",
                "priority": "Critical",
                "confidence": 0.89,
                "reason": (
                    "Remove stagnant-water breeding sites "
                    "before the next transmission cycle."
                ),
            },
            {
                "title": "Targeted public health alert",
                "priority": "High",
                "confidence": 0.86,
                "reason": (
                    "Notify households, schools, "
                    "and high-risk locations."
                ),
            },
        ]

    if risk == "Medium":

        return [
            {
                "title": "Increase surveillance frequency",
                "priority": "High",
                "confidence": 0.84,
                "reason": (
                    "Medium outbreak risk detected from "
                    "seasonal dengue and climate patterns."
                ),
            },
            {
                "title": "Community cleanup campaign",
                "priority": "Medium",
                "confidence": 0.80,
                "reason": (
                    "Reduce mosquito breeding sites "
                    "before risk increases."
                ),
            },
            {
                "title": "Monitor climate triggers",
                "priority": "Medium",
                "confidence": 0.76,
                "reason": (
                    "Monitor rainfall, humidity, "
                    "and temperature changes."
                ),
            },
        ]

    return [
        {
            "title": "Routine monitoring",
            "priority": "Normal",
            "confidence": 0.78,
            "reason": (
                "Current pattern is within "
                "the low-risk range."
            ),
        },
        {
            "title": "Maintain public awareness",
            "priority": "Normal",
            "confidence": 0.72,
            "reason": (
                "Continue dengue prevention "
                "awareness activities."
            ),
        },
    ]


# ============================================================
# SHAP HELPERS
# ============================================================

@lru_cache(maxsize=1)
def get_shap_explainer():

    try:

        return shap.TreeExplainer(model)

    except Exception as error:

        raise RuntimeError(
            f"Unable to initialize SHAP explainer: {error}"
        )


def get_all_class_shap_values(
    input_df: pd.DataFrame,
):

    explainer = get_shap_explainer()

    raw_shap_values = (
        explainer.shap_values(
            input_df
        )
    )

    # Older SHAP versions
    if isinstance(
        raw_shap_values,
        list,
    ):

        arrays = [
            np.asarray(
                class_values
            )
            for class_values
            in raw_shap_values
        ]

        return np.stack(
            arrays,
            axis=-1,
        )

    shap_array = np.asarray(
        raw_shap_values
    )

    # Single output
    if shap_array.ndim == 2:

        return shap_array[
            :,
            :,
            np.newaxis,
        ]

    # Multiclass
    if shap_array.ndim == 3:

        number_of_classes = len(
            model.classes_
        )

        # Newer SHAP:
        # samples x features x classes
        if (
            shap_array.shape[-1]
            == number_of_classes
        ):

            return shap_array

        # Alternative:
        # classes x samples x features
        if (
            shap_array.shape[0]
            == number_of_classes
        ):

            return np.moveaxis(
                shap_array,
                0,
                -1,
            )

    raise RuntimeError(
        "Unsupported SHAP output shape: "
        f"{shap_array.shape}"
    )


def get_model_class_index(
    prediction: str,
):

    classes = [
        str(class_name)
        for class_name
        in model.classes_
    ]

    try:

        return classes.index(
            str(prediction)
        )

    except ValueError:

        raise RuntimeError(
            f"Predicted class {prediction} "
            f"not found in model classes {classes}"
        )


def calculate_local_grouped_shap(
    input_df: pd.DataFrame,
    prediction: str,
):

    all_shap_values = (
        get_all_class_shap_values(
            input_df
        )
    )

    class_index = (
        get_model_class_index(
            prediction
        )
    )

    class_shap_values = (
        all_shap_values[
            0,
            :,
            class_index,
        ]
    )

    feature_positions = {
        feature: index
        for index, feature
        in enumerate(FEATURES)
    }

    local_results = []

    for (
        display_name,
        feature_names,
    ) in SHAP_FEATURE_GROUPS.items():

        grouped_shap_value = 0.0

        for feature_name in feature_names:

            if (
                feature_name
                in feature_positions
            ):

                feature_index = (
                    feature_positions[
                        feature_name
                    ]
                )

                grouped_shap_value += float(
                    class_shap_values[
                        feature_index
                    ]
                )

        display_feature = (
            SHAP_DISPLAY_VALUE_FEATURE[
                display_name
            ]
        )

        display_value = float(
            input_df.iloc[0][
                display_feature
            ]
        )

        local_results.append(
            {
                "feature": display_name,

                "value": round(
                    display_value,
                    2,
                ),

                "shap_value": round(
                    grouped_shap_value,
                    4,
                ),
            }
        )

    local_results = sorted(
        local_results,
        key=lambda item: abs(
            item["shap_value"]
        ),
        reverse=True,
    )

    return local_results


@lru_cache(maxsize=1)
def calculate_global_grouped_shap():

    df = prepare_history_with_lags()

    input_df = df[
        FEATURES
    ].copy()

    all_shap_values = (
        get_all_class_shap_values(
            input_df
        )
    )

    # mean absolute SHAP over:
    # records + model classes
    feature_importance = np.mean(
        np.abs(
            all_shap_values
        ),
        axis=(0, 2),
    )

    feature_positions = {
        feature: index
        for index, feature
        in enumerate(FEATURES)
    }

    global_results = []

    for (
        display_name,
        feature_names,
    ) in SHAP_FEATURE_GROUPS.items():

        grouped_importance = 0.0

        for feature_name in feature_names:

            if (
                feature_name
                in feature_positions
            ):

                feature_index = (
                    feature_positions[
                        feature_name
                    ]
                )

                grouped_importance += float(
                    feature_importance[
                        feature_index
                    ]
                )

        global_results.append(
            {
                "feature": display_name,

                "importance": round(
                    grouped_importance,
                    4,
                ),
            }
        )

    global_results = sorted(
        global_results,
        key=lambda item: item[
            "importance"
        ],
        reverse=True,
    )

    return global_results


# ============================================================
# RL RISK ASSESSMENT
# ============================================================

@lru_cache(maxsize=1)
def get_rl_case_thresholds():
    """Derive practical weekly case bands from the proxy/context dataset.

    The old prototype values 1500/5000 are intentionally not used.
    When labelled proxy case data are available, class medians are used
    to derive LOW/MEDIUM and MEDIUM/HIGH cut-points. A quantile fallback
    is used only if those columns are unavailable.
    """

    fallback = (10.0, 25.0)

    if area_proxy_df is None:
        return fallback

    case_column = None
    for candidate in (
        "moh_dengue_cases_proxy",
        "moh_dengue_cases",
        "area_dengue_cases",
    ):
        if candidate in area_proxy_df.columns:
            case_column = candidate
            break

    if case_column is None:
        return fallback

    cases = pd.to_numeric(
        area_proxy_df[case_column],
        errors="coerce",
    )

    valid = cases.dropna()
    if valid.empty:
        return fallback

    if "area_outbreak_level" in area_proxy_df.columns:
        calibration_df = pd.DataFrame(
            {
                "cases": cases,
                "level": area_proxy_df["area_outbreak_level"]
                .astype(str)
                .str.strip()
                .str.casefold(),
            }
        ).dropna()

        medians = calibration_df.groupby("level")["cases"].median()

        if all(
            level in medians.index
            for level in ("low", "medium", "high")
        ):
            low_median = float(medians["low"])
            medium_median = float(medians["medium"])
            high_median = float(medians["high"])

            medium_threshold = max(
                1.0,
                (low_median + medium_median) / 2.0,
            )
            high_threshold = max(
                medium_threshold + 1.0,
                (medium_median + high_median) / 2.0,
            )

            return (
                round(medium_threshold, 2),
                round(high_threshold, 2),
            )

    medium_threshold = float(valid.quantile(0.50))
    high_threshold = float(valid.quantile(0.80))

    if high_threshold <= medium_threshold:
        high_threshold = medium_threshold + 1.0

    return (
        round(max(1.0, medium_threshold), 2),
        round(max(2.0, high_threshold), 2),
    )


def build_rl_state(
    data: InterventionInput,
):
    medium_case_threshold, high_case_threshold = (
        get_rl_case_thresholds()
    )

    if data.cases < medium_case_threshold:
        case_level = 0
    elif data.cases < high_case_threshold:
        case_level = 1
    else:
        case_level = 2

    # Preserve the rainfall/temperature state definitions used by the
    # supplied q_table_real.npy implementation.
    if data.rainfall < 10:
        rainfall_level = 0
    elif data.rainfall < 20:
        rainfall_level = 1
    else:
        rainfall_level = 2

    if data.temperature < 26:
        temperature_level = 0
    elif data.temperature < 30:
        temperature_level = 1
    else:
        temperature_level = 2

    return (
        case_level,
        rainfall_level,
        temperature_level,
    )


def determine_intervention_risk(
    cases: int,
    rainfall: float,
    temperature: float,
) -> str:
    data = InterventionInput(
        area="calibration",
        cases=cases,
        rainfall=rainfall,
        temperature=temperature,
    )

    case_level, rainfall_level, temperature_level = (
        build_rl_state(data)
    )

    # Weekly cases are the primary signal. Rainfall and the favourable
    # 26-30 C temperature band can escalate an otherwise lower state.
    if case_level == 2:
        return "HIGH"

    favourable_temperature = temperature_level == 1
    heavy_rainfall = rainfall_level == 2

    if case_level == 1:
        if heavy_rainfall and favourable_temperature:
            return "HIGH"
        return "MEDIUM"

    if heavy_rainfall and favourable_temperature:
        return "MEDIUM"

    return "LOW"


def get_q_learning_values(
    data: InterventionInput,
    risk_level: str,
):
    del risk_level  # Risk label is not used to index the numeric Q-table.

    if rl_q_table is None:
        return None

    try:
        case_level, rainfall_level, temperature_level = (
            build_rl_state(data)
        )

        q_values = np.asarray(
            rl_q_table[
                case_level,
                rainfall_level,
                temperature_level,
            ],
            dtype=float,
        ).flatten()

        if len(q_values) < len(RL_ACTIONS):
            return None

        return {
            action: float(q_values[index])
            for index, action in enumerate(RL_ACTIONS)
        }

    except Exception as error:
        print("RL Q-table lookup failed:", error)
        return None


def rank_q_learning_actions(
    q_values,
):
    if not q_values:
        return []

    values = np.asarray(
        [float(q_values.get(action, 0.0)) for action in RL_ACTIONS],
        dtype=float,
    )

    sorted_indices = np.argsort(values)[::-1]
    shifted = values - np.min(values)

    if float(np.sum(shifted)) == 0.0:
        probabilities = np.ones(len(values)) / len(values)
    else:
        probabilities = shifted / np.sum(shifted)

    recommendations = []

    for rank, action_index in enumerate(
        sorted_indices[:3],
        start=1,
    ):
        action_index = int(action_index)
        recommendations.append(
            {
                "rank": rank,
                "action": RL_ACTIONS[action_index],
                "confidence": round(
                    float(probabilities[action_index] * 100),
                    1,
                ),
                "q_value": round(float(values[action_index]), 6),
            }
        )

    return recommendations


def fallback_recommendations(
    risk_level: str,
):
    if risk_level == "HIGH":
        return [
            {
                "rank": 1,
                "action": "Deploy Fumigation Teams",
                "confidence": 89.9,
            },
            {
                "rank": 2,
                "action": "Issue Public Health Alert",
                "confidence": 6.3,
            },
            {
                "rank": 3,
                "action": "Community Cleanup Campaign",
                "confidence": 1.9,
            },
        ]

    if risk_level == "MEDIUM":
        return [
            {
                "rank": 1,
                "action": "Community Cleanup Campaign",
                "confidence": 62.5,
            },
            {
                "rank": 2,
                "action": "Issue Public Health Alert",
                "confidence": 24.0,
            },
            {
                "rank": 3,
                "action": "Monitor Only",
                "confidence": 13.5,
            },
        ]

    return [
        {
            "rank": 1,
            "action": "Monitor Only",
            "confidence": 75.0,
        },
        {
            "rank": 2,
            "action": "Community Cleanup Campaign",
            "confidence": 18.0,
        },
        {
            "rank": 3,
            "action": "Increase Hospital Readiness",
            "confidence": 7.0,
        },
    ]


def get_risk_interpretation(
    risk_level: str,
    area: str,
):
    if risk_level == "HIGH":
        return f"High dengue intervention risk detected in {area}."

    if risk_level == "MEDIUM":
        return f"Moderate dengue intervention risk detected in {area}."

    return f"Low dengue intervention risk detected in {area}."


def get_recommendation_explanation(
    risk_level: str,
):
    medium_threshold, high_threshold = get_rl_case_thresholds()

    return (
        f"Risk is based on weekly MOH-area cases using dataset-calibrated "
        f"case bands (medium from about {medium_threshold:g} cases, high "
        f"from about {high_threshold:g} cases), with rainfall and temperature "
        f"used in the operational state. The intervention ranking is selected "
        f"from q_table_real.npy when available. Current risk: {risk_level}."
    )

# ============================================================
# SUPABASE MOH / PHI / WARNING HELPERS
# ============================================================

MOH_AREA_NAME_COLUMNS = [
    "name",
    "area_name",
    "moh_area_name",
]


def get_all_moh_area_records():
    client = get_supabase_client()

    try:
        response = (
            client
            .table("moh_areas")
            .select("*")
            .execute()
        )
        return response.data or []

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to query moh_areas: {str(error)}",
        )


def detect_moh_area_name_column(records):
    for column_name in MOH_AREA_NAME_COLUMNS:
        if any(column_name in record for record in records):
            return column_name

    return None


def find_moh_area(area_name: str):
    area_name = area_name.strip()

    if not area_name:
        raise HTTPException(
            status_code=400,
            detail="Area cannot be empty.",
        )

    records = get_all_moh_area_records()

    if not records:
        raise HTTPException(
            status_code=404,
            detail="No MOH areas were found in Supabase.",
        )

    name_column = detect_moh_area_name_column(records)

    if not name_column:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to identify the MOH area name column. "
                "Expected one of: name, area_name, moh_area_name."
            ),
        )

    normalized_area = area_name.casefold()

    for record in records:
        saved_name = str(record.get(name_column, "")).strip()

        if saved_name.casefold() == normalized_area:
            return {
                "id": record.get("id"),
                "name": saved_name,
                "name_column": name_column,
                "record": record,
            }

    raise HTTPException(
        status_code=404,
        detail=f"MOH area '{area_name}' was not found.",
    )


def find_active_phi_officer(moh_area_id):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("phi_officers")
            .select(
                "id,"
                "full_name,"
                "email,"
                "phone_number,"
                "moh_area_id,"
                "is_active,"
                "auth_user_id,"
                "created_at"
            )
            .eq("moh_area_id", moh_area_id)
            .eq("is_active", True)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to query PHI officers: {str(error)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail=(
                "No active PHI officer was found for the selected MOH area."
            ),
        )

    officer = response.data[0]

    if not officer.get("email"):
        raise HTTPException(
            status_code=400,
            detail=(
                "The active PHI officer does not have an email address."
            ),
        )

    return officer


def get_top_intervention_action(
    data: InterventionInput,
    risk_level: str,
):
    q_values = get_q_learning_values(
        data,
        risk_level,
    )

    if q_values:
        recommendations = rank_q_learning_actions(
            q_values
        )
    else:
        recommendations = fallback_recommendations(
            risk_level
        )

    if recommendations:
        return recommendations[0]["action"]

    return "Monitor Only"


def send_phi_warning_email(
    data: InterventionInput,
    risk_level: str,
    recipient_email: str,
):
    """
    Send a HIGH-risk PHI warning through the Resend HTTPS API.

    Required Hugging Face Space Secrets:
      - RESEND_API_KEY
      - EMAIL_FROM

    Example testing sender:
      Vector Shield <onboarding@resend.dev>

    Production sender example after verifying a domain in Resend:
      Vector Shield <alerts@verified-domain.com>

    The API key is never returned or logged.
    """
    provider = "resend_https_api"
    recipient = str(recipient_email or "").strip()

    resend_api_key = os.getenv("RESEND_API_KEY", "").strip()
    email_from = os.getenv("EMAIL_FROM", "").strip()
    resend_api_url = os.getenv(
        "RESEND_API_URL",
        "https://api.resend.com/emails",
    ).strip()

    base_result = {
        "provider": provider,
        "from_email": email_from or None,
        "recipient": recipient or None,
        "provider_message_id": None,
    }

    if risk_level != "HIGH":
        return {
            **base_result,
            "sent": False,
            "message": (
                "No warning email sent because "
                f"risk level is {risk_level}."
            ),
        }

    if not resend_api_key or not email_from:
        return {
            **base_result,
            "sent": False,
            "message": (
                "HTTPS email configuration is incomplete. "
                "Add RESEND_API_KEY and EMAIL_FROM to Hugging Face "
                "Space Secrets."
            ),
            "provider_error_message": (
                "Missing RESEND_API_KEY or EMAIL_FROM."
            ),
        }

    if not recipient:
        return {
            **base_result,
            "sent": False,
            "message": "The PHI officer does not have a valid email address.",
            "provider_error_message": "Recipient email is empty.",
        }

    subject = f"HIGH Dengue Risk Warning - {data.area}"
    text_body = f"""
DENGUE HIGH-RISK WARNING

Area: {data.area}
Risk Level: {risk_level}
Dengue Cases: {data.cases}
Rainfall: {data.rainfall} mm
Temperature: {data.temperature} °C

A HIGH dengue outbreak risk has been detected.

Please review the current dengue situation and take the appropriate
public health intervention.

This warning was generated by the Dengue Intervention Optimization System.
""".strip()

    payload = {
        "from": email_from,
        "to": [recipient],
        "subject": subject,
        "text": text_body,
    }

    request = urllib.request.Request(
        resend_api_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {resend_api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "colombo-dengue-api/4.2",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=20,
        ) as response:
            status_code = int(response.getcode())
            response_body = response.read().decode(
                "utf-8",
                errors="replace",
            )

        decoded_response = None
        try:
            decoded_response = json.loads(response_body)
        except Exception:
            decoded_response = None

        # urllib normally raises HTTPError for 4xx/5xx responses,
        # but keep this guard for completeness.
        if status_code < 200 or status_code >= 300:
            provider_error_type = None
            provider_error_message = None

            if isinstance(decoded_response, dict):
                provider_error_type = (
                    decoded_response.get("name")
                    or decoded_response.get("error")
                )
                provider_error_message = decoded_response.get("message")

            print(
                "PHI Resend non-2xx response:",
                {
                    "status": status_code,
                    "from": email_from,
                    "to": recipient,
                    "error_type": provider_error_type,
                    "error_message": provider_error_message,
                    "body": response_body[:2000],
                },
            )

            return {
                **base_result,
                "sent": False,
                "message": (
                    "High-risk warning was detected, but the email "
                    "provider rejected the request."
                ),
                "provider_status": status_code,
                "provider_error_type": provider_error_type,
                "provider_error_message": provider_error_message,
                "provider_response_body": response_body,
            }

        provider_message_id = None
        if isinstance(decoded_response, dict):
            provider_message_id = decoded_response.get("id")

        return {
            **base_result,
            "sent": True,
            "message": "High-risk warning sent successfully.",
            "provider_status": status_code,
            "provider_message_id": provider_message_id,
        }

    except urllib.error.HTTPError as error:
        try:
            provider_response_body = error.read().decode(
                "utf-8",
                errors="replace",
            )
        except Exception:
            provider_response_body = ""

        provider_error_type = None
        provider_error_message = None

        try:
            decoded_error = json.loads(provider_response_body)
            if isinstance(decoded_error, dict):
                provider_error_type = (
                    decoded_error.get("name")
                    or decoded_error.get("error")
                )
                provider_error_message = decoded_error.get("message")
        except Exception:
            decoded_error = None

        if not provider_error_message and provider_response_body:
            provider_error_message = provider_response_body

        print(
            "PHI Resend HTTP error:",
            {
                "status": int(error.code),
                "from": email_from,
                "to": recipient,
                "error_type": provider_error_type,
                "error_message": provider_error_message,
                "body": provider_response_body[:2000],
            },
        )

        return {
            **base_result,
            "sent": False,
            "message": (
                "High-risk warning was detected, but the email "
                "provider rejected the request."
            ),
            "provider_status": int(error.code),
            "provider_error_type": provider_error_type,
            "provider_error_message": provider_error_message,
            "provider_response_body": provider_response_body,
        }

    except urllib.error.URLError as error:
        error_message = str(error.reason)

        print(
            "PHI Resend network error:",
            {
                "from": email_from,
                "to": recipient,
                "error": error_message,
            },
        )

        return {
            **base_result,
            "sent": False,
            "message": (
                "High-risk warning was detected, but the email "
                "provider could not be reached."
            ),
            "provider_error_message": error_message,
        }

    except Exception as error:
        error_message = str(error)

        print(
            "PHI Resend unexpected error:",
            {
                "from": email_from,
                "to": recipient,
                "error": error_message,
            },
        )

        return {
            **base_result,
            "sent": False,
            "message": (
                "High-risk warning was detected, but the email could "
                "not be sent."
            ),
            "provider_error_message": error_message,
        }

def save_warning_history(
    moh_area_id,
    phi_officer_id,
    data: InterventionInput,
    risk_level: str,
    recommended_action: str,
    recipient_email: str,
    email_result: dict,
):
    client = get_supabase_client()

    record = {
        "moh_area_id": moh_area_id,
        "phi_officer_id": phi_officer_id,
        "dengue_cases": data.cases,
        "rainfall_mm": data.rainfall,
        "temperature_c": data.temperature,
        "risk_level": risk_level,
        "recommended_action": recommended_action,
        "recipient_email": recipient_email,
        "email_sent": bool(email_result.get("sent", False)),
        "email_message": email_result.get("message", ""),
        "created_at": datetime.now(
            ZoneInfo("Asia/Colombo")
        ).isoformat(),
    }

    try:
        response = (
            client
            .table("warning_history")
            .insert(record)
            .execute()
        )
        return response.data

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Warning was processed, but warning_history "
                f"could not be saved: {str(error)}"
            ),
        )


def get_warning_history_records(limit: int):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("warning_history")
            .select(
                "id,"
                "moh_area_id,"
                "phi_officer_id,"
                "dengue_cases,"
                "rainfall_mm,"
                "temperature_c,"
                "risk_level,"
                "recommended_action,"
                "recipient_email,"
                "email_sent,"
                "email_message,"
                "created_at"
            )
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return response.data or []

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to load warning history: {str(error)}",
        )


def resolve_moh_area_names(area_ids):
    if not area_ids:
        return {}

    records = get_all_moh_area_records()
    name_column = detect_moh_area_name_column(records)

    if not name_column:
        return {}

    wanted_ids = {str(value) for value in area_ids if value is not None}

    return {
        str(record.get("id")): record.get(name_column)
        for record in records
        if str(record.get("id")) in wanted_ids
    }


def resolve_phi_officers(phi_ids):
    if not phi_ids:
        return {}

    client = get_supabase_client()
    wanted_ids = {str(value) for value in phi_ids if value is not None}

    try:
        response = (
            client
            .table("phi_officers")
            .select("id,full_name,email")
            .execute()
        )

        return {
            str(record.get("id")): record
            for record in (response.data or [])
            if str(record.get("id")) in wanted_ids
        }

    except Exception as error:
        print("Unable to resolve PHI officers for history:", error)
        return {}



# ============================================================
# CANONICAL AREA / RL FEEDBACK HELPERS
# ============================================================

def get_canonical_moh_areas():
    records = get_all_moh_area_records()
    name_column = detect_moh_area_name_column(records)

    if not name_column:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to identify the MOH area name column. "
                "Expected one of: name, area_name, moh_area_name."
            ),
        )

    areas = sorted(
        {
            str(record.get(name_column)).strip()
            for record in records
            if str(record.get(name_column, "")).strip()
        }
    )

    if not areas:
        raise HTTPException(
            status_code=404,
            detail="No MOH areas were found in Supabase.",
        )

    return areas


def normalize_canonical_moh_area(area: str) -> str:
    cleaned = " ".join(str(area).strip().split())

    if not cleaned:
        raise HTTPException(
            status_code=400,
            detail="MOH area is required.",
        )

    areas = get_canonical_moh_areas()
    direct_lookup = {
        item.casefold(): item
        for item in areas
    }

    if cleaned.casefold() in direct_lookup:
        return direct_lookup[cleaned.casefold()]

    # Handle the known Colombo naming mismatch in the backend only.
    # Flutter does not need a hard-coded mapping.
    if cleaned.casefold() in {"colombo", "cmc", "cmu"}:
        for alias in ("Colombo", "CMC", "CMU"):
            if alias.casefold() in direct_lookup:
                return direct_lookup[alias.casefold()]

    raise HTTPException(
        status_code=400,
        detail={
            "message": f"Invalid MOH area: {cleaned}",
            "available_areas": areas,
        },
    )


def validate_intervention_input(data: InterventionInput):
    if data.cases < 0:
        raise HTTPException(
            status_code=400,
            detail="cases cannot be negative.",
        )

    if data.rainfall < 0:
        raise HTTPException(
            status_code=400,
            detail="rainfall cannot be negative.",
        )

    if data.temperature < 0 or data.temperature > 60:
        raise HTTPException(
            status_code=400,
            detail="temperature must be between 0 and 60 Celsius.",
        )


def find_active_phi_officer_optional(moh_area_id):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("phi_officers")
            .select(
                "id,full_name,email,phone_number,moh_area_id,"
                "is_active,auth_user_id,created_at"
            )
            .eq("moh_area_id", moh_area_id)
            .eq("is_active", True)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to query PHI officers: {str(error)}",
        )

    if not response.data:
        return None

    return response.data[0]


def get_warning_for_feedback(warning_history_id: int):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("warning_history")
            .select(
                "id,moh_area_id,phi_officer_id,dengue_cases,"
                "rainfall_mm,temperature_c,recommended_action"
            )
            .eq("id", warning_history_id)
            .limit(1)
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to load warning record: {str(error)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=404,
            detail="Warning history record was not found.",
        )

    return response.data[0]


def calculate_feedback_reward(
    cases_before: int,
    cases_after: int,
    outcome_status: str,
) -> float:
    if cases_before <= 0:
        case_change_ratio = 0.0
    else:
        case_change_ratio = (
            cases_before - cases_after
        ) / cases_before

    outcome_adjustment = {
        "improved": 1.0,
        "no_change": 0.0,
        "worsened": -1.0,
    }[outcome_status]

    reward = (
        RL_REWARD_SCALE * case_change_ratio
        + outcome_adjustment
    )

    return round(
        max(
            -RL_REWARD_SCALE,
            min(RL_REWARD_SCALE, reward),
        ),
        2,
    )


def update_q_table_from_feedback(
    cases_before: int,
    cases_after: int,
    rainfall: float,
    temperature: float,
    intervention_action: str,
    reward: float,
):
    global rl_q_table
    global rl_q_table_version
    global rl_q_table_source
    global rl_q_table_persistence_error

    if rl_q_table is None:
        return (
            False,
            rl_q_table_load_error or "Q-table is not loaded.",
            None,
        )

    if intervention_action not in RL_ACTIONS:
        return (
            False,
            "Feedback action does not match a valid RL action.",
            None,
        )

    # A lock prevents overlapping feedback requests from changing the same
    # in-memory Q-table at the same time inside one Space process.
    with _q_table_lock:
        try:
            action_index = RL_ACTIONS.index(intervention_action)

            current_data = InterventionInput(
                area="feedback",
                cases=cases_before,
                rainfall=rainfall,
                temperature=temperature,
            )
            next_data = InterventionInput(
                area="feedback",
                cases=cases_after,
                rainfall=rainfall,
                temperature=temperature,
            )

            current_state = build_rl_state(current_data)
            next_state = build_rl_state(next_data)

            # Work on a copy first. The production in-memory state is changed
            # only after Supabase confirms permanent persistence.
            candidate_table = rl_q_table.copy()

            old_q_value = float(
                candidate_table[
                    current_state[0],
                    current_state[1],
                    current_state[2],
                    action_index,
                ]
            )

            next_max_q = float(
                np.max(
                    candidate_table[
                        next_state[0],
                        next_state[1],
                        next_state[2],
                    ]
                )
            )

            new_q_value = old_q_value + RL_LEARNING_RATE * (
                reward
                + (RL_DISCOUNT_FACTOR * next_max_q)
                - old_q_value
            )

            candidate_table[
                current_state[0],
                current_state[1],
                current_state[2],
                action_index,
            ] = new_q_value

            # Supabase is the production source of truth. If this write fails,
            # do not claim q_table_updated=true and do not mutate the live table.
            new_version = persist_rl_q_table_to_supabase(
                candidate_table,
                rl_q_table_version,
            )

            rl_q_table = candidate_table
            rl_q_table_version = new_version
            rl_q_table_source = "supabase_persistent_state"
            rl_q_table_persistence_error = None

            local_cache_saved = True
            local_cache_error = None

            try:
                np.save(Q_TABLE_PERSIST_PATH, rl_q_table)
            except Exception as cache_error:
                # Supabase already contains the durable state, so a local cache
                # write failure must not invalidate the successful RL update.
                local_cache_saved = False
                local_cache_error = str(cache_error)
                print(
                    "Q-table Supabase persistence succeeded, "
                    f"but local cache save failed: {cache_error}"
                )

            return (
                True,
                None,
                {
                    "action": intervention_action,
                    "action_index": action_index,
                    "reward": reward,
                    "old_q_value": round(old_q_value, 6),
                    "new_q_value": round(float(new_q_value), 6),
                    "learning_rate": RL_LEARNING_RATE,
                    "discount_factor": RL_DISCOUNT_FACTOR,
                    "persistence_mode": "supabase",
                    "q_table_version": rl_q_table_version,
                    "local_cache_saved": local_cache_saved,
                    "local_cache_error": local_cache_error,
                },
            )

        except Exception as error:
            rl_q_table_persistence_error = str(error)
            print("Q-table feedback update error:", error)
            return (
                False,
                (
                    "Q-table update was not committed because permanent "
                    f"Supabase persistence failed: {str(error)}"
                ),
                None,
            )


def save_intervention_feedback(
    warning,
    data: FeedbackInput,
    outcome_status: str,
    reward: float,
):
    client = get_supabase_client()

    record = {
        "warning_history_id": warning["id"],
        "moh_area_id": warning["moh_area_id"],
        "phi_officer_id": warning.get("phi_officer_id"),
        "intervention_action": warning["recommended_action"],
        "cases_before": warning["dengue_cases"],
        "cases_after": data.cases_after,
        "follow_up_days": data.follow_up_days,
        "outcome_status": outcome_status,
        "feedback_notes": data.feedback_notes.strip(),
        "reward": reward,
        "q_table_updated": False,
    }

    try:
        response = (
            client
            .table("intervention_feedback")
            .insert(record)
            .execute()
        )
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to save intervention feedback: {str(error)}",
        )

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Feedback record could not be saved.",
        )

    return response.data[0]


def mark_feedback_q_table_updated(feedback_id):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("intervention_feedback")
            .update({"q_table_updated": True})
            .eq("id", feedback_id)
            .execute()
        )
        return bool(response.data is not None)
    except Exception as error:
        print("Unable to mark q_table_updated:", error)
        return False


def get_feedback_history_records(limit: int):
    client = get_supabase_client()

    try:
        response = (
            client
            .table("intervention_feedback")
            .select(
                "id,warning_history_id,moh_area_id,phi_officer_id,"
                "intervention_action,cases_before,cases_after,"
                "follow_up_days,outcome_status,feedback_notes,reward,"
                "q_table_updated,submitted_at"
            )
            .order("submitted_at", desc=True)
            .limit(limit)
            .execute()
        )
        return response.data or []
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to load feedback history: {str(error)}",
        )


def get_area_weather_context(area: str):
    model_area = resolve_area_proxy_model_area(area)

    if area_proxy_df is not None:
        area_rows = area_proxy_df[
            area_proxy_df["moh_area"].str.casefold()
            == model_area.casefold()
        ].copy()

        source = "area_proxy_context_dataset_latest_area_row"

        if area_rows.empty:
            max_year = int(area_proxy_df["year"].max())
            year_rows = area_proxy_df[
                area_proxy_df["year"] == max_year
            ]
            max_week = int(year_rows["week"].max())
            area_rows = year_rows[
                year_rows["week"] == max_week
            ].copy()
            source = "area_proxy_context_dataset_latest_all_area_average"

        area_rows = area_rows.sort_values(["year", "week"])
        latest_year = int(area_rows["year"].max())
        latest_year_rows = area_rows[area_rows["year"] == latest_year]
        latest_week = int(latest_year_rows["week"].max())
        latest_rows = latest_year_rows[
            latest_year_rows["week"] == latest_week
        ]

        rainfall = float(
            pd.to_numeric(
                latest_rows["rainfall_mm"],
                errors="coerce",
            ).mean()
        )
        temperature = float(
            pd.to_numeric(
                latest_rows["temp_mean_c"],
                errors="coerce",
            ).mean()
        )

        period_date = date.fromisocalendar(
            latest_year,
            latest_week,
            1,
        )

        return {
            "area": area,
            "rainfall": round(rainfall, 2),
            "temperature": round(temperature, 2),
            "source": source,
            "data_year": latest_year,
            "data_week": latest_week,
            "updated_at": datetime(
                period_date.year,
                period_date.month,
                period_date.day,
                tzinfo=ZoneInfo("Asia/Colombo"),
            ).isoformat(),
            "important_note": (
                "Weather/context values come from the latest available "
                "project dataset, not a live weather forecast."
            ),
        }

    latest_row = history_df.sort_values(
        ["year", "week"]
    ).tail(1)

    if latest_row.empty:
        raise HTTPException(
            status_code=503,
            detail="No weather/context data are currently available.",
        )

    row = latest_row.iloc[0]
    data_year = int(row["year"])
    data_week = int(row["week"])
    period_date = date.fromisocalendar(data_year, data_week, 1)

    return {
        "area": area,
        "rainfall": round(float(row["rainfall_mm"]), 2),
        "temperature": round(float(row["temp_mean_c"]), 2),
        "source": "latest_district_dataset_context",
        "data_year": data_year,
        "data_week": data_week,
        "updated_at": datetime(
            period_date.year,
            period_date.month,
            period_date.day,
            tzinfo=ZoneInfo("Asia/Colombo"),
        ).isoformat(),
        "important_note": (
            "Area-specific weather context was unavailable, so the latest "
            "Colombo District dataset weather context was returned."
        ),
    }


# ============================================================
# ROOT ENDPOINT
# ============================================================

@app.get("/")
def home():

    return {
        "message": (
            "Colombo Dengue Outbreak "
            "Prediction API is running"
        ),

        "model": (
            "Tuned Random Forest with Lag Features"
        ),

        "validation": (
            "Future-Year Validation"
        ),

        "evaluation_train_period": EVALUATION_TRAIN_PERIOD,

        "evaluation_test_period": EVALUATION_TEST_PERIOD,

        "accuracy": EVALUATION_ACCURACY,

        "weighted_f1": EVALUATION_WEIGHTED_F1,

        "production_training_period": (
            f"{PRODUCTION_TRAIN_START_YEAR}-{PRODUCTION_TRAIN_END_YEAR}"
        ),

        "model_file": MODEL_FILE,

        "dataset_file": DATA_FILE,

        "future_prediction_mode": (
            "2022-2025 historical seasonal average estimation"
        ),

        "rl_model_loaded": (
            rl_q_table is not None
        ),

        "rl_q_table_file": Q_TABLE_FILE,

        "rl_q_table_shape": (
            list(rl_q_table.shape)
            if rl_q_table is not None
            else None
        ),

        "rl_q_table_source": rl_q_table_source,

        "rl_q_table_version": rl_q_table_version,

        "rl_q_table_persistence": (
            f"supabase:{RL_Q_TABLE_STATE_TABLE}"
        ),

        "shap_enabled": True,

        "available_endpoints": [
            "/predict",
            "/predict-auto",
            "/predict-future",
            "/predict-area-risk",
            "/predict-dashboard",
            "/latest-dashboard",
            "/today-dashboard",
            "/trend/weekly-summary",
            "/available-weeks",
            "/supported-future-weeks",
            "/shap/local",
            "/shap/global",
            "/recommend",
            "/send-warning",
            "/warning-history",
            "/submit-feedback",
            "/feedback-history",
            "/area-weather",
            "/moh-areas",
        ],

        "note": (
            "The final production Random Forest was trained on 2022-2025. "
            "The uploaded model-ready dataset covers 2007-2026, but "
            "automatic future-feature generation uses 2022-2025 as the "
            "seasonal reference period to remain consistent with model training. "
            "No direct dengue_cases feature is passed to the model; only "
            "dengue_lag_1 and dengue_lag_2 are used."
        ),
    }


# ============================================================
# MANUAL ML PREDICTION
# ============================================================

@app.post("/predict")
def predict_manual(
    data: ManualDengueInput,
):

    input_df = pd.DataFrame(
        [
            to_dict(data)
        ]
    )

    input_df = input_df[
        FEATURES
    ]

    prediction, probability_output = (
        get_prediction_response(
            input_df
        )
    )

    return {
        "predicted_outbreak_level": prediction,

        "probabilities": (
            probability_output
        ),

        "model_used": (
            "Tuned Random Forest with Lag Features"
        ),

        "input_type": "manual",
    }


# ============================================================
# AUTOMATED HISTORICAL PREDICTION
# ============================================================

@app.post("/predict-auto")
def predict_auto(
    data: AutoDengueInput,
):

    year = data.year
    week = data.week

    df = prepare_history_with_lags()

    selected_row = df[
        (df["year"] == year)
        & (df["week"] == week)
    ]

    if selected_row.empty:

        raise HTTPException(
            status_code=404,
            detail=(
                "No historical data found "
                "for the selected year and week."
            ),
        )

    input_df = selected_row[
        FEATURES
    ]

    prediction, probability_output = (
        get_prediction_response(
            input_df
        )
    )

    actual_level = (
        selected_row[
            "outbreak_level"
        ].values[0]

        if (
            "outbreak_level"
            in selected_row.columns
        )

        else None
    )

    return {
        "year": year,
        "week": week,

        "predicted_outbreak_level": (
            prediction
        ),

        "actual_outbreak_level": (
            actual_level
        ),

        "probabilities": (
            probability_output
        ),

        "model_used": (
            "Tuned Random Forest with Lag Features"
        ),

        "input_type": (
            "automated_from_historical_dataset"
        ),
    }


# ============================================================
# FUTURE PREDICTION
# ============================================================

@app.post("/predict-future")
def predict_future(
    data: AutoDengueInput,
):

    year = data.year
    week = data.week

    input_df = (
        build_historical_future_features(
            year,
            week,
        )
    )

    prediction, probability_output = (
        get_prediction_response(
            input_df
        )
    )

    _, prev1_week = (
        get_previous_year_week(
            year,
            week,
            offset=1,
        )
    )

    _, prev2_week = (
        get_previous_year_week(
            year,
            week,
            offset=2,
        )
    )

    return {
        "year": year,
        "week": week,

        "calculated_month": int(
            input_df.iloc[0][
                "month"
            ]
        ),

        "predicted_outbreak_level": (
            prediction
        ),

        "probabilities": (
            probability_output
        ),

        "model_used": (
            "Tuned Random Forest with Lag Features"
        ),

        "validation": (
            "Future-Year Validation"
        ),

        "input_type": (
            "future_prediction_from_"
            "historical_seasonal_averages"
        ),

        "auto_generated_features": (
            input_df.iloc[
                0
            ].to_dict()
        ),

        "data_sources_used": {

            "target_weather": (
                "Historical average weather values "
                f"for Week {week}"
            ),

            "dengue_lag_1": (
                "Historical average dengue cases "
                f"for previous Week {prev1_week}"
            ),

            "dengue_lag_2": (
                "Historical average dengue cases "
                f"for two-week previous Week {prev2_week}"
            ),

            "rainfall_lag_1": (
                "Historical average rainfall "
                f"for previous Week {prev1_week}"
            ),

            "humidity_lag_1": (
                "Historical average humidity "
                f"for previous Week {prev1_week}"
            ),
        },

        "important_note": (
            "This is a 2022-2025 seasonal-average based future risk "
            "estimation, not a real-time weather forecast prediction."
        ),
    }


# ============================================================
# AREA PROXY RISK PREDICTION
# POST /predict-area-risk
# ============================================================

@app.post(
    "/predict-area-risk",
    response_model=AreaRiskResponse,
    tags=["Area Proxy Risk"],
    summary="Predict selected Colombo MOH area proxy risk",
)
def predict_area_risk(
    data: AreaRiskInput,
):
    """Return historical/proxy area-risk context for a canonical MOH area."""

    if area_proxy_model is None or area_proxy_df is None:
        raise HTTPException(
            status_code=503,
            detail={
                "message": (
                    "Area proxy risk model is currently unavailable. "
                    "Existing district-level prediction endpoints are unaffected."
                ),
                "load_error": area_proxy_load_error,
            },
        )

    canonical_area = normalize_canonical_moh_area(data.area)

    input_df, input_type, estimation_basis = (
        build_area_proxy_features(
            year=data.year,
            week=data.week,
            area=canonical_area,
        )
    )

    predicted_level, probabilities = predict_area_proxy(input_df)

    model_accuracy = get_area_metadata_percent(
        ["random_forest_2025", "accuracy"],
        86.35,
    )
    weighted_f1 = get_area_metadata_percent(
        ["random_forest_2025", "weighted_f1"],
        86.36,
    )
    future_accuracy = get_area_metadata_percent(
        ["future_2026_proxy_check", "accuracy"],
        86.36,
    )
    future_weighted_f1 = get_area_metadata_percent(
        ["future_2026_proxy_check", "weighted_f1"],
        86.32,
    )

    methodology_note = (
        "The selected area prediction is based on a proxy/context model "
        "prepared from Colombo District-level dengue data and estimated "
        "MOH-area distributions. It is used for area-risk context in the "
        "mobile app."
    )

    if input_type == "historical_area_proxy_estimation":
        methodology_note += (
            " The exact selected area-week was not available in the proxy "
            "dataset, so non-leakage model features were estimated using "
            f"{estimation_basis}. This must not be interpreted as official "
            "MOH-area reported data."
        )

    return {
        "year": int(data.year),
        "week": int(data.week),
        "area": canonical_area,
        "predicted_area_risk_level": predicted_level,
        "probabilities": probabilities,
        "model_used": "Random Forest Area Proxy Risk Model",
        "validation": "Future-Year Validation",
        "model_accuracy": model_accuracy,
        "weighted_f1": weighted_f1,
        "future_proxy_check_accuracy": future_accuracy,
        "future_proxy_check_weighted_f1": future_weighted_f1,
        "input_type": input_type,
        "important_note": (
            "This is an MOH-area proxy risk prediction, not a complete "
            "official MOH-area surveillance prediction."
        ),
        "data_context": {
            "dataset": "Colombo MOH Area Proxy Context Dataset 2015-2026",
            "area_data_type": "proxy_area_context",
            "moh_cases_source": "estimated_from_district_cases",
            "confidence_level": "estimated",
        },
        "methodology_note": methodology_note,
    }

# ============================================================
# AREA FEATURE AUTO-FILL
# GET /get-area-features
# ============================================================

@app.get(
    "/get-area-features",
    tags=["Area Proxy Risk"],
    summary="Get auto-generated area prediction features",
)
def get_area_features(
    area: str,
    year: int,
    week: int,
):
    """
    Return auto-generated features for manual prediction editing.
    Existing prediction endpoint is not affected.
    """

    if area_proxy_model is None or area_proxy_df is None:
        raise HTTPException(
            status_code=503,
            detail={
                "message": "Area proxy risk model unavailable",
                "load_error": area_proxy_load_error,
            },
        )


    canonical_area = normalize_canonical_moh_area(area)


    input_df, input_type, estimation_basis = (
        build_area_proxy_features(
            year=year,
            week=week,
            area=canonical_area,
        )
    )


    # Convert dataframe row into editable feature values
    feature_row = input_df.iloc[0].to_dict()


    return {

        "year": int(year),

        "week": int(week),

        "area": canonical_area,


        "features": {

            key: (
                float(value)
                if isinstance(value, (int, float))
                else value
            )

            for key, value in feature_row.items()

        },


        "input_type": input_type,


        "estimation_basis": estimation_basis,


        "message": (
            "These features are auto-generated and can be "
            "modified before manual prediction."
        )

    }

# ============================================================
# DASHBOARD PREDICTION
# ============================================================

@app.post("/predict-dashboard")
def predict_dashboard(
    data: AutoDengueInput,
):

    year = data.year
    week = data.week

    input_df = (
        build_historical_future_features(
            year,
            week,
        )
    )

    prediction, probability_output = (
        get_prediction_response(
            input_df
        )
    )

    confidence = 0.0

    if probability_output:

        confidence = max(
            probability_output.values()
        )

    return {
        "year": year,
        "week": week,

        "calculated_month": int(
            input_df.iloc[0][
                "month"
            ]
        ),

        "risk_level": prediction,

        "risk_color": (
            risk_color(
                prediction
            )
        ),

        "confidence": round(
            float(confidence),
            2,
        ),

        "probabilities": (
            probability_output
        ),

        "top_reason": (
            "Prediction is mainly based on "
            "historical rainfall, humidity, "
            "temperature, and dengue lag patterns."
        ),

        "recommendations": (
            get_interventions_for_risk(
                prediction
            )
        ),

        "model_used": (
            "Tuned Random Forest with Lag Features"
        ),

        "validation": (
            "Future-Year Validation"
        ),

        "input_type": (
            "dashboard_prediction_from_"
            "historical_seasonal_averages"
        ),

        "auto_generated_features": (
            input_df.iloc[
                0
            ].to_dict()
        ),

        "important_note": (
            "This endpoint uses the centralized "
            "hosted ML model. Inputs are generated "
            "automatically using historical "
            "seasonal averages."
        ),
    }


# ============================================================
# LATEST DASHBOARD
# ============================================================

@app.get("/latest-dashboard")
def latest_dashboard():

    df = prepare_history_with_lags()

    df = df.sort_values(
        ["year", "week"]
    ).reset_index(drop=True)

    latest_row = (
        df.tail(1)
    )

    if latest_row.empty:

        raise HTTPException(
            status_code=404,
            detail=(
                "No historical data found "
                "in the dataset."
            ),
        )

    input_df = latest_row[
        FEATURES
    ]

    prediction, probability_output = (
        get_prediction_response(
            input_df
        )
    )

    confidence = 0.0

    if probability_output:

        confidence = max(
            probability_output.values()
        )

    actual_level = (
        latest_row[
            "outbreak_level"
        ].values[0]

        if (
            "outbreak_level"
            in latest_row.columns
        )

        else None
    )

    latest_year = int(
        latest_row[
            "year"
        ].values[0]
    )

    latest_week = int(
        latest_row[
            "week"
        ].values[0]
    )

    latest_month = int(
        latest_row[
            "month"
        ].values[0]
    )

    return {
        "year": latest_year,
        "week": latest_week,
        "month": latest_month,

        "risk_level": prediction,

        "actual_outbreak_level": (
            actual_level
        ),

        "risk_color": (
            risk_color(
                prediction
            )
        ),

        "confidence": round(
            float(confidence),
            2,
        ),

        "probabilities": (
            probability_output
        ),

        "top_reason": (
            "Latest dengue risk update is "
            "generated using the most recent "
            "available historical dataset record."
        ),

        "recommendations": (
            get_interventions_for_risk(
                prediction
            )
        ),

        "model_used": (
            "Tuned Random Forest with Lag Features"
        ),

        "validation": (
            "Future-Year Validation"
        ),

        "input_type": (
            "latest_dashboard_prediction_"
            "from_historical_dataset"
        ),

        "latest_features_used": (
            input_df.iloc[
                0
            ].to_dict()
        ),

        "important_note": (
            "This endpoint automatically uses "
            "the latest available week from the "
            "uploaded historical dataset."
        ),
    }


# ============================================================
# TODAY DASHBOARD
# ============================================================

@app.get("/today-dashboard")
def today_dashboard():

    try:

        today = datetime.now(
            ZoneInfo(
                "Asia/Colombo"
            )
        ).date()

        iso_calendar = (
            today.isocalendar()
        )

        current_year = int(
            iso_calendar.year
        )

        current_week = int(
            iso_calendar.week
        )

        current_month = int(
            today.month
        )

        input_df = (
            build_historical_future_features(
                current_year,
                current_week,
            )
        )

        prediction, probability_output = (
            get_prediction_response(
                input_df
            )
        )

        confidence = 0.0

        if probability_output:

            confidence = max(
                probability_output.values()
            )

        return {
            "date": today.isoformat(),

            "year": current_year,

            "week": current_week,

            "month": current_month,

            "risk_level": prediction,

            "risk_color": (
                risk_color(
                    prediction
                )
            ),

            "confidence": round(
                float(confidence),
                2,
            ),

            "probabilities": (
                probability_output
            ),

            "top_reason": (
                "Today's dengue risk update is "
                "generated using the current ISO "
                "week and historical seasonal "
                "dengue/weather patterns."
            ),

            "recommendations": (
                get_interventions_for_risk(
                    prediction
                )
            ),

            "model_used": (
                "Tuned Random Forest with Lag Features"
            ),

            "validation": (
                "Future-Year Validation"
            ),

            "input_type": (
                "today_dashboard_prediction_"
                "from_historical_seasonal_averages"
            ),

            "auto_generated_features": (
                input_df.iloc[
                    0
                ].to_dict()
            ),

            "important_note": (
                "This endpoint uses today's "
                "Sri Lanka date and automatically "
                "generates ML features using "
                "historical seasonal averages."
            ),
        }

    except HTTPException:
        raise

    except Exception as error:

        raise HTTPException(
            status_code=500,
            detail=(
                "Today dashboard prediction failed: "
                f"{str(error)}"
            ),
        )


# ============================================================
# WEEKLY TREND SUMMARY
# ============================================================

@app.get("/trend/weekly-summary")
def weekly_trend_summary(
    weeks: int = 12,
):

    if (
        weeks < 1
        or weeks > 52
    ):

        raise HTTPException(
            status_code=400,
            detail=(
                "weeks must be between 1 and 52."
            ),
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
        col

        for col
        in required_trend_columns

        if col
        not in history_df.columns
    ]

    if missing_columns:

        raise HTTPException(
            status_code=500,
            detail=(
                "Dataset is missing required trend "
                f"columns: {missing_columns}"
            ),
        )

    trend_df = history_df[
        required_trend_columns
    ].copy()

    trend_df = (
        trend_df
        .sort_values(
            ["year", "week"]
        )
        .tail(weeks)
    )

    trend_df = (
        trend_df.fillna(0)
    )

    weekly_summary = []

    for _, row in trend_df.iterrows():

        weekly_summary.append(
            {
                "year": int(
                    row["year"]
                ),

                "week": int(
                    row["week"]
                ),

                "month": int(
                    row["month"]
                ),

                "label": (
                    f"{int(row['year'])}"
                    f"-W{int(row['week'])}"
                ),

                "dengue_cases": round(
                    float(
                        row[
                            "dengue_cases"
                        ]
                    ),
                    2,
                ),

                "rainfall_mm": round(
                    float(
                        row[
                            "rainfall_mm"
                        ]
                    ),
                    2,
                ),

                "humidity_pct": round(
                    float(
                        row[
                            "humidity_pct"
                        ]
                    ),
                    2,
                ),

                "temp_mean_c": round(
                    float(
                        row[
                            "temp_mean_c"
                        ]
                    ),
                    2,
                ),
            }
        )

    return {
        "title": (
            "Weekly Dengue and Weather Trend Summary"
        ),

        "district": (
            "Colombo District"
        ),

        "weeks_returned": len(
            weekly_summary
        ),

        "requested_weeks": (
            weeks
        ),

        "weekly_summary": (
            weekly_summary
        ),

        "chart_fields": {

            "x_axis": "label",

            "line_series": [
                "dengue_cases",
                "rainfall_mm",
                "humidity_pct",
                "temp_mean_c",
            ],
        },

        "important_note": (
            "This endpoint returns the latest "
            "available weekly records from the "
            "historical dataset for trend charts."
        ),
    }


# ============================================================
# AVAILABLE WEEKS
# ============================================================

@app.get("/available-weeks")
def available_weeks():

    available = (
        history_df[
            ["year", "week"]
        ]
        .drop_duplicates()
        .sort_values(
            ["year", "week"]
        )
    )

    return {
        "available_weeks": (
            available.to_dict(
                orient="records"
            )
        )
    }


# ============================================================
# SUPPORTED FUTURE WEEKS
# ============================================================

@app.get("/supported-future-weeks")
def supported_future_weeks():

    return {
        "supported_input_format": {

            "year": (
                "Any future year, "
                "e.g., 2026 or 2027"
            ),

            "week": (
                "Valid ISO week number, "
                "usually 1-52 or 1-53 "
                "depending on the year"
            ),
        },

        "example_inputs": [
            {
                "year": 2026,
                "week": 40,
            },
            {
                "year": 2026,
                "week": 45,
            },
            {
                "year": 2027,
                "week": 10,
            },
        ],

        "mode": (
            "historical_seasonal_"
            "average_estimation"
        ),
    }


# ============================================================
# LOCAL SHAP ENDPOINT
# POST /shap/local
# ============================================================

@app.post("/shap/local")
def local_shap(
    data: AutoDengueInput,
):

    try:

        input_df = (
            build_historical_future_features(
                data.year,
                data.week,
            )
        )

        prediction, _ = (
            get_prediction_response(
                input_df
            )
        )

        local_results = (
            calculate_local_grouped_shap(
                input_df,
                prediction,
            )
        )

        return {
            "local_shap": (
                local_results
            )
        }

    except HTTPException:
        raise

    except Exception as error:

        raise HTTPException(
            status_code=500,
            detail=(
                "Local SHAP calculation failed: "
                f"{str(error)}"
            ),
        )


# ============================================================
# GLOBAL SHAP ENDPOINT
# GET /shap/global
# ============================================================

@app.get("/shap/global")
def global_shap():

    try:

        global_results = (
            calculate_global_grouped_shap()
        )

        return {
            "global_shap": (
                global_results
            )
        }

    except Exception as error:

        raise HTTPException(
            status_code=500,
            detail=(
                "Global SHAP calculation failed: "
                f"{str(error)}"
            ),
        )


# ============================================================
# RL RECOMMENDATION ENDPOINT
# POST /recommend
# ============================================================

@app.post("/recommend")
def recommend_intervention(
    data: InterventionInput,
):
    canonical_area = normalize_canonical_moh_area(data.area)

    normalized_data = InterventionInput(
        area=canonical_area,
        cases=data.cases,
        rainfall=data.rainfall,
        temperature=data.temperature,
    )
    validate_intervention_input(normalized_data)

    risk_level = determine_intervention_risk(
        normalized_data.cases,
        normalized_data.rainfall,
        normalized_data.temperature,
    )

    q_values = get_q_learning_values(
        normalized_data,
        risk_level,
    )

    if q_values:
        recommendations = rank_q_learning_actions(q_values)
        recommendation_source = "q_table_real.npy"
    else:
        if REQUIRE_RL_MODEL:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Q-Learning table is not available for the requested state."
                ),
            )
        recommendations = fallback_recommendations(risk_level)
        recommendation_source = "fallback_policy"

    if not recommendations:
        raise HTTPException(
            status_code=500,
            detail="No RL intervention recommendations could be generated.",
        )

    top_action = recommendations[0]["action"]
    medium_threshold, high_threshold = get_rl_case_thresholds()

    return {
        "success": True,
        "area": canonical_area,
        "cases": normalized_data.cases,
        "rainfall": normalized_data.rainfall,
        "temperature": normalized_data.temperature,
        "risk_level": risk_level,
        "top_action": top_action,
        "risk_interpretation": get_risk_interpretation(
            risk_level,
            canonical_area,
        ),
        "recommendation_explanation": get_recommendation_explanation(
            risk_level
        ),
        "recommendations": recommendations,
        "recommendation_source": recommendation_source,
        "risk_calibration": {
            "case_threshold_source": "area_proxy_context_dataset",
            "medium_case_threshold": medium_threshold,
            "high_case_threshold": high_threshold,
            "fixed_1500_5000_thresholds_used": False,
        },
        "email": {
            "sent": False,
            "message": "No email is sent from /recommend.",
        },
    }

# ============================================================
# PHI WARNING ENDPOINT
# POST /send-warning
# ============================================================

@app.post("/send-warning")
def send_warning(
    data: InterventionInput,
):
    canonical_area = normalize_canonical_moh_area(data.area)
    normalized_data = InterventionInput(
        area=canonical_area,
        cases=data.cases,
        rainfall=data.rainfall,
        temperature=data.temperature,
    )
    validate_intervention_input(normalized_data)

    risk_level = determine_intervention_risk(
        normalized_data.cases,
        normalized_data.rainfall,
        normalized_data.temperature,
    )

    q_values = get_q_learning_values(normalized_data, risk_level)
    if q_values:
        recommendations = rank_q_learning_actions(q_values)
        recommendation_source = "q_table_real.npy"
    else:
        recommendations = fallback_recommendations(risk_level)
        recommendation_source = "fallback_policy"

    if not recommendations:
        raise HTTPException(
            status_code=500,
            detail="No intervention recommendation could be generated.",
        )

    recommended_action = recommendations[0]["action"]
    moh_area = find_moh_area(canonical_area)
    phi_officer = find_active_phi_officer_optional(moh_area["id"])

    recipient_email = (
        phi_officer.get("email")
        if phi_officer
        else None
    )

    if risk_level == "HIGH" and phi_officer and recipient_email:
        email_result = send_phi_warning_email(
            normalized_data,
            risk_level,
            recipient_email,
        )
    elif risk_level == "HIGH" and not phi_officer:
        email_result = {
            "sent": False,
            "message": (
                "HIGH risk was detected, but no active PHI officer is "
                "assigned to the selected MOH area."
            ),
        }
    elif risk_level == "HIGH" and not recipient_email:
        email_result = {
            "sent": False,
            "message": (
                "HIGH risk was detected, but the active PHI officer does "
                "not have an email address."
            ),
        }
    else:
        email_result = {
            "sent": False,
            "message": (
                "No warning email sent because risk level is "
                f"{risk_level}."
            ),
        }

    saved_rows = save_warning_history(
        moh_area_id=moh_area["id"],
        phi_officer_id=(
            phi_officer.get("id")
            if phi_officer
            else None
        ),
        data=normalized_data,
        risk_level=risk_level,
        recommended_action=recommended_action,
        recipient_email=recipient_email,
        email_result=email_result,
    )

    warning_history_id = None
    if saved_rows:
        try:
            warning_history_id = saved_rows[0].get("id")
        except Exception:
            warning_history_id = None

    email_response = {
        "sent": bool(email_result.get("sent", False)),
        "message": email_result.get("message", ""),
        "recipient": recipient_email,
        "provider": email_result.get("provider", "resend_https_api"),
        "provider_message_id": email_result.get("provider_message_id"),
    }

    # On failure, return useful Resend diagnostics without exposing the API key.
    if not email_response["sent"]:
        diagnostic_fields = [
            "provider_status",
            "provider_error_type",
            "provider_error_message",
            "provider_response_body",
            "from_email",
        ]

        for field in diagnostic_fields:
            value = email_result.get(field)
            if value is not None:
                email_response[field] = value

    return {
        "success": True,
        "area": canonical_area,
        "risk_level": risk_level,
        "recommendations": recommendations,
        "top_action": recommended_action,
        "recommendation_source": recommendation_source,
        "warning_saved": True,
        "warning_history_id": warning_history_id,
        "phi_officer_found": phi_officer is not None,
        "email_sent": bool(email_result.get("sent", False)),
        "email": email_response,
    }

# ============================================================
# WARNING HISTORY ENDPOINT
# GET /warning-history?limit=20
# ============================================================

@app.get("/warning-history")
def warning_history(
    limit: int = 20,
):
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail="limit must be between 1 and 100.",
        )

    records = get_warning_history_records(limit)

    area_ids = [
        record.get("moh_area_id")
        for record in records
        if record.get("moh_area_id") is not None
    ]

    phi_ids = [
        record.get("phi_officer_id")
        for record in records
        if record.get("phi_officer_id") is not None
    ]

    area_names = resolve_moh_area_names(area_ids)
    phi_officers = resolve_phi_officers(phi_ids)

    output = []

    for record in records:
        moh_area_id = record.get("moh_area_id")
        phi_officer_id = record.get("phi_officer_id")

        officer = phi_officers.get(
            str(phi_officer_id),
            {},
        )

        output.append(
            {
                "id": record.get("id"),
                "moh_area_name": area_names.get(
                    str(moh_area_id)
                ),
                "phi_officer_name": officer.get(
                    "full_name"
                ),
                "phi_officer_email": (
                    officer.get("email")
                    or record.get("recipient_email")
                ),
                "dengue_cases": record.get(
                    "dengue_cases"
                ),
                "rainfall_mm": record.get(
                    "rainfall_mm"
                ),
                "temperature_c": record.get(
                    "temperature_c"
                ),
                "risk_level": record.get(
                    "risk_level"
                ),
                "recommended_action": record.get(
                    "recommended_action"
                ),
                "email_sent": record.get(
                    "email_sent"
                ),
                "email_message": record.get(
                    "email_message"
                ),
                "created_at": record.get(
                    "created_at"
                ),
            }
        )

    return {
        "count": len(output),
        "warning_history": output,
    }



# ============================================================
# RL FEEDBACK LOOP
# POST /submit-feedback
# ============================================================

@app.post("/submit-feedback")
def submit_feedback(
    data: FeedbackInput,
):
    outcome_status = data.outcome_status.strip().casefold()

    if outcome_status not in {
        "improved",
        "no_change",
        "worsened",
    }:
        raise HTTPException(
            status_code=400,
            detail=(
                "outcome_status must be improved, no_change, or worsened."
            ),
        )

    warning = get_warning_for_feedback(
        data.warning_history_id
    )

    reward = calculate_feedback_reward(
        int(warning["dengue_cases"]),
        data.cases_after,
        outcome_status,
    )

    feedback = save_intervention_feedback(
        warning=warning,
        data=data,
        outcome_status=outcome_status,
        reward=reward,
    )

    q_updated, q_error, q_update_details = (
        update_q_table_from_feedback(
            cases_before=int(warning["dengue_cases"]),
            cases_after=data.cases_after,
            rainfall=float(warning["rainfall_mm"]),
            temperature=float(warning["temperature_c"]),
            intervention_action=warning["recommended_action"],
            reward=reward,
        )
    )

    if q_updated:
        status_marked = mark_feedback_q_table_updated(
            feedback["id"]
        )
        if not status_marked:
            q_updated = False
            q_error = (
                "Q-table changed in memory/file, but the feedback record "
                "could not be marked q_table_updated=true."
            )

    return {
        "success": True,
        "feedback_id": feedback["id"],
        "warning_history_id": data.warning_history_id,
        "intervention_action": warning["recommended_action"],
        "cases_before": int(warning["dengue_cases"]),
        "cases_after": data.cases_after,
        "outcome_status": outcome_status,
        "reward": reward,
        "q_table_updated": q_updated,
        "q_table_update": q_update_details,
        "q_table_update_error": q_error,
    }


# ============================================================
# FEEDBACK HISTORY
# GET /feedback-history?limit=20
# ============================================================

@app.get("/feedback-history")
def feedback_history(
    limit: int = 20,
):
    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail="limit must be between 1 and 100.",
        )

    records = get_feedback_history_records(limit)
    return {
        "success": True,
        "count": len(records),
        "feedback": records,
    }


# ============================================================
# AREA WEATHER / CONTEXT
# GET /area-weather?area=Dehiwala
# ============================================================

@app.get("/area-weather")
def area_weather(
    area: str,
):
    canonical_area = normalize_canonical_moh_area(area)
    return get_area_weather_context(canonical_area)


# ============================================================
# MOH AREAS
# GET /moh-areas
# ============================================================

@app.get("/moh-areas")
def get_moh_areas():
    """Return the canonical MOH-area list directly from Supabase."""
    areas = get_canonical_moh_areas()
    return {
        "success": True,
        "count": len(areas),
        "district": "Colombo",
        "areas": areas,
    }

