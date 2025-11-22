// js/telemetry.js

// Base URL for your *dev* API
const BASE_URL = "https://iot-dev.arguswatcher.net";

// Use DEVICES from sample-device.js
const DEVICES = window.DEVICES || [];

// ==============================
// DOM references
// ==============================
const deviceSelect = document.getElementById("device-select");
const statusDevice = document.getElementById("status-device");
const statusUpdated = document.getElementById("status-updated");

const telemetryBox = document.getElementById("telemetry-box");
const devicePoint = document.getElementById("device-point");
const devicePointLabel = document.getElementById("device-point-label");

const infoDevice = document.getElementById("info-device");
const infoX = document.getElementById("info-x");
const infoY = document.getElementById("info-y");
const infoUpdated = document.getElementById("info-updated");

// ==============================
// Populate device dropdown
// ==============================
function populateDeviceSelect() {
  if (!deviceSelect) return;
  DEVICES.forEach((d) => {
    const opt = document.createElement("option");
    opt.value = d.alias;      // we'll use alias as the selected value
    opt.textContent = d.alias;
    deviceSelect.appendChild(opt);
  });
}

// ==============================
// Coordinate mapping helper
// ==============================
// Map logical (x,y) in [-100, 100] to pixel position in the box
function mapToBox(x, y) {
  const rect = telemetryBox.getBoundingClientRect();
  const width = rect.width;
  const height = rect.height;

  const nx = (x + 100) / 200;  // -100..100 -> 0..1
  const ny = (y + 100) / 200;

  const left = nx * width;
  const top = (1 - ny) * height; // invert y so +y is up

  return { left, top };
}

// ==============================
// UI update helper
// ==============================
function updateDevicePosition(deviceLabel, x, y, timestamp) {
  const { left, top } = mapToBox(x, y);
  devicePoint.style.left = `${left}px`;
  devicePoint.style.top = `${top}px`;

  const timeDisplay = timestamp || new Date().toISOString();

  devicePointLabel.textContent = deviceLabel || "device";
  statusDevice.textContent = deviceLabel || "None";
  statusUpdated.textContent = timeDisplay;

  infoDevice.textContent = deviceLabel || "–";
  infoX.textContent = typeof x === "number" ? x.toFixed(2) : "–";
  infoY.textContent = typeof y === "number" ? y.toFixed(2) : "–";
  infoUpdated.textContent = timeDisplay;
}

// Expose globally if you want to test from console
window.updateDevicePosition = updateDevicePosition;

// ==============================
// Device lookup
// ==============================
function findDeviceByAlias(alias) {
  return DEVICES.find((d) => d.alias === alias) || null;
}

// ==============================
// Telemetry fetching
// ==============================
async function fetchTelemetry(device) {
  if (!device) return null;

  const url = `${BASE_URL}/telemetry/latest/${encodeURIComponent(
    device.device_uuid
  )}`;

  const res = await fetch(url, {
    headers: {
      "x-api-key": device.api_key, // alias as API key
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    console.error("Telemetry fetch failed", res.status, await res.text());
    throw new Error(`Telemetry fetch failed: ${res.status}`);
  }

  const data = await res.json();
  // Expected shape:
  // {
  //   "device_uuid": "...",
  //   "alias": "device-001",
  //   "x_coord": 1.2,
  //   "y_coord": 3.4,
  //   "system_time_utc": "...",
  //   "device_time": "..."
  // }

  const x = data.x_coord;
  const y = data.y_coord;
  const alias = data.alias || device.alias;
  const deviceTime = data.device_time || data.system_time_utc;

  if (typeof x !== "number" || typeof y !== "number") {
    console.warn("Telemetry response missing numeric x_coord/y_coord:", data);
    return null;
  }

  return { x, y, alias, deviceTime };
}

// ==============================
// Polling logic
// ==============================
let pollingTimer = null;
let currentDevice = null;

function startPolling(device) {
  if (pollingTimer) {
    clearInterval(pollingTimer);
    pollingTimer = null;
  }

  currentDevice = device;
  if (!device) return;

  // Fetch once immediately
  refreshTelemetry();

  // Then every 3 seconds
  pollingTimer = setInterval(refreshTelemetry, 3000);
}

async function refreshTelemetry() {
  if (!currentDevice) return;

  try {
    const result = await fetchTelemetry(currentDevice);
    if (!result) return;

    updateDevicePosition(
      result.alias,
      result.x,
      result.y,
      result.deviceTime
    );
  } catch (err) {
    console.error("Error refreshing telemetry:", err);
    // You could update a "status" element here if you add one
  }
}

// ==============================
// Event: device selection
// ==============================
if (deviceSelect) {
  deviceSelect.addEventListener("change", () => {
    const alias = deviceSelect.value;
    if (!alias) return;

    const device = findDeviceByAlias(alias);
    if (!device) {
      console.warn("Selected alias not found in DEVICES:", alias);
      return;
    }

    startPolling(device);
  });
}

// ==============================
// Init on page load
// ==============================
window.addEventListener("DOMContentLoaded", () => {
  populateDeviceSelect();

  // Optional: auto-select first device
  const firstRealOption = deviceSelect.querySelector("option[value]");
  if (firstRealOption && !deviceSelect.value) {
    deviceSelect.value = firstRealOption.value;
    const device = findDeviceByAlias(firstRealOption.value);
    if (device) {
      startPolling(device);
    }
  }
});
