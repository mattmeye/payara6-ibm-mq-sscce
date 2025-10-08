# Payara 6 MDB + External Resource Adapter SSCCE

**Short, Self Contained, Correct Example** demonstrating MDB activation failure with external Resource Adapter in Payara 6.2024.10.

## What This Demonstrates

Message-Driven Bean configured to use external Jakarta Resource Adapter (IBM MQ) is silently ignored during deployment.

## Prerequisites

- Docker with docker-compose
- Java 21 (for local build)
- Gradle 8.5+

## Quick Start

```bash
# Build the WAR
./gradlew build

# Start Payara + IBM MQ
docker-compose up -d

# Wait for deployment (30 seconds)
sleep 30

# Check if MDB was activated
docker logs payara 2>&1 | grep -i "TestMessageBean"
# Expected: Should see "Portable JNDI names for EJB TestMessageBean"
# Actual: NO OUTPUT - MDB is silently ignored
```

## Expected vs Actual Behavior

### Expected
- MDB `TestMessageBean` should be detected and activated
- MDB should appear in server logs: `Portable JNDI names for EJB TestMessageBean`
- MDB should consume messages from IBM MQ queue `DEV.QUEUE.1`

### Actual
- ❌ MDB is completely ignored (silent failure)
- ❌ No logs about MDB during deployment
- ❌ MDB does NOT appear in JNDI names
- ✅ WAR deploys successfully
- ✅ Resource Adapter deploys successfully
- ✅ JNDI resources created successfully

## Project Structure

```
payara6-ibm-mq-sscce/
├── README.md
├── build.gradle.kts
├── settings.gradle.kts
├── docker-compose.yml
├── docker/
│   └── payara/
│       ├── post-boot-commands.asadmin
│       └── download-mq-rar.sh
└── src/
    └── main/
        ├── java/
        │   └── test/
        │       └── TestMessageBean.java
        └── webapp/
            └── WEB-INF/
                ├── ejb-jar.xml
                └── glassfish-ejb-jar.xml
```

## Key Files

### TestMessageBean.java
Minimal MDB implementation with only required ActivationConfig properties.

### ejb-jar.xml
Standard Jakarta EE 10 descriptor (ejb-jar_4_0.xsd).

### glassfish-ejb-jar.xml
Payara-specific descriptor binding MDB to external RA (DTD format as per Payara docs).

### post-boot-commands.asadmin
Payara configuration deploying:
1. IBM MQ Resource Adapter (.rar)
2. Connector Connection Pool
3. Connector Resource (jms/MQConnectionFactory)
4. Admin Objects (Queues)
5. Backend WAR

## Verification Commands

```bash
# 1. Check if MDB appears in logs (EXPECTED TO FAIL)
docker logs payara 2>&1 | grep "TestMessageBean"

# 2. Check JNDI tree (MDB will be missing)
docker exec payara asadmin list-jndi-entries --context java:global

# 3. Verify MDB class is in WAR
docker exec payara unzip -l /opt/payara/deployments/test-mdb.war | grep TestMessageBean

# 4. Verify deployment descriptors are in WAR
docker exec payara unzip -p /opt/payara/deployments/test-mdb.war WEB-INF/glassfish-ejb-jar.xml

# 5. Send test message to queue
docker exec ibm-mq /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1
# Type: {"message": "test"}
# Press Ctrl+D

# 6. Check if message was consumed (EXPECTED TO FAIL - message remains in queue)
docker exec ibm-mq /opt/mqm/samp/bin/amqsbcg DEV.QUEUE.1 QM1
```

## IBM MQ Resource Adapter

- **Artifact:** `com.ibm.mq:wmq.jakarta.jmsra:9.4.3.1`
- **Source:** Maven Central
- **Jakarta Version:** Jakarta Messaging 3.1 (Jakarta EE 10)
- **Download:** Automated via `docker/payara/download-mq-rar.sh`

## Environment Details

- **Payara:** 6.2024.10 (Docker image: `payara/server-full:6.2024.10-jdk21`)
- **JDK:** OpenJDK 21.0.4 (Eclipse Temurin)
- **Jakarta EE:** 10
- **IBM MQ:** 9.4.0.0 (Docker image: `icr.io/ibm-messaging/mq:9.4.0.0-r1`)

## Related Issue

This SSCCE reproduces the bug reported at: [Payara GitHub Issue #XXXX]

## License

Public Domain - use freely for bug reproduction and testing.
