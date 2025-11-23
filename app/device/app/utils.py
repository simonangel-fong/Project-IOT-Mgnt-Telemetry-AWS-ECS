# utils.py
from __future__ import annotations

import json
import logging
import os
import random
from datetime import datetime, timezone
from typing import Any, List

import requests
from model import Device


# ==============================
# parse env to float
# ==============================
def get_env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        return float(raw)
    except ValueError:
        logging.warning(
            "Invalid float for %s=%r, using default=%s", name, raw, default)
        return default


# ==============================
# load device from a json file
# ==============================
def load_devices(path: str) -> List[Device]:
    logging.info("Loading devices from %s", path)
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    if not isinstance(raw, list):
        raise ValueError("Devices JSON must be a list of objects.")

    devices: List[Device] = []
    for item in raw:
        try:
            devices.append(Device.from_dict(item))
        except ValueError as exc:
            logging.warning("Skipping invalid device entry %r: %s", item, exc)

    if not devices:
        raise ValueError("No valid devices found in JSON file.")

    logging.info("Loaded %d devices", len(devices))
    return devices


# ==============================
# Convert local time to utc
# ==============================
def now_utc_iso() -> str:
    """Return current time in UTC ISO 8601 with 'Z' suffix."""
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


# ==============================
# Radomize cooridnate
# ==============================
def random_coordinates() -> tuple[float, float]:
    """
    Generate random (x, y) in [-100, 100].
    You can adjust the range if your dashboard expects something else.
    """
    x = random.uniform(-100, 100)
    y = random.uniform(-100, 100)
    return x, y


# ==============================
# Build telemetry payload
# ==============================
def build_payload(ts: str) -> dict[str, Any]:
    """
    Build telemetry payload for a device.
    """
    payload = {
        "x_coord": random.uniform(-100, 100),
        "y_coord": random.uniform(-100, 100),
        "device_time": ts,
    }
    return payload


# ==============================
# Send telemetry payload
# ==============================
def send_telemetry(device: Device, target_endpoint: str, payload: dict) -> None:
    url = f"{target_endpoint}/{device.uuid}"

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "x-api-key": device.alias,
    }

    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=5)
    except requests.RequestException as exc:
        logging.error("Device %s: request error: %s", device.alias, exc)
        return

    if resp.status_code >= 200 and resp.status_code < 300:
        logging.info(
            "Device %s: sent telemetry x=%.2f y=%.2f -> %s %s",
            device.alias,
            payload["x_coord"],
            payload["y_coord"],
            resp.status_code,
            resp.reason,
        )
    else:
        try:
            body = resp.text
        except Exception:
            body = "<unreadable>"
        logging.warning(
            "Device %s: telemetry failed -> %s %s, body=%s",
            device.alias,
            resp.status_code,
            resp.reason,
            body,
        )
