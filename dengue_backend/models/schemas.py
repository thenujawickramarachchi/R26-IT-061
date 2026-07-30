from pydantic import BaseModel
from typing import Optional

class ChatRequest(BaseModel):
    message: str

class ClaimRequest(BaseModel):
    claim: str

class SimulationRequest(BaseModel):
    year: Optional[int] = 2024
    week: int
    month: int

    temp_max_c: float
    temp_min_c: float
    temp_mean_c: float
    humidity_pct: float
    rainfall_mm: float
    wind_speed_kmh: float
    cloudcover: float
    visibility: float
    uvindex: float

    rainfall_change: Optional[float] = 0
    humidity_change: Optional[float] = 0
    temperature_change: Optional[float] = 0
    wind_change: Optional[float] = 0
