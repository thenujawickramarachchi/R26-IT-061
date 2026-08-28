# Sri Lankan Multilingual Dengue NLP Backend

FastAPI backend for the trained Sinhala, Singlish and English dengue NLP components.
The Android/mobile application sends text to this server; the multi-gigabyte models
must **not** be bundled inside the mobile APK.

## Included API behavior

- Context routing: `sufficient_context`, `needs_clarification`, `out_of_scope`, `requires_current_data`
- Closed-corpus QA/RAG retrieval with Top-5 supporting evidence
- Clinical claim verification using retrieved evidence plus multilingual NLI
- Deterministic historical WER numerical-claim checking
- Four-level report severity triage with a mandatory low-confidence review gate
- Optional API key, CORS configuration and no request-body logging
- Lazy model loading to reduce startup time

The backend follows FastAPI's application-lifespan/shared-resource approach, while
each large model is loaded only when its route is used.

## Important research limitations

- Severity V2 achieved **46.88% accuracy / 46.18% macro F1** on a 32-record official
  holdout. Emergency Alert recall was 87.5%. It is experimental triage, not a
  standalone public-health classifier.
- Severity training data is English-only and mainly controlled synthetic text.
- QA retrieval achieved 51.32% Top-1 exact-answer accuracy and 71.96% Top-5 recall.
- Clinical selective results and any 100% curated numeric results must be reported
  with their sample size, coverage and curated-dataset limitation.
- Low confidence, conflicting evidence, unavailable current statistics or missing
  context must return `Needs Review`/clarification rather than a guessed answer.

## Required model directory

Extract `Dengue_NLP_Final_Model_Bundle_v1.zip`. The configured `MODEL_ROOT` must
contain this exact structure:

```text
Dengue_NLP_Model/
├── context_classifier_v1/
├── clinical_nli_v1/
├── numeric_wer_checker_v1/
├── qa_rag_retriever_v1/
└── severity_classifier_v2/
```

## Windows 11 setup

Use Python **3.11**. Do not create the virtual environment from
`C:\Windows\System32`.

```powershell
mkdir C:\DengueProject
cd C:\DengueProject
# Extract the backend ZIP and model ZIP here.
cd .\dengue_nlp_backend

py -3.11 -m venv .venv
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

Copy-Item .env.example .env
notepad .env
```

Set the path in `.env`:

```env
MODEL_ROOT=C:/DengueProject/Dengue_NLP_Model
MODEL_DEVICE=auto
API_KEY=replace-with-a-long-random-secret
ALLOWED_ORIGINS=*
```

Verify the bundle and start one worker:

```powershell
python scripts\verify_model_bundle.py
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
```

Open:

- API health: `http://127.0.0.1:8000/health`
- Swagger test interface: `http://127.0.0.1:8000/docs`

The first request to a component can take time because that model is loaded lazily.

## Request example

PowerShell:

```powershell
$headers = @{ "X-API-Key" = "replace-with-a-long-random-secret" }
$body = @{
  text = "අවශ්‍ය නැහැ"
  previous_context = $null
  language = "Sinhala"
  operation = "auto"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "http://127.0.0.1:8000/v1/analyze" `
  -Method Post `
  -Headers $headers `
  -ContentType "application/json; charset=utf-8" `
  -Body $body
```

Explicit operations accepted by the same endpoint:

- `auto`
- `context`
- `question_answering`
- `claim_verification`
- `numeric_verification`
- `severity`

## Response outline

```json
{
  "request_id": "uuid",
  "route": "clarification",
  "status": "needs_clarification",
  "language": "Sinhala",
  "context": {
    "label": "needs_clarification",
    "confidence": 0.99
  },
  "answer": "කරුණාකර ඩෙංගු සම්බන්ධ සම්පූර්ණ ප්‍රශ්නය හෝ ප්‍රකාශය ලබා දෙන්න.",
  "truth": null,
  "severity": null,
  "evidence": [],
  "details": {},
  "safety_message": "Research prototype only..."
}
```

## Mobile connection

- Android emulator calling a backend on the same PC: `http://10.0.2.2:8000`
- Physical phone: use the PC's LAN IPv4 address, for example
  `http://192.168.1.20:8000`; phone and PC must be on the same network.
- Production: use HTTPS and keep the API key outside the mobile source repository.

## Docker CPU deployment

Place `dengue_nlp_backend` and `Dengue_NLP_Model` beside each other, then:

```bash
cp .env.example .env
docker compose up --build
```

Large models are mounted read-only. CPU inference will be slower. For a GPU server,
install a CUDA-compatible PyTorch build and use `MODEL_DEVICE=cuda`.

## Tests

The API tests use a fake pipeline and do not load the large model weights:

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest -q
```

## Production safety checklist

1. Do not expose the development server directly to the public internet.
2. Use HTTPS, authentication, rate limiting and a trusted reverse proxy.
3. Never log raw PHI/medical text without ethics approval and secure governance.
4. Refresh the official WER lookup when new reports are released.
5. Keep one API worker per loaded model set unless the server has enough RAM/VRAM
   for duplicated workers.
6. Send ambiguous, low-confidence and urgent clinical cases for human review.
