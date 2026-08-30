from __future__ import annotations

import hashlib
import io
import os
import uuid
from datetime import date, datetime, timezone
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from PIL import Image, ImageOps, UnidentifiedImageError

from app.services.supabase_service import supabase_inspection_service
from app.services.vision_detector import vision_detector


router = APIRouter(prefix="/v1/inspection", tags=["PHI inspection"])

MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_INSPECTION_PHOTOS = 10
ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}


class CompleteInspectionRequest(BaseModel):
    field_verified: bool
    action_taken: str = Field(min_length=1, max_length=200)
    remarks: str | None = Field(default=None, max_length=2000)
    warning_issued: bool = False
    reinspection_date: date | None = None
    checklist: dict[str, bool] = Field(default_factory=dict)


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


@router.get("/database-status")
def database_status() -> dict:
    """Check whether the PHI inspection database connection is available."""
    try:
        return {"status": "ok", **supabase_inspection_service.status()}
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Supabase connection failed: {exc}",
        ) from exc


async def _analyze_uploaded_photo(
    file: UploadFile,
    *,
    inspection_id: str | None,
    latitude: float | None,
    longitude: float | None,
    address: str | None,
    confidence_threshold: float,
    save_evidence: bool,
) -> dict:
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"{file.filename or 'Image'}: upload a JPEG, PNG or WebP image.",
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
    """Backward-compatible single-photo inspection endpoint."""
    if not 0.05 <= confidence_threshold <= 0.95:
        raise HTTPException(
            status_code=422,
            detail="confidence_threshold must be between 0.05 and 0.95.",
        )

    result = await _analyze_uploaded_photo(
        file,
        inspection_id=inspection_id,
        latitude=latitude,
        longitude=longitude,
        address=address,
        confidence_threshold=confidence_threshold,
        save_evidence=save_evidence,
    )
    result["legal_notice"] = (
        "This AI output is decision support only. A trained PHI officer must verify field conditions. "
        "The prediction alone must not be used as the sole basis for a warning, penalty or legal action."
    )

    if inspection_id and supabase_inspection_service.configured:
        try:
            result["database"] = {
                "saved": True,
                **supabase_inspection_service.save_analysis(result),
            }
        except Exception as exc:
            result["database"] = {"saved": False, "error": str(exc)}
    else:
        result["database"] = {
            "saved": False,
            "error": "Supabase is not configured or inspection_id is missing.",
        }
    return result


@router.post("/analyze-photos")
async def analyze_inspection_photos(
    files: list[UploadFile] = File(...),
    inspection_id: str | None = Form(default=None),
    latitude: float | None = Form(default=None),
    longitude: float | None = Form(default=None),
    address: str | None = Form(default=None),
    confidence_threshold: float = Form(default=0.25),
    save_evidence: bool = Form(default=True),
) -> dict:
    """Analyze several evidence photos under one PHI inspection ID."""
    if not files:
        raise HTTPException(status_code=400, detail="Upload at least one inspection photo.")
    if len(files) > MAX_INSPECTION_PHOTOS:
        raise HTTPException(
            status_code=422,
            detail=f"A maximum of {MAX_INSPECTION_PHOTOS} photos is allowed per inspection.",
        )
    if not 0.05 <= confidence_threshold <= 0.95:
        raise HTTPException(
            status_code=422,
            detail="confidence_threshold must be between 0.05 and 0.95.",
        )

    photo_results: list[dict] = []
    combined_detections: list[dict] = []

    for index, file in enumerate(files, start=1):
        photo_result = await _analyze_uploaded_photo(
            file,
            inspection_id=inspection_id,
            latitude=latitude,
            longitude=longitude,
            address=address,
            confidence_threshold=confidence_threshold,
            save_evidence=save_evidence,
        )
        photo_result["photo_number"] = index
        photo_results.append(photo_result)
        combined_detections.extend(photo_result["detections"])

    total_score, overall_level, overall_action = calculate_risk(combined_detections)
    observed_at = datetime.now(timezone.utc).isoformat()

    result = {
        "status": "ok",
        "inspection_id": inspection_id,
        "observed_at_utc": observed_at,
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "address": address,
        },
        "photo_count": len(photo_results),
        "evidence_ids": [item["evidence_id"] for item in photo_results],
        "photos": photo_results,
        "detection_count": len(combined_detections),
        "detections": combined_detections,
        "risk_summary": {
            "score": total_score,
            "level": overall_level,
            "recommended_action": overall_action,
        },
        "requires_phi_verification": True,
        "legal_notice": (
            "This AI output is decision support only. A trained PHI officer must verify field conditions. "
            "The prediction alone must not be used as the sole basis for a warning, penalty or legal action."
        ),
    }

    if inspection_id and supabase_inspection_service.configured:
        try:
            result["database"] = {
                "saved": True,
                **supabase_inspection_service.save_analysis(result),
            }
        except Exception as exc:
            result["database"] = {"saved": False, "error": str(exc)}
    else:
        result["database"] = {
            "saved": False,
            "error": "Supabase is not configured or inspection_id is missing.",
        }
    return result


@router.post("/{inspection_id}/complete")
def complete_inspection(inspection_id: str, payload: CompleteInspectionRequest) -> dict:
    """Persist PHI verification, action taken and optional reinspection."""
    if not payload.field_verified:
        raise HTTPException(
            status_code=422,
            detail="The field condition must be PHI-verified before completion.",
        )
    if not supabase_inspection_service.configured:
        raise HTTPException(status_code=503, detail="Supabase is not configured.")

    try:
        saved = supabase_inspection_service.complete_inspection(
            inspection_id=inspection_id,
            field_verified=payload.field_verified,
            action_taken=payload.action_taken,
            remarks=payload.remarks,
            warning_issued=payload.warning_issued,
            reinspection_date=payload.reinspection_date,
            checklist=payload.checklist,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Could not save the completed inspection to Supabase: {exc}",
        ) from exc

    return {"status": "ok", "database_saved": True, **saved}
