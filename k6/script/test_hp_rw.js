// test_hp_rw.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { parseNumberEnv, getDeviceForVU } from "./common.js";
import { getTelemetryLatest, postTelemetry } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// -------- Write (POST) parameters --------
const W_RATE_START = parseNumberEnv("W_RATE_START", 200);    // initial write RPS
const W_RATE_TARGET = parseNumberEnv("W_RATE_TARGET", 1500); // peak write RPS
const W_STAGE_RAMP = parseNumberEnv("W_STAGE_RAMP", 3);      // minutes per write ramp stage
const W_STAGE_PEAK = parseNumberEnv("W_STAGE_PEAK", 10);     // minutes to hold peak write RPS

const W_VU = parseNumberEnv("W_VU", 200);       // pre-allocated VUs for write
const W_MAX_VU = parseNumberEnv("W_MAX_VU", 1500); // max VUs for write scenario

// -------- Read (GET) parameters --------
const R_RATE_MIN = parseNumberEnv("R_RATE_MIN", 200);   // min read RPS
const R_RATE_MAX = parseNumberEnv("R_RATE_MAX", 1500);  // max read RPS
const R_STAGE = parseNumberEnv("R_STAGE", 3);           // minutes per read stage
const R_STAGES = parseNumberEnv("R_STAGES", 5);         // number of random stages

const R_VU = parseNumberEnv("R_VU", 200);       // pre-allocated VUs for read
const R_MAX_VU = parseNumberEnv("R_MAX_VU", 1500); // max VUs for read scenario

// random read stages once at init-time
const readStages = Array.from({ length: R_STAGES }, () => {
  const target = Math.floor(
    R_RATE_MIN + Math.random() * (R_RATE_MAX - R_RATE_MIN)
  );
  return {
    duration: `${R_STAGE}m`,
    target,
  };
});

// ==============================
// k6 options
// ==============================
export const options = {
  cloud: {
    name: "High-Performance Read/Write Test",
  },

  thresholds: {
    // Global failure rate for both rw
    http_req_failed: [
      {
        threshold: "rate<0.05", // <5% failures allowed overall
        abortOnFail: true,
        delayAbortEval: "1m",
      },
    ],

    // Write performance (POST /telemetry)
    "http_req_duration{endpoint:telemetry_post}": [
      "p(50)<150",
      "p(95)<400",
      "p(99)<800",
    ],

    // Read performance (GET /telemetry)
    "http_req_duration{endpoint:telemetry_get}": [
      "p(50)<150",
      "p(95)<400",
      "p(99)<800",
    ],
  },

  scenarios: {
    // High-Perf Write (POST)
    hp_write_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: W_RATE_START, // initial write RPS
      timeUnit: "1s",

      preAllocatedVUs: W_VU,
      maxVUs: W_MAX_VU,

      stages: [
        // Ramp up writes
        { duration: `${W_STAGE_RAMP}m`, target: W_RATE_START },
        {
          duration: `${W_STAGE_RAMP}m`,
          target: Math.round(W_RATE_TARGET * 0.5),
        },
        {
          duration: `${W_STAGE_RAMP}m`,
          target: Math.round(W_RATE_TARGET * 0.75),
        },
        { duration: `${W_STAGE_RAMP}m`, target: W_RATE_TARGET },

        // Hold peak write RPS
        { duration: `${W_STAGE_PEAK}m`, target: W_RATE_TARGET },
      ],

      gracefulStop: "60s",
      exec: "hp_write_telemetry",
      tags: {
        scenario: "hp_write_telemetry",
      },
    },

    // High-Perf Read (GET)
    hp_read_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: readStages[0]?.target || R_RATE_MIN, // start from first random target
      timeUnit: "1s",

      preAllocatedVUs: R_VU,
      maxVUs: R_MAX_VU,

      stages: readStages, // random RPS per stage

      gracefulStop: "60s",
      exec: "hp_read_telemetry",
      tags: {
        scenario: "hp_read_telemetry",
      },
    },
  },
};

// ==============================
// Scenario functions
// ==============================
const device = getDeviceForVU();

export function hp_write_telemetry() {
  postTelemetry({ base_url: BASE_URL, device });
}

export function hp_read_telemetry() {
  getTelemetryLatest({ base_url: BASE_URL, device });
}

export default hp_write_telemetry;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "hp_rw_test.json": JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
