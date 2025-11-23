# app/main.py
from __future__ import annotations
import os
import redis
from fastapi import FastAPI
# cors
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

# ====================
# CORS
# ====================
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_credentials=False,  # no cookies for devices
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "x-api-key"],
)


# ====================
# Root endpoint
# ====================
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
    print(settings.cors_list)
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

        response["postgres"] = {
            "host": settings.postgres.host,
            "port": settings.postgres.port,
            "db_name": settings.postgres.db,
            "user": settings.postgres.user,
        }

        response["redis"] = {
            "host": settings.redis.host,
            "port": settings.redis.port,
            "db_name": settings.redis.db,
        }

        response["cors"] = settings.cors_list

    return response

# ====================
# Routers
# ====================
# Health check & readiness probes
app.include_router(health.router, prefix=API_PREFIX)

# Administrative device registry endpoints (UUID-based lookups)
app.include_router(device.router, prefix=API_PREFIX)

# Device-facing telemetry ingestion and listing endpoints
app.include_router(telemetry.router, prefix=API_PREFIX)
