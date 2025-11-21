# IoT Management Telemetry - Redis

[Back](../../README.md)

- [IoT Management Telemetry - Redis](#iot-management-telemetry---redis)
  - [Redis](#redis)
    - [Develop with Docker Compose](#develop-with-docker-compose)
  - [Push to DockerHub](#push-to-dockerhub)
  - [Push to ECR](#push-to-ecr)

---

## Redis

```sh
# custom config
redis-server /usr/local/etc/redis/redis.conf
```

---

### Develop with Docker Compose

```sh
docker compose -f ./app/docker-compose.yaml down -v
docker compose -f ./app/docker-compose.yaml up -d --build
```

---

## Push to DockerHub

```sh
docker build -t redis ./app/redis
docker tag redis simonangelfong/iot-mgnt-telemetry-redis
docker push simonangelfong/iot-mgnt-telemetry-redis
```

---

## Push to ECR

- Create ECR private repo

```sh
# aws ecr delete-repository --repository-name iot-mgnt-telemetry-redis --region ca-central-1
aws ecr create-repository --repository-name iot-mgnt-telemetry-redis --region ca-central-1

# confirm
aws ecr describe-repositories
```

- Authenticate and push

```sh
# authenticate your Docker client to ECR.
aws ecr get-login-password --region ca-central-1 | docker login --username AWS --password-stdin 099139718958.dkr.ecr.ca-central-1.amazonaws.com
# Login Succeeded

# Build your Docker image
docker build -t pgdb ./app/redis

# tag your image
docker tag redis 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-redis:dev

# push image to repository
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-redis:dev

# confirm
aws ecr describe-images --repository-name iot-mgnt-telemetry-pgdb
```

---
