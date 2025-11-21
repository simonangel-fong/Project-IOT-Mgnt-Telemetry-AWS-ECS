# IoT Management Telemetry - AWS ECS

[Back](../../README.md)

- [IoT Management Telemetry - AWS ECS](#iot-management-telemetry---aws-ecs)
  - [Terraform - AWS](#terraform---aws)
  - [Test](#test)

---

## Terraform - AWS

```sh
cd aws

terraform init -backend-config=backend.config
terraform fmt && terraform validate

terraform plan
terraform apply -auto-approve

terraform destroy -auto-approve
```

---

## Test

```sh
# home
curl "https://iot-dev.arguswatcher.net"
curl "https://iot-dev.arguswatcher.net/health"
curl "https://iot-dev.arguswatcher.net/health/db"
# list devices
curl "https://iot-dev.arguswatcher.net/devices"
# get device
curl "https://iot-dev.arguswatcher.net/devices/a5124a19-2725-4e07-9fdf-cb54a451204a"

# get telemetry:
curl "https://iot-dev.arguswatcher.net/telemetry/a5124a19-2725-4e07-9fdf-cb54a451204a" -H "Content-Type: application/json" -H "X-api-key: dev-alpha"

# post telemetry:
curl -X POST "https://iot-dev.arguswatcher.net/telemetry/a5124a19-2725-4e07-9fdf-cb54a451204a" ^
  -H "Content-Type: application/json" ^
  -H "X-api-key: dev-alpha" ^
  -d '{"x_coord": 123.456, "y_coord": 78.9, "device_time": "2025-11-17T18:31:56Z"}'
```
