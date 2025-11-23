# IoT Management Telemetry - Performance Tuning

[Back](../../README.md)

- [IoT Management Telemetry - Performance Tuning](#iot-management-telemetry---performance-tuning)
  - [App Level](#app-level)
    - [FastAPI](#fastapi)
    - [PGDB](#pgdb)
  - [Architecture](#architecture)
    - [Redis](#redis)

---

## App Level

### FastAPI

| Parameter    | Value | Description                                                                             |
| ------------ | ----- | --------------------------------------------------------------------------------------- |
| pool_size    | 10    | Number of persistent DB connections kept in the SQLAlchemy connection pool.             |
| max_overflow | 10    | Extra “burst” connections allowed above `pool_size` during spikes in traffic.           |
| workers      | 2     | Number of FastAPI/Uvicorn worker processes handling requests in parallel.               |
| CPU core     | 2048  | ECS task CPU units (≈ 2 vCPUs) to provide enough compute for the app and its 2 workers. |

Target: 1200 RPS
Assume: DB operation = 50ms
Concurrency: 60 RPS

Effective max connections = workers \* (pool_size + max_overflow) = 2 \* ( 10 + 10 ) = 40

```sh
docker build -t fastapi ./app/fastapi && docker tag fastapi:latest 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-fastapi:dev && docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-fastapi:dev

cd aws && terraform fmt && terraform validate && terraform apply -auto-approve && cd ..

# reading
docker run --rm --name k6_hp_read -p 5665:5665 -e BASE_URL="https://iot-dev.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/aws_test_hp_read.html -v ./k6/script:/scripts -v ./k6/report:/report/ grafana/k6 run /scripts/test_hp_read.js

# write
docker run --rm --name k6_hp_write -p 5665:5665 -e BASE_URL="https://iot-dev.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/aws_test_hp_write.html -v ./k6/script:/scripts -v ./k6/report:/report/ grafana/k6 run /scripts/test_hp_write.js
```

### PGDB

---

## Architecture

### Redis
