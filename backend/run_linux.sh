#!/usr/bin/env bash
set -euo pipefail

python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env. Set MODEL_ROOT, then run this script again."
  exit 0
fi

python scripts/verify_model_bundle.py
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
