# IBM MQ Docker Image Setup

This document describes how to build and use the IBM MQ Docker image for this SSCCE project.

## For Apple Silicon (ARM64) Systems

IBM MQ does not provide official ARM64 Docker images. You must build a custom image using the IBM MQ Developer Image build tools.

### Prerequisites

- Docker Desktop for Mac (with Docker Compose)
- GNU make
- Git

### Building the ARM64 Image

1. **Clone the IBM MQ Container Repository**

   ```bash
   cd /tmp
   git clone --depth 1 https://github.com/ibm-messaging/mq-container.git
   cd mq-container
   ```

2. **Build the Developer Image**

   ```bash
   make build-devserver
   ```

   This command:
   - Downloads IBM MQ Advanced for Developers 9.4.3.1 for ARM64
   - Builds a Docker image tagged `ibm-mqadvanced-server-dev:9.4.3.1-arm64`
   - Takes approximately 5-10 minutes

3. **Verify the Image**

   ```bash
   docker images | grep ibm-mqadvanced-server-dev
   ```

   Expected output:
   ```
   ibm-mqadvanced-server-dev   9.4.3.1-arm64   <IMAGE_ID>   <TIME>   849MB
   ```

### Using the ARM64 Image

The `Dockerfile` in this directory is pre-configured to use the ARM64 image:

```dockerfile
FROM localhost/ibm-mqadvanced-server-dev:9.4.3.1-arm64
```

**Important:** Use `DOCKER_BUILDKIT=0` when building with docker-compose due to image referencing issues:

```bash
cd /Users/matt/projects/payara6-ibm-mq-sscce
DOCKER_BUILDKIT=0 docker-compose build
DOCKER_BUILDKIT=0 docker-compose up -d
```

---

## For AMD64 (Intel/AMD) Systems

AMD64 systems can use the official IBM MQ Docker images from IBM Container Registry (no custom build required).

### Using the Official AMD64 Image

1. **Update `docker/ibm-mq/Dockerfile`**

   Replace the FROM statement:

   ```dockerfile
   # IBM MQ 9.4 with custom queue configuration
   # Using official IBM MQ image for AMD64

   FROM icr.io/ibm-messaging/mq:9.4.0.0-r1

   # MQ Configuration
   ENV MQ_QMGR_NAME=QM1
   ENV MQ_APP_PASSWORD=passw0rd

   # Copy custom MQ configuration scripts
   COPY --chmod=755 01-create-queues.mqsc /etc/mqm/
   COPY --chmod=755 02-configure-security.mqsc /etc/mqm/

   # Expose ports
   EXPOSE 1414 9443
   ```

2. **Update `docker-compose.yml`**

   Add `platform: linux/amd64` to the `ibm-mq` service:

   ```yaml
   services:
     ibm-mq:
       build:
         context: ./docker/ibm-mq
         dockerfile: Dockerfile
       platform: linux/amd64
       container_name: ibm-mq
       hostname: ibm-mq
       # ... rest of configuration
   ```

3. **Build and Run**

   ```bash
   docker-compose build
   docker-compose up -d
   ```

### Available Official Images

- **Latest**: `icr.io/ibm-messaging/mq:latest`
- **9.4.0.0**: `icr.io/ibm-messaging/mq:9.4.0.0-r1`
- **9.3.x**: `icr.io/ibm-messaging/mq:9.3.x.x-rx`

See [IBM MQ Container Registry](https://ibm.biz/mq-container-images) for all available versions.

---

## Configuration Files

### 01-setup-queues.mqsc

Creates the following MQ objects:
- `DEV.QUEUE.1` - Main application queue with backout handling
- `DEV.BACKOUT.QUEUE` - For messages that fail after 3 retries
- `DEV.DEAD.LETTER.QUEUE` - For undeliverable messages

### 03-configure-ssl.mqsc

Configures SSL/TLS security:
- Enables channel authentication
- Creates SSL-enabled `DEV.APP.SVRCONN` channel with `ECDHE_RSA_AES_128_GCM_SHA256` cipher
- Sets up certificate-based authentication (SSLPEERMAP)
- Configures authorization for the `app` user

### setup-ssl.sh

Initializes the IBM MQ SSL keystore:
- Imports CA certificate
- Imports MQ server certificate and private key
- Sets proper permissions on keystore files

---

## Troubleshooting

### ARM64: "SIGSEGV: segmentation violation"

This occurs when trying to run AMD64 images on ARM64 without proper emulation:

**Solution:** Build the ARM64 developer image as described above.

### AMD64: "failed to resolve source metadata"

This occurs when the Dockerfile references a locally-built ARM64 image:

**Solution:** Update the Dockerfile to use the official AMD64 image as described above.

### "Connection refused" to MQ

If Payara cannot connect to IBM MQ:

1. Check MQ container is running:
   ```bash
   docker ps | grep ibm-mq
   ```

2. Check MQ health:
   ```bash
   docker logs ibm-mq
   ```

3. Verify network connectivity:
   ```bash
   docker exec payara ping -c 3 ibm-mq
   ```

---

## References

- [IBM MQ Container GitHub](https://github.com/ibm-messaging/mq-container)
- [Building MQ Developer Images](https://github.com/ibm-messaging/mq-container/blob/master/docs/building.md)
- [IBM MQ Container Registry](https://ibm.biz/mq-container-images)
