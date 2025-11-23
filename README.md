# Project: IoT Management Telemetry

## Documentation

- Application:

  - [FastAPI](./doc/fastapi/fastapi.md)
  - [PostgreSQL](./doc/postgres/postgres.md)
  - [Redis](./doc/redis/redis.md)
  - [Device Simulator](./doc/device/device.md)

- Testing

  - [K6](./doc/k6/k6.md)

- Deployment

  - [AWS ECS](./doc/aws/aws.md)

- Dev cheapsheet

```sh
# push image
docker build -t fastapi ./app/fastapi
docker tag fastapi:latest 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-fastapi:dev
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-fastapi:dev

docker build -t pgdb ./app/pgdb
docker tag pgdb 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-pgdb:dev
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-pgdb:dev

docker build -t device ./app/device
docker tag device 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-device:dev
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-device:dev

# smoke testing
docker run --rm --name k6_smoke -p 5665:5665 -e BASE_URL="https://iot-dev.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/aws_test_smoke.html -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js
```
