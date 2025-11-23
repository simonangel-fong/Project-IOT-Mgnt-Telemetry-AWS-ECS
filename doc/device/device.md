# IoT Management Telemetry - Device Simulator

[Back](../../README.md)

- [IoT Management Telemetry - Device Simulator](#iot-management-telemetry---device-simulator)
  - [Device Simulator](#device-simulator)
    - [Develop with Docker Compose](#develop-with-docker-compose)
  - [Push to DockerHub](#push-to-dockerhub)
  - [Push to ECR](#push-to-ecr)

---

## Device Simulator


### Develop with Docker Compose

```sh
docker compose -f ./app/docker-compose.yaml down -v
docker compose -f ./app/docker-compose.yaml up -d --build
```

---

## Push to DockerHub

```sh
docker build -t device ./app/device
docker tag device simonangelfong/iot-mgnt-telemetry-device
docker push simonangelfong/iot-mgnt-telemetry-device
```

---

## Push to ECR

- Create ECR private repo

```sh
# aws ecr delete-repository --repository-name iot-mgnt-telemetry-device --region ca-central-1
aws ecr create-repository --repository-name iot-mgnt-telemetry-device --region ca-central-1

# confirm
aws ecr describe-repositories
```

- Authenticate and push

```sh
# authenticate your Docker client to ECR.
aws ecr get-login-password --region ca-central-1 | docker login --username AWS --password-stdin 099139718958.dkr.ecr.ca-central-1.amazonaws.com
# Login Succeeded

# Build your Docker image
docker build -t device ./app/device

# tag your image
docker tag device 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-device:dev

# push image to repository
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-device:dev

# confirm
aws ecr describe-images --repository-name iot-mgnt-telemetry-pgdb
```

---
