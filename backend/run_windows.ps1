$ErrorActionPreference = "Stop"

if (-not (Test-Path ".venv")) {
    py -3.11 -m venv .venv
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& ".\.venv\Scripts\Activate.ps1"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env. Set MODEL_ROOT, then run this script again." -ForegroundColor Yellow
    exit 0
}

python scripts/verify_model_bundle.py
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
