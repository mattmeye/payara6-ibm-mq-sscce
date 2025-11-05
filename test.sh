#!/bin/bash
# Test script for Payara 6 MDB + IBM MQ SSCCE
# End-to-End automated test

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Payara 6 MDB + IBM MQ SSCCE - Test Script"
echo "================================================"
echo

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to wait for container to be healthy
wait_for_healthy() {
    local container=$1
    local max_wait=120
    local waited=0

    echo "Waiting for $container to be healthy..."
    while [ $waited -lt $max_wait ]; do
        local health_status=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        if [ "$health_status" = "healthy" ]; then
            print_status 0 "$container is healthy"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done

    print_status 1 "$container failed to become healthy within ${max_wait}s"
    return 1
}

echo "Step 1: Building the project"
echo "-----------------------------"
./gradlew clean build
print_status $? "WAR file built"
echo

echo "Step 2: Starting containers"
echo "----------------------------"
env DOCKER_BUILDKIT=0 docker-compose down -v 2>/dev/null || true
env DOCKER_BUILDKIT=0 docker-compose up -d

wait_for_healthy "ibm-mq"

# Wait for Payara - if healthcheck fails, check for deployment instead
if ! wait_for_healthy "payara"; then
    echo "Healthcheck failed, but checking if application is deployed..."
    sleep 30
    if docker logs payara 2>&1 | grep -q "test-mdb was successfully deployed"; then
        print_status 0 "Payara application deployed (healthcheck not available)"
    else
        print_status 1 "Payara deployment failed"
        exit 1
    fi
fi
echo

echo "Step 3: Waiting for full deployment"
echo "-------------------------------------"
echo "Waiting additional 30s for MDB activation..."
sleep 30
echo

echo "Step 4: Checking deployment status"
echo "-----------------------------------"

if docker logs payara 2>&1 | grep -q "test-mdb was successfully deployed"; then
    print_status 0 "test-mdb deployed successfully"
else
    print_status 1 "test-mdb deployment failed"
    echo
    docker logs payara 2>&1 | grep -i "exception\|error" | tail -10
    exit 1
fi

if docker logs payara 2>&1 | grep -q "Exception.*TestMessageBean"; then
    print_status 1 "MDB activation failed with exception"
    echo
    docker logs payara 2>&1 | grep -A 10 "TestMessageBean.*Exception" | head -20
    exit 1
else
    print_status 0 "No MDB activation exceptions"
fi

# Save logs for later inspection
docker logs payara 2>&1 > /tmp/payara.log
echo

echo "Step 5: Testing message delivery"
echo "---------------------------------"
echo "Sending test message 1..."
docker exec ibm-mq bash -c "echo 'Test message 1' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1" 2>&1 | grep -q "Sample AMQSPUT0 end"
print_status $? "Message 1 sent to queue"

sleep 3

echo "Checking if MDB received message 1..."
if docker logs payara 2>&1 | grep -q "MDB RECEIVED MESSAGE: Test message 1"; then
    print_status 0 "Message 1 received by MDB"
else
    print_status 1 "Message 1 NOT received by MDB"
    exit 1
fi

echo
echo "Sending test message 2..."
docker exec ibm-mq bash -c "echo 'Test message 2' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1" 2>&1 | grep -q "Sample AMQSPUT0 end"
print_status $? "Message 2 sent to queue"

sleep 3

echo "Checking if MDB received message 2..."
if docker logs payara 2>&1 | grep -q "MDB RECEIVED MESSAGE: Test message 2"; then
    print_status 0 "Message 2 received by MDB"
else
    print_status 1 "Message 2 NOT received by MDB"
    exit 1
fi

echo
echo "Sending JSON message..."
docker exec ibm-mq bash -c "cat > /tmp/test.json << 'EOF'
{\"test\": \"json message\", \"timestamp\": \"$(date -Iseconds)\"}
EOF
cat /tmp/test.json | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1" 2>&1 | grep -q "Sample AMQSPUT0 end"
print_status $? "JSON message sent to queue"

sleep 3

echo "Checking if MDB received JSON message..."
if docker logs payara 2>&1 | grep -q "MDB RECEIVED MESSAGE:.*json message"; then
    print_status 0 "JSON message received by MDB"
else
    print_status 1 "JSON message NOT received by MDB"
    exit 1
fi

echo

echo "Step 6: Verifying MQ configuration"
echo "-----------------------------------"
docker exec ibm-mq bash -c "echo 'DISPLAY QLOCAL(DEV.QUEUE.1)' | runmqsc QM1" > /tmp/mq-queue.log 2>&1
if grep -q "QUEUE(DEV.QUEUE.1)" /tmp/mq-queue.log; then
    print_status 0 "DEV.QUEUE.1 exists"
else
    print_status 1 "DEV.QUEUE.1 NOT found"
fi

docker exec ibm-mq bash -c "echo 'DISPLAY CHANNEL(DEV.APP.SVRCONN)' | runmqsc QM1" > /tmp/mq-channel.log 2>&1
if grep -q "CHANNEL(DEV.APP.SVRCONN)" /tmp/mq-channel.log; then
    print_status 0 "DEV.APP.SVRCONN channel exists"
else
    print_status 1 "DEV.APP.SVRCONN channel NOT found"
fi

echo

echo "Step 7: Summary"
echo "---------------"
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|ibm-mq|payara"
echo

echo "Messages received by MDB:"
docker logs payara 2>&1 | grep "MDB RECEIVED MESSAGE" | sed 's/^/  /'
echo

echo "MDB Configuration:"
echo "  - Package: test"
echo "  - Class: TestMessageBean"
echo "  - Destination: DEV.QUEUE.1"
echo "  - ConnectionFactory: jms/MQConnectionFactory"
echo "  - Resource Adapter: wmq.jakarta.jmsra"
echo "  - User: mqm"
echo

echo "Logs saved to:"
echo "  - /tmp/payara.log"
echo "  - /tmp/mq-queue.log"
echo "  - /tmp/mq-channel.log"
echo

echo "================================================"
echo -e "${GREEN}✓ All tests passed successfully!${NC}"
echo "================================================"
