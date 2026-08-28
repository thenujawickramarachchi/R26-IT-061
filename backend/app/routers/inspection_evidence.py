from __future__ import annotations

import os
import re
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse


router = APIRouter(prefix="/v1/inspection", tags=["PHI inspection"])


def evidence_root() -> Path:
    configured = os.getenv("DENGUE_EVIDENCE_DIR")
    if configured:
        return Path(configured).expanduser().resolve()

    project_root = Path(__file__).resolve().parents[2]
    return project_root / "inspection_evidence"


def validate_evidence_id(evidence_id: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{32}", evidence_id):
        raise HTTPException(status_code=404, detail="Evidence image not found.")
    return evidence_id


@router.get(
    "/evidence/{evidence_id}/annotated",
    name="get_annotated_inspection_evidence",
    response_class=FileResponse,
)
def get_annotated_evidence(evidence_id: str) -> FileResponse:
    safe_id = validate_evidence_id(evidence_id)
    image_path = evidence_root() / safe_id / "annotated.jpg"

    if not image_path.is_file():
        raise HTTPException(status_code=404, detail="Evidence image not found.")

    return FileResponse(
        path=image_path,
        media_type="image/jpeg",
        filename=f"{safe_id}_annotated.jpg",
        headers={"Cache-Control": "no-store"},
    )
