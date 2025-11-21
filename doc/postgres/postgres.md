# IoT Management Telemetry - PostgreSQL

[Back](../../README.md)

- [IoT Management Telemetry - PostgreSQL](#iot-management-telemetry---postgresql)
  - [Postgresql](#postgresql)
    - [Develop with Docker Compose](#develop-with-docker-compose)
  - [Push to DockerHub](#push-to-dockerhub)
  - [Push to ECR](#push-to-ecr)

---

## Postgresql

```sh
# custom config
postgres -c config_file=/config/postgresql.dev.conf
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
docker build -t pgdb ./app/pgdb
docker tag pgdb simonangelfong/iot-mgnt-telemetry-pgdb
docker push simonangelfong/iot-mgnt-telemetry-pgdb
```

---

## Push to ECR

- Create ECR private repo

```sh
# aws ecr delete-repository --repository-name iot-mgnt-telemetry-pgdb --region ca-central-1
aws ecr create-repository --repository-name iot-mgnt-telemetry-pgdb --region ca-central-1

# confirm
aws ecr describe-repositories
```

- Authenticate and push

```sh
# authenticate your Docker client to ECR.
aws ecr get-login-password --region ca-central-1 | docker login --username AWS --password-stdin 099139718958.dkr.ecr.ca-central-1.amazonaws.com
# Login Succeeded

# Build your Docker image
docker build -t pgdb ./app/pgdb

# tag your image
docker tag pgdb 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-pgdb:dev

# push image to repository
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/iot-mgnt-telemetry-pgdb:dev

# confirm
aws ecr describe-images --repository-name iot-mgnt-telemetry-pgdb
```

---
