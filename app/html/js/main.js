// js/main.js

"use strict";

// ==============================
// Config
// ==============================

// Base URL for your *dev* API
const BASE_URL = "https://iot-dev.arguswatcher.net";
// const BASE_URL = "http://localhost:8080";

// ==============================
// Import helpers from utils.js
// ==============================
const Utils = window.TelemetryUtils || {};
const { mapToBox, fetchDevices, fetchTelemetry, findDeviceByAlias } = Utils;

// Basic guard in case utils.js is missing
if (!mapToBox || !fetchDevices || !fetchTelemetry || !findDeviceByAlias) {
  console.error("TelemetryUtils is not properly loaded. Check script order.");
}

// ==============================
// State
// ==============================
const state = {
  devices: [],
  currentDevice: null,
  pollingTimer: null,
  pollingIntervalMs: 1000,  // 1s
};

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

// =====================================================================
// UI helpers: DOM updates & data binding
// =====================================================================

/**
 * Update the dashboard UI with the given telemetry.
 */
function updateDevicePosition(deviceLabel, x, y, timestamp) {
  if (!telemetryBox || !devicePoint || !devicePointLabel) return;

  const rect = telemetryBox.getBoundingClientRect();
  const { left, top } = mapToBox(x, y, rect);

  devicePoint.style.left = `${left}px`;
  devicePoint.style.top = `${top}px`;

  const timeDisplay = timestamp || new Date().toISOString();
  const label = deviceLabel || "device";

  devicePointLabel.textContent = label;

  if (statusDevice) statusDevice.textContent = label;
  if (statusUpdated) statusUpdated.textContent = timeDisplay;

  if (infoDevice) infoDevice.textContent = label;
  if (infoX) infoX.textContent = typeof x === "number" ? x.toFixed(2) : "–";
  if (infoY) infoY.textContent = typeof y === "number" ? y.toFixed(2) : "–";
  if (infoUpdated) infoUpdated.textContent = timeDisplay;
}

// Expose for manual testing in the browser console
window.updateDevicePosition = updateDevicePosition;

/**
 * Populate the <select> with devices.
 */
function populateDeviceSelect(devices) {
  if (!deviceSelect) return;

  // Remove any existing device options (keep placeholder)
  deviceSelect
    .querySelectorAll("option[data-device-option]")
    .forEach((opt) => opt.remove());

  devices.forEach((d) => {
    const opt = document.createElement("option");
    opt.value = d.alias;
    opt.textContent = d.alias;
    opt.setAttribute("data-device-option", "true");
    deviceSelect.appendChild(opt);
  });
}

/**
 * Start polling telemetry for a given device.
 */
function startPolling(device) {
  // Clear any existing timer
  if (state.pollingTimer) {
    clearInterval(state.pollingTimer);
    state.pollingTimer = null;
  }

  state.currentDevice = device;
  if (!device) return;

  // Fetch once immediately
  refreshTelemetry();

  // Then every N ms
  state.pollingTimer = setInterval(refreshTelemetry, state.pollingIntervalMs);
}

/**
 * Refresh telemetry for the current device.
 */
async function refreshTelemetry() {
  const device = state.currentDevice;
  if (!device) return;

  try {
    const result = await fetchTelemetry(BASE_URL, device);
    if (!result) return;

    updateDevicePosition(result.alias, result.x, result.y, result.deviceTime);
  } catch (err) {
    console.error("Error refreshing telemetry:", err);
    if (statusDevice) statusDevice.textContent = "Error";
    if (statusUpdated) statusUpdated.textContent = new Date().toISOString();
  }
}

/**
 * Bind change listener for device dropdown.
 */
function bindDeviceSelectEvents() {
  if (!deviceSelect) return;

  deviceSelect.addEventListener("change", () => {
    const alias = deviceSelect.value;
    if (!alias) return;

    const device = findDeviceByAlias(state.devices, alias);
    if (!device) {
      console.warn("Selected alias not found in devices:", alias);
      return;
    }

    startPolling(device);
  });
}

/**
 * Initial page setup: fetch devices, populate dropdown, auto-select first.
 */
async function initTelemetryDashboard() {
  try {
    const devices = await fetchDevices(BASE_URL);
    state.devices = devices;

    populateDeviceSelect(devices);
    bindDeviceSelectEvents();

    // Auto-select first device if nothing selected
    if (deviceSelect && !deviceSelect.value && devices.length > 0) {
      deviceSelect.value = devices[0].alias;
      startPolling(devices[0]);
    }
  } catch (err) {
    console.error("Failed to initialize telemetry dashboard:", err);
    if (statusDevice) statusDevice.textContent = "Init error";
    if (statusUpdated) statusUpdated.textContent = new Date().toISOString();
  }
}

// ==============================
// Init on page load
// ==============================
window.addEventListener("DOMContentLoaded", () => {
  if (!window.TelemetryUtils) {
    console.error(
      "TelemetryUtils not found. Make sure utils.js is loaded first."
    );
    return;
  }
  initTelemetryDashboard();
});
