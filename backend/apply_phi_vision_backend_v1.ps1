$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Location).Path
$AppDir = Join-Path $ProjectRoot "app"
$MainFile = Join-Path $AppDir "main.py"
$ModelFile = Join-Path $ProjectRoot "Dengue_NLP_Model\vision_detector_v1\model.pt"
$RequirementsFile = Join-Path $ProjectRoot "requirements.txt"

if (-not (Test-Path $MainFile)) {
    throw "app\main.py was not found. Run this script from C:\DengueProject."
}

if (-not (Test-Path $ModelFile)) {
    throw "Vision model was not found at: $ModelFile"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ProjectRoot "vision_patch_backups\before_phi_vision_$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $MainFile (Join-Path $BackupDir "main.py") -Force

if (Test-Path $RequirementsFile) {
    Copy-Item $RequirementsFile (Join-Path $BackupDir "requirements.txt") -Force
}

$RoutersDir = Join-Path $AppDir "routers"
$ServicesDir = Join-Path $AppDir "services"
New-Item -ItemType Directory -Path $RoutersDir -Force | Out-Null
New-Item -ItemType Directory -Path $ServicesDir -Force | Out-Null

$RoutersInit = Join-Path $RoutersDir "__init__.py"
$ServicesInit = Join-Path $ServicesDir "__init__.py"

if (-not (Test-Path $RoutersInit)) {
    New-Item -ItemType File -Path $RoutersInit | Out-Null
}

if (-not (Test-Path $ServicesInit)) {
    New-Item -ItemType File -Path $ServicesInit | Out-Null
}

$VisionService = @'
from __future__ import annotations

import os
import threading
from pathlib import Path
from typing import Any

from PIL import Image
from ultralytics import YOLO


CLASS_RISK_WEIGHTS = {
    "coconut_shell": 2,
    "tire": 2,
    "open_container": 2,
    "water_storage": 3,
    "drain_inlet": 3,
}


def default_model_path() -> Path:
    project_root = Path(__file__).resolve().parents[2]
    return (
        project_root
        / "Dengue_NLP_Model"
        / "vision_detector_v1"
        / "model.pt"
    )


class VisionDetector:
    def __init__(self) -> None:
        configured_path = os.getenv("DENGUE_VISION_MODEL_PATH")
        self.model_path = (
            Path(configured_path).expanduser().resolve()
            if configured_path
            else default_model_path()
        )
        self.device = os.getenv("DENGUE_VISION_DEVICE", "cpu")
        self._model: YOLO | None = None
        self._load_lock = threading.Lock()
        self._predict_lock = threading.Lock()

    @property
    def loaded(self) -> bool:
        return self._model is not None

    def load(self) -> YOLO:
        if self._model is None:
            with self._load_lock:
                if self._model is None:
                    if not self.model_path.exists():
                        raise FileNotFoundError(
                            f"Vision model not found: {self.model_path}"
                        )
                    self._model = YOLO(str(self.model_path))
        return self._model

    def predict(
        self,
        image: Image.Image,
        confidence: float,
    ) -> tuple[list[dict[str, Any]], Any]:
        model = self.load()

        with self._predict_lock:
            result = model.predict(
                source=image,
                imgsz=640,
                conf=confidence,
                device=self.device,
                verbose=False,
            )[0]

        detections: list[dict[str, Any]] = []

        for box in result.boxes:
            class_id = int(box.cls[0].item())
            label = str(result.names[class_id])
            score = float(box.conf[0].item())
            coordinates = [
                round(float(value), 2)
                for value in box.xyxy[0].tolist()
            ]

            detections.append(
                {
                    "class_id": class_id,
                    "label": label,
                    "confidence": round(score, 6),
                    "box_xyxy": coordinates,
                    "risk_weight": CLASS_RISK_WEIGHTS.get(label, 1),
                }
            )

        detections.sort(
            key=lambda item: item["confidence"],
            reverse=True,
        )
        return detections, result


vision_detector = VisionDetector()
'@

$VisionRouter = @'
from __future__ import annotations

import hashlib
import io
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from app.services.vision_detector import vision_detector


router = APIRouter(prefix="/v1/inspection", tags=["PHI inspection"])

MAX_IMAGE_BYTES = 10 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}


def evidence_root() -> Path:
    configured = os.getenv("DENGUE_EVIDENCE_DIR")
    if configured:
        return Path(configured).expanduser().resolve()

    project_root = Path(__file__).resolve().parents[2]
    return project_root / "inspection_evidence"


def calculate_risk(detections: list[dict]) -> tuple[int, str, str]:
    score = sum(int(item.get("risk_weight", 1)) for item in detections)

    if score == 0:
        return (
            0,
            "No Model-Detected Risk",
            "Complete the manual PHI site inspection.",
        )
    if score <= 2:
        return (
            score,
            "Low Concern",
            "Inspect the detected object and record whether water or larvae are present.",
        )
    if score <= 5:
        return (
            score,
            "Moderate Concern",
            "PHI verification, a prevention warning and scheduled reinspection are recommended.",
        )
    return (
        score,
        "High Concern",
        "Prompt PHI review is recommended. Legal action must rely on verified field evidence and applicable law, not the model alone.",
    )


@router.get("/model-info")
def vision_model_info() -> dict:
    return {
        "status": "available" if vision_detector.model_path.exists() else "missing",
        "loaded": vision_detector.loaded,
        "model_path": str(vision_detector.model_path),
        "device": vision_detector.device,
        "classes": [
            "coconut_shell",
            "tire",
            "open_container",
            "water_storage",
            "drain_inlet",
        ],
    }


@router.post("/analyze-photo")
async def analyze_inspection_photo(
    file: UploadFile = File(...),
    inspection_id: str | None = Form(default=None),
    latitude: float | None = Form(default=None),
    longitude: float | None = Form(default=None),
    address: str | None = Form(default=None),
    confidence_threshold: float = Form(default=0.25),
    save_evidence: bool = Form(default=True),
) -> dict:
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Upload a JPEG, PNG or WebP image.",
        )

    if not 0.05 <= confidence_threshold <= 0.95:
        raise HTTPException(
            status_code=422,
            detail="confidence_threshold must be between 0.05 and 0.95.",
        )

    image_bytes = await file.read(MAX_IMAGE_BYTES + 1)
    await file.close()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds the 10 MB limit.")

    try:
        image = Image.open(io.BytesIO(image_bytes))
        image.load()
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Invalid image file.") from exc

    try:
        detections, raw_result = vision_detector.predict(
            image=image,
            confidence=confidence_threshold,
        )
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Vision inference failed: {exc}",
        ) from exc

    evidence_id = uuid.uuid4().hex
    observed_at = datetime.now(timezone.utc).isoformat()
    image_sha256 = hashlib.sha256(image_bytes).hexdigest()
    saved_files: dict[str, str] = {}

    if save_evidence:
        case_directory = evidence_root() / evidence_id
        case_directory.mkdir(parents=True, exist_ok=False)

        original_path = case_directory / "original.jpg"
        annotated_path = case_directory / "annotated.jpg"

        image.save(original_path, format="JPEG", quality=95)

        annotated_bgr = raw_result.plot()
        annotated_rgb = annotated_bgr[:, :, ::-1].copy()
        Image.fromarray(annotated_rgb).save(
            annotated_path,
            format="JPEG",
            quality=92,
        )

        saved_files = {
            "original": str(original_path),
            "annotated": str(annotated_path),
        }

    risk_score, risk_level, recommended_action = calculate_risk(detections)

    return {
        "status": "ok",
        "evidence_id": evidence_id,
        "inspection_id": inspection_id,
        "observed_at_utc": observed_at,
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "address": address,
        },
        "image": {
            "filename": Path(file.filename or "upload.jpg").name,
            "width": image.width,
            "height": image.height,
            "sha256": image_sha256,
        },
        "model": {
            "name": "Dengue Breeding-Risk Object Detector V1",
            "confidence_threshold": confidence_threshold,
        },
        "detection_count": len(detections),
        "detections": detections,
        "risk_summary": {
            "score": risk_score,
            "level": risk_level,
            "recommended_action": recommended_action,
        },
        "evidence_saved": save_evidence,
        "saved_files": saved_files,
        "requires_phi_verification": True,
        "legal_notice": (
            "This AI output is decision support only. A trained PHI officer must verify field conditions. The prediction alone must not be used as the sole basis for a warning, penalty or legal action."
        ),
    }
'@

$VisionServicePath = Join-Path $ServicesDir "vision_detector.py"
$VisionRouterPath = Join-Path $RoutersDir "inspection.py"

Set-Content -Path $VisionServicePath -Value $VisionService -Encoding UTF8
Set-Content -Path $VisionRouterPath -Value $VisionRouter -Encoding UTF8

$MainContent = Get-Content $MainFile -Raw
$RouterMarker = "from app.routers.inspection import router as inspection_router"

if ($MainContent -notmatch [regex]::Escape($RouterMarker)) {
    $MainAddition = @'

# PHI inspection computer-vision API
from app.routers.inspection import router as inspection_router
app.include_router(inspection_router)
'@
    Add-Content -Path $MainFile -Value $MainAddition -Encoding UTF8
}

if (Test-Path $RequirementsFile) {
    $RequirementsContent = Get-Content $RequirementsFile -Raw

    if ($RequirementsContent -notmatch "(?m)^ultralytics([=<>!~].*)?$") {
        Add-Content -Path $RequirementsFile -Value "`nultralytics==8.4.120" -Encoding UTF8
    }

    if ($RequirementsContent -notmatch "(?m)^python-multipart([=<>!~].*)?$") {
        Add-Content -Path $RequirementsFile -Value "python-multipart" -Encoding UTF8
    }
}

python -m py_compile $VisionServicePath $VisionRouterPath $MainFile

Write-Host ""
Write-Host "PHI VISION BACKEND PATCH APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Project: $ProjectRoot"
Write-Host "Model: $ModelFile"
Write-Host "Backup: $BackupDir"
Write-Host "Endpoint: POST /v1/inspection/analyze-photo"
Write-Host "Model info: GET /v1/inspection/model-info"
Write-Host "Evidence folder: $ProjectRoot\inspection_evidence"
Write-Host ""
Write-Host "Next: start the API and open /docs."
