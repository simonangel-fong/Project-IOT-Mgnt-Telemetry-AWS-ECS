// test_hp_read.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { parseNumberEnv, getDeviceForVU } from "./common.js";
import { getTelemetryLatest } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// High-performance read test parameters
const RATE_START = parseNumberEnv("RATE_START", 200); // initial RPS
const RATE_TARGET = parseNumberEnv("RATE_TARGET", 1500); // peak RPS
const STAGE_RAMP = parseNumberEnv("STAGE_RAMP", 3); // minutes per ramp stage
const STAGE_PEAK = parseNumberEnv("STAGE_PEAK", 10); // minutes to hold peak

// VU pool
const VU = parseNumberEnv("VU", 200); // pre-allocated VUs
const MAX_VU = parseNumberEnv("MAX_VU", 1500); // safety upper bound

// ==============================
// k6 options
// ==============================
export const options = {
  cloud: {
    name: "High-Performance Read Test",
  },

  thresholds: {
    http_req_failed: [
      {
        threshold: "rate<0.05", // less than 5% failures allowed under HP load
        abortOnFail: true,
        delayAbortEval: "1m",
      },
    ],

    // Focus on GET /telemetry
    "http_req_duration{endpoint:telemetry_get}": [
      "p(50)<150", // median
      "p(95)<400", // p95 under 400ms at high load
      "p(99)<800", // p99 under 800ms
    ],
  },

  scenarios: {
    hp_read_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: RATE_START, // initial RPS
      timeUnit: "1s", // RPS

      preAllocatedVUs: VU, // initial VU pool
      maxVUs: MAX_VU, // max VU

      stages: [
        // Ramp up
        { duration: `${STAGE_RAMP}m`, target: RATE_START },
        {
          duration: `${STAGE_RAMP}m`,
          target: Math.round(RATE_TARGET * 0.5),
        },
        {
          duration: `${STAGE_RAMP}m`,
          target: Math.round(RATE_TARGET * 0.75),
        },
        { duration: `${STAGE_RAMP}m`, target: RATE_TARGET },

        // Hold the peak RPS
        { duration: `${STAGE_PEAK}m`, target: RATE_TARGET },
      ],

      gracefulStop: "60s",
      exec: "hp_read_telemetry", // scenario function below
    },
  },
};

// ==============================
// Scenario function
// ==============================
const device = getDeviceForVU();

export function hp_read_telemetry() {
  getTelemetryLatest({ base_url: BASE_URL, device });
}

export default hp_read_telemetry;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "hp_read_test.json": JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
