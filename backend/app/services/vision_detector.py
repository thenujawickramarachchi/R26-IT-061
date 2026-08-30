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
