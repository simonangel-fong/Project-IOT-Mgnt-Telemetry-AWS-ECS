# app/main.py
from __future__ import annotations
import os
import redis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routers import health, device, telemetry
from .config.logging import setup_logging

setup_logging()

HOSTNAME = os.getenv("HOSTNAME", "my_host")
API_PREFIX = "/api"
settings = get_settings()

app = FastAPI(
    title="IoT Device Management API",
    version="0.1.0",
    description=(
        "Device Management API for registering IoT devices and handling their "
        "telemetry data. Device-facing endpoints authenticate using device UUIDs "
        "and API keys, while administrative endpoints are intended for internal "
        "operations and tooling."
    ),
)

# ============================================================
# CORS
# ============================================================
ALLOWED_ORIGINS = [
    # Frontend served directly from S3 website
    "http://iot-mgnt-telemetry-dev-web-bucket.s3-website.ca-central-1.amazonaws.com",

    # Frontend served via CloudFront
    "https://iot-dev.arguswatcher.net",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,  # no cookies for devices
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "x-api-key"],
)

# ============================================================
# Root endpoint
# ============================================================
@app.get(
    f"{API_PREFIX}/",
    tags=["root"],
    summary="Service status",
    description=(
        "Return basic information about the Device Management API service. "
    ),
)
async def home() -> dict:
    """
    Return basic service metadata and status.
    """
    response: dict = {
        "app": settings.app_name,
        "status": "ok",
        "environment": settings.env,
        "debug": settings.debug,
        "docs": {
            "openapi": "/openapi.json",
            "swagger_ui": "/docs",
            "redoc": "/redoc",
        },
    }

    if settings.debug:
        response["fastapi"] = {
            "fastapi_host": HOSTNAME,
        }

        pgdb_cfg = settings.postgres
        response["postgres"] = {
            "host": pgdb_cfg.host,
            "port": pgdb_cfg.port,
            "db_name": pgdb_cfg.db,
            "user": pgdb_cfg.user,
        }

        rd_cfg = settings.redis
        response["redis"] = {
            "host": rd_cfg.host,
            "port": rd_cfg.port,
            "db_name": rd_cfg.db,
        }

    return response

# ============================================================
# Routers
# ============================================================
# Health check & readiness probes
app.include_router(health.router, prefix=API_PREFIX)

# Administrative device registry endpoints (UUID-based lookups)
app.include_router(device.router, prefix=API_PREFIX)

# Device-facing telemetry ingestion and listing endpoints
app.include_router(telemetry.router, prefix=API_PREFIX)
