// js/utils.js

(function (global) {
  "use strict";

  /**
   * Map logical (x, y) in [-100, 100] to pixel position within the given rect.
   * This is purely math: no DOM access.
   */
  function mapToBox(x, y, rect) {
    if (!rect) return { left: 0, top: 0 };

    const { width, height } = rect;

    const nx = (x + 100) / 200; // -100..100 -> 0..1
    const ny = (y + 100) / 200;

    const left = nx * width;
    const top = (1 - ny) * height; // invert y so +y is up

    return { left, top };
  }

  /**
   * Find a device in the given list by alias.
   */
  function findDeviceByAlias(devices, alias) {
    return (devices || []).find((d) => d.alias === alias) || null;
  }

  /**
   * Fetch the device list from the API.
   * For demo: derive api_key from alias.
   */
  async function fetchDevices(baseUrl) {
    const url = `${baseUrl}/api/devices`;
    console.log("Fetching devices from:", url);

    const res = await fetch(url, {
      headers: {
        Accept: "application/json",
      },
    });

    if (!res.ok) {
      console.error("Device fetch failed", res.status, await res.text());
      throw new Error(`Device fetch failed: ${res.status}`);
    }

    const data = await res.json();
    // data shape:
    // [
    //   { device_uuid, alias, created_at, updated_at },
    //   ...
    // ]

    // Attach api_key = alias for demo purposes
    return data.map((d) => ({
      ...d,
      api_key: d.alias,
    }));
  }

  /**
   * Fetch latest telemetry for a given device.
   * Expects device to have { device_uuid, alias, api_key }.
   */
  async function fetchTelemetry(baseUrl, device) {
    if (!device) return null;

    const url = `${baseUrl}/api/telemetry/latest/${encodeURIComponent(
      device.device_uuid
    )}`;
    console.log("Fetching telemetry from:", url);

    const res = await fetch(url, {
      headers: {
        "x-api-key": device.api_key, // alias as API key (demo)
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
    //   device_uuid,
    //   alias,
    //   x_coord,
    //   y_coord,
    //   system_time_utc,
    //   device_time,
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

  // Expose helpers on a single namespace
  global.TelemetryUtils = {
    mapToBox,
    findDeviceByAlias,
    fetchDevices,
    fetchTelemetry,
  };
})(window);
