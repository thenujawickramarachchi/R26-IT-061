from __future__ import annotations

from collections.abc import Callable
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings
from app.schemas import AnalyzeRequest, AnalyzeResponse, HealthResponse
from app.security import verify_api_key
from app.services.pipeline import DenguePipeline


PipelineFactory = Callable[[Settings], DenguePipeline]


def create_app(
    settings: Settings | None = None,
    pipeline_factory: PipelineFactory = DenguePipeline,
) -> FastAPI:
    runtime_settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.settings = runtime_settings
        app.state.pipeline = pipeline_factory(runtime_settings)
        yield
        close = getattr(app.state.pipeline, "close", None)
        if callable(close):
            close()

    api = FastAPI(
        title=runtime_settings.app_name,
        version=runtime_settings.app_version,
        description=(
            "Context-aware Sinhala, Singlish and English dengue question answering, "
            "claim verification, official-number checking and severity triage."
        ),
        lifespan=lifespan,
    )
    api.state.settings = runtime_settings

    api.add_middleware(
        CORSMiddleware,
        allow_origins=runtime_settings.cors_origins,
        allow_credentials=runtime_settings.cors_origins != ["*"],
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type", "X-API-Key"],
    )

    @api.get("/", tags=["system"])
    async def root() -> dict[str, str]:
        return {
            "name": runtime_settings.app_name,
            "version": runtime_settings.app_version,
            "docs": "/docs",
        }

    @api.get("/health", response_model=HealthResponse, tags=["system"])
    async def health(request: Request) -> HealthResponse:
        pipeline = request.app.state.pipeline
        return HealthResponse(
            status="ok",
            version=runtime_settings.app_version,
            model_root_exists=runtime_settings.model_root.expanduser().is_dir(),
            components=pipeline.status(),
        )

    @api.post(
        "/v1/analyze",
        response_model=AnalyzeResponse,
        dependencies=[Depends(verify_api_key)],
        tags=["dengue"],
    )
    async def analyze(payload: AnalyzeRequest, request: Request) -> AnalyzeResponse:
        pipeline = request.app.state.pipeline
        result = await run_in_threadpool(
            pipeline.analyze,
            payload.text,
            payload.previous_context,
            payload.language,
            payload.operation,
            payload.top_k,
        )
        return AnalyzeResponse.model_validate(result)

    return api


app = create_app()

# PHI inspection computer-vision API
from app.routers.inspection import router as inspection_router
app.include_router(inspection_router)

# PHI annotated evidence image API
from app.routers.inspection_evidence import router as inspection_evidence_router
app.include_router(inspection_evidence_router)
