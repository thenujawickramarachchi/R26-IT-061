from __future__ import annotations

import os
import re
import threading
from datetime import date
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from supabase import Client, create_client


class SupabaseInspectionService:
    """Persist PHI inspection records and evidence to Supabase."""

    def __init__(self) -> None:
        load_dotenv()
        self.url = (os.getenv("SUPABASE_URL") or "").strip()
        self.secret_key = (os.getenv("SUPABASE_SECRET_KEY") or "").strip()
        self.bucket = (os.getenv("SUPABASE_STORAGE_BUCKET") or "inspection-evidence").strip()
        self._client: Client | None = None
        self._lock = threading.RLock()

    @property
    def configured(self) -> bool:
        return bool(self.url and self.secret_key and self.bucket)

    def client(self) -> Client:
        if not self.configured:
            raise RuntimeError(
                "Supabase is not configured. Set SUPABASE_URL, "
                "SUPABASE_SECRET_KEY and SUPABASE_STORAGE_BUCKET in .env."
            )
        if self._client is None:
            with self._lock:
                if self._client is None:
                    self._client = create_client(self.url, self.secret_key)
        return self._client

    @staticmethod
    def _safe_segment(value: str) -> str:
        cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
        return cleaned.strip("._") or "inspection"

    def status(self) -> dict[str, Any]:
        if not self.configured:
            return {
                "configured": False,
                "connected": False,
                "bucket": self.bucket or None,
            }

        response = self.client().table("inspections").select("id").limit(1).execute()
        return {
            "configured": True,
            "connected": True,
            "bucket": self.bucket,
            "sample_rows": len(response.data or []),
        }

    def _upload_jpeg(self, inspection_id: str, evidence_id: str, kind: str, local_path: str) -> str:
        safe_inspection = self._safe_segment(inspection_id)
        safe_evidence = self._safe_segment(evidence_id)
        object_path = f"{safe_inspection}/{safe_evidence}/{kind}.jpg"

        with Path(local_path).open("rb") as file_handle:
            self.client().storage.from_(self.bucket).upload(
                path=object_path,
                file=file_handle,
                file_options={
                    "cache-control": "3600",
                    "upsert": "false",
                    "content-type": "image/jpeg",
                },
            )

        # The bucket is private. Store a stable internal URI, not an expiring signed URL.
        return f"storage://{self.bucket}/{object_path}"

    def save_analysis(self, result: dict[str, Any]) -> dict[str, Any]:
        inspection_id = str(result.get("inspection_id") or "").strip()
        if not inspection_id:
            raise ValueError("inspection_id is required before an inspection can be saved.")

        location = result.get("location") or {}
        risk = result.get("risk_summary") or {}
        photos = result.get("photos")
        if not isinstance(photos, list):
            photos = [result]

        inspection_row = {
            "inspection_id": inspection_id,
            "address": location.get("address"),
            "latitude": location.get("latitude"),
            "longitude": location.get("longitude"),
            "risk_score": int(risk.get("score") or 0),
            "risk_level": risk.get("level"),
            "status": "analyzed",
        }
        existing = (
            self.client()
            .table("inspections")
            .select("id")
            .eq("inspection_id", inspection_id)
            .limit(1)
            .execute()
        )
        if existing.data:
            (
                self.client()
                .table("inspections")
                .update(inspection_row)
                .eq("inspection_id", inspection_id)
                .execute()
            )
        else:
            self.client().table("inspections").insert(inspection_row).execute()

        saved_photo_rows: list[dict[str, Any]] = []
        for photo in photos:
            if not isinstance(photo, dict):
                continue

            evidence_id = str(photo.get("evidence_id") or "").strip()
            if not evidence_id:
                continue

            saved_files = photo.get("saved_files") or {}
            original_uri: str | None = None
            annotated_uri: str | None = None

            original_path = saved_files.get("original")
            annotated_path = saved_files.get("annotated")
            if original_path and Path(str(original_path)).is_file():
                original_uri = self._upload_jpeg(
                    inspection_id, evidence_id, "original", str(original_path)
                )
            if annotated_path and Path(str(annotated_path)).is_file():
                annotated_uri = self._upload_jpeg(
                    inspection_id, evidence_id, "annotated", str(annotated_path)
                )

            photo_risk = photo.get("risk_summary") or {}
            row = {
                "inspection_id": inspection_id,
                "evidence_id": evidence_id,
                "original_image_url": original_uri,
                "annotated_image_url": annotated_uri,
                "detection_count": int(photo.get("detection_count") or 0),
                "risk_score": int(photo_risk.get("score") or 0),
                "risk_level": photo_risk.get("level"),
                "detections": photo.get("detections") or [],
            }
            self.client().table("inspection_photos").insert(row).execute()
            saved_photo_rows.append(row)

        return {
            "inspection_id": inspection_id,
            "photo_rows_saved": len(saved_photo_rows),
            "bucket": self.bucket,
        }

    def complete_inspection(
        self,
        *,
        inspection_id: str,
        field_verified: bool,
        action_taken: str,
        remarks: str | None,
        warning_issued: bool,
        reinspection_date: date | None,
        checklist: dict[str, bool],
    ) -> dict[str, Any]:
        inspection_id = inspection_id.strip()
        if not inspection_id:
            raise ValueError("inspection_id is required.")

        current = (
            self.client()
            .table("inspections")
            .select("inspection_id")
            .eq("inspection_id", inspection_id)
            .limit(1)
            .execute()
        )
        if not current.data:
            raise ValueError(f"Inspection {inspection_id} was not found in Supabase.")

        status_value = "reinspection_required" if reinspection_date else "verified"
        self.client().table("inspections").update(
            {
                "status": status_value,
                "remarks": remarks or None,
            }
        ).eq("inspection_id", inspection_id).execute()

        findings = {
            "inspection_id": inspection_id,
            # These are not inferred from the AI result. They stay unknown until
            # explicit manual fields are added to the mobile UI.
            "breeding_site_found": None,
            "larvae_found": None,
            "containers_checked": None,
            "positive_containers": None,
            "water_containers_checked": bool(checklist.get("Water containers checked", False)),
            "gutters_checked": bool(checklist.get("Gutters checked", False)),
            "tyres_checked": bool(checklist.get("Tyres checked", False)),
            "drains_checked": bool(checklist.get("Drains checked", False)),
            "waste_checked": bool(checklist.get("Waste accumulation checked", False)),
            "water_tanks_checked": bool(checklist.get("Water tanks covered", False)),
            "phi_verified": bool(field_verified),
            "verification_notes": remarks or None,
        }
        existing_findings = (
            self.client()
            .table("inspection_findings")
            .select("id")
            .eq("inspection_id", inspection_id)
            .limit(1)
            .execute()
        )
        if existing_findings.data:
            (
                self.client()
                .table("inspection_findings")
                .update(findings)
                .eq("inspection_id", inspection_id)
                .execute()
            )
        else:
            self.client().table("inspection_findings").insert(findings).execute()

        # Keep one final action row for this save operation.
        self.client().table("inspection_actions").insert(
            {
                "inspection_id": inspection_id,
                "action_taken": action_taken.strip(),
                "warning_issued": bool(warning_issued),
                "remarks": remarks or None,
            }
        ).execute()

        if reinspection_date is not None:
            self.client().table("reinspections").insert(
                {
                    "inspection_id": inspection_id,
                    "reinspection_date": reinspection_date.isoformat(),
                    "status": "scheduled",
                    "resolved": False,
                    "notes": remarks or None,
                }
            ).execute()

        return {
            "inspection_id": inspection_id,
            "status": status_value,
            "field_verified": bool(field_verified),
            "reinspection_date": reinspection_date.isoformat() if reinspection_date else None,
        }


supabase_inspection_service = SupabaseInspectionService()
