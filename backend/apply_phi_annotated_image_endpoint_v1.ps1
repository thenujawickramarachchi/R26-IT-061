$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Location).Path
$AppDir = Join-Path $ProjectRoot "app"
$MainFile = Join-Path $AppDir "main.py"
$RoutersDir = Join-Path $AppDir "routers"

if (-not (Test-Path $MainFile)) {
    throw "app\main.py was not found. Run this script from C:\DengueProject."
}

if (-not (Test-Path $RoutersDir)) {
    throw "app\routers was not found. Apply the PHI vision backend patch first."
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ProjectRoot "vision_patch_backups\before_evidence_url_$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $MainFile (Join-Path $BackupDir "main.py") -Force

$EvidenceRouter = @'
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
'@

$EvidenceRouterPath = Join-Path $RoutersDir "inspection_evidence.py"
Set-Content -Path $EvidenceRouterPath -Value $EvidenceRouter -Encoding UTF8

$MainContent = Get-Content $MainFile -Raw
$RouterMarker = "from app.routers.inspection_evidence import router as inspection_evidence_router"

if ($MainContent -notmatch [regex]::Escape($RouterMarker)) {
    $MainAddition = @'

# PHI annotated evidence image API
from app.routers.inspection_evidence import router as inspection_evidence_router
app.include_router(inspection_evidence_router)
'@
    Add-Content -Path $MainFile -Value $MainAddition -Encoding UTF8
}

python -m py_compile $EvidenceRouterPath $MainFile

Write-Host ""
Write-Host "ANNOTATED EVIDENCE IMAGE ENDPOINT APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Project: $ProjectRoot"
Write-Host "Backup: $BackupDir"
Write-Host "Endpoint: GET /v1/inspection/evidence/{evidence_id}/annotated"
Write-Host ""
Write-Host "Next: restart the API and test the image URL."
