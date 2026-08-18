"""FindMe backend -- FastAPI entrypoint. Replaces Supabase's auto-generated PostgREST
API + Edge Functions with one service owning routing, auth, and business logic
directly."""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.core.errors import AppError
from app.routers import alerts as alerts_router
from app.routers import auth as auth_router
from app.routers import billing as billing_router
from app.routers import consents as consents_router
from app.routers import devices as devices_router
from app.routers import geofences as geofences_router
from app.routers import ingest as ingest_router
from app.routers import intel as intel_router
from app.routers import map as map_router
from app.routers import referrals as referrals_router
from app.routers import uploads as uploads_router

settings = get_settings()

app = FastAPI(title="FindMe API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})


app.include_router(auth_router.router)
app.include_router(devices_router.router)
app.include_router(consents_router.router)
app.include_router(geofences_router.router)
app.include_router(map_router.router)
app.include_router(alerts_router.router)
app.include_router(intel_router.router)
app.include_router(billing_router.router)
app.include_router(referrals_router.router)
app.include_router(ingest_router.router)
app.include_router(uploads_router.router)


@app.get("/healthz", tags=["meta"])
async def healthz() -> dict[str, str]:
    return {"status": "ok"}
