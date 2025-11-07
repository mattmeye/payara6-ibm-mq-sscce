# Payara 6 + IBM MQ SSL/TLS SSCCE

**Short, Self Contained, Correct Example** demonstrating Message-Driven Bean (MDB) with IBM MQ Resource Adapter using SSL/TLS certificate-based authentication.

## Overview

This project demonstrates:
- MDB activation with external Resource Adapter (IBM MQ)
- SSL/TLS certificate-based authentication
- Custom `SSLSocketFactory` embedded in WAR
- Connection pool pre-configured in `domain.xml`

## Prerequisites

- Docker with docker-compose
- Java 21
- Gradle 8.5+

## Quick Start

```bash
# 1. Generate SSL certificates
./docker/certs/generate-certificates.sh

# 2. Build the WAR
./gradlew clean build

# 3. Start services
docker-compose up -d

# 4. Wait for startup
sleep 30

# 5. Send test message
docker exec ibm-mq bash -c "echo 'Test message' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1"

# 6. Verify message received
docker logs payara 2>&1 | grep "MDB RECEIVED"
```

## Architecture

### SSL/TLS Configuration

- **IBM MQ Server**: Requires SSL/TLS on port 1414
- **Cipher Suite**: `ECDHE_RSA_AES_128_GCM_SHA256` (TLS 1.2)
- **Authentication**: Certificate-based (optional client certificate)
- **Certificates**: Self-signed CA with server and client certificates

### Payara Configuration

- **Connection Pool**: Pre-configured in `domain.xml`
- **SSLSocketFactory**: Custom implementation (`MQTruststoreSSLSocketFactory`) embedded in WAR
- **Package Structure**: `com.example.mq.*`
  - `com.example.mq.mdb.TestMessageBean` - Message-Driven Bean
  - `com.example.mq.ssl.MQTruststoreSSLSocketFactory` - Custom SSL factory

### Key Design Decision: domain.xml vs post-boot-commands

The connection pool is configured in `domain.xml` (not `post-boot-commands.asadmin`) to allow the custom `SSLSocketFactory` to be loaded from the WAR's classloader instead of requiring a separate JAR in `domain1/lib/`.

**Deployment Sequence:**
1. Payara starts → `domain.xml` loaded (connection pool config present but not instantiated)
2. RAR deployed via `post-boot-commands.asadmin`
3. WAR deployed (contains `SSLSocketFactory`)
4. MDB activation → Connection pool accessed → `SSLSocketFactory` instantiated from WAR

## Project Structure

```
payara6-ibm-mq-sscce/
├── build.gradle.kts
├── docker-compose.yml
├── docker/
│   ├── certs/
│   │   └── generate-certificates.sh      # SSL certificate generation
│   ├── ibm-mq/
│   │   ├── 01-setup-queues.mqsc         # Queue setup
│   │   ├── 03-configure-ssl.mqsc        # SSL/TLS configuration
│   │   └── setup-ssl.sh                 # SSL keystore setup
│   └── payara/
│       ├── domain.xml                    # Pre-configured connection pool
│       ├── post-boot-commands.asadmin   # Deployment commands
│       └── wmq.jakarta.jmsra.rar        # IBM MQ Resource Adapter
└── src/main/
    ├── java/com/example/mq/
    │   ├── mdb/
    │   │   └── TestMessageBean.java     # Message-Driven Bean
    │   └── ssl/
    │       └── MQTruststoreSSLSocketFactory.java  # Custom SSL factory
    └── webapp/WEB-INF/
        └── ejb-jar.xml                   # MDB deployment descriptor
```

## Key Files

### [TestMessageBean.java](src/main/java/com/example/mq/mdb/TestMessageBean.java)
Message-Driven Bean that consumes messages from `DEV.QUEUE.1`.

### [MQTruststoreSSLSocketFactory.java](src/main/java/com/example/mq/ssl/MQTruststoreSSLSocketFactory.java)
Custom `SSLSocketFactory` that reads truststore configuration from system properties:
- `mq.ssl.trustStore`
- `mq.ssl.trustStorePassword`
- `mq.ssl.trustStoreType`

### [domain.xml](docker/payara/domain.xml)
Payara domain configuration with pre-configured:
- `connector-connection-pool` (MQConnectionPool)
- `connector-resource` (jms/MQConnectionFactory)
- `admin-object-resource` (jms/DEV.QUEUE.1)

### [docker-compose.yml](docker-compose.yml)
Container orchestration mounting:
- WAR to `/tmp/test-mdb.war`
- RAR to `/tmp/wmq.jakarta.jmsra.rar`
- `domain.xml` (read-only) to Payara config directory
- SSL certificates to `/opt/payara/certs`

## SSL/TLS Details

### Certificate Generation

```bash
./docker/certs/generate-certificates.sh
```

Creates:
- **CA Certificate**: `docker/certs/ca/ca.crt`
- **MQ Server Certificate**: `docker/certs/mq/mq-server.p12` (CN=ibm-mq)
- **Payara Client Truststore**: `docker/certs/payara/payara-truststore.p12`

### IBM MQ Configuration

Channel: `DEV.APP.SVRCONN`
- **Cipher**: `ECDHE_RSA_AES_128_GCM_SHA256`
- **Client Auth**: `OPTIONAL` (for development)
- **Channel Auth**: Permissive ADDRESSMAP for all connections

### Payara Configuration

System Properties (via `JAVA_TOOL_OPTIONS` in docker-compose.yml):
```
-Dcom.ibm.mq.cfg.useIBMCipherMappings=false
-Dmq.ssl.trustStore=/opt/payara/certs/payara/payara-truststore.p12
-Dmq.ssl.trustStorePassword=payara
-Dmq.ssl.trustStoreType=PKCS12
```

## Verification Commands

```bash
# Check deployment
docker logs payara | grep "test-mdb was successfully deployed"

# Check SSL initialization
docker logs payara | grep "MQTruststoreSSLSocketFactory.*Successfully initialized"

# Verify MDB receives messages
docker exec ibm-mq bash -c "echo 'Test' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1"
docker logs payara | grep "MDB RECEIVED MESSAGE"

# Check IBM MQ SSL config
docker exec ibm-mq bash -c "echo 'DISPLAY CHANNEL(DEV.APP.SVRCONN) SSLCIPH SSLCAUTH' | runmqsc QM1"
```

## Environment Details

- **Payara**: 6.2024.10-jdk21
- **Jakarta EE**: 10
- **IBM MQ**: 9.4.0.0-r1
- **IBM MQ RAR**: 9.4.2.0 (Jakarta Messaging 3.1)

## Troubleshooting

### MDB Not Receiving Messages

Check logs for errors:
```bash
docker logs payara | grep -E "(ERROR|Exception|SEVERE)"
```

### SSL Handshake Failures

Verify certificates:
```bash
# Check MQ keystore
docker exec ibm-mq bash -c "runmqakm -cert -list -db /var/mqm/qmgrs/QM1/ssl/mq-server.kdb -stashed"

# Check Payara truststore
keytool -list -keystore docker/certs/payara/payara-truststore.p12 -storepass payara
```

### Connection Authorization Issues

Check IBM MQ authentication:
```bash
# Display CONNAUTH settings
docker exec ibm-mq bash -c "echo 'DISPLAY QMGR CONNAUTH' | runmqsc QM1"

# Display channel authentication
docker exec ibm-mq bash -c "echo 'DISPLAY CHLAUTH(DEV.APP.SVRCONN) ALL' | runmqsc QM1"
```

## Clean Restart

```bash
docker-compose down -v
docker-compose up -d
```

## License

Public Domain - use freely for testing and development.
