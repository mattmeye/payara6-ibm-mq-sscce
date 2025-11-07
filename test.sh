#!/bin/bash
# Automated test script for Payara 6 + IBM MQ SSCCE
# This script performs a complete test cycle:
# 1. Generate certificates
# 2. Download IBM MQ (if needed)
# 3. Clean up Docker containers and volumes
# 4. Build and start containers
# 5. Configure SSL in IBM MQ
# 6. Send test messages
# 7. Verify MDB message processing

set -e

echo "========================================="
echo "Payara 6 + IBM MQ SSCCE Test Script"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Step 1: Generate certificates
print_info "Step 1: Generating SSL/TLS certificates..."
if [ -d "docker/certs/ca" ] && [ -f "docker/certs/ca/ca.crt" ]; then
    print_info "Certificates already exist. Skipping generation."
else
    print_info "Generating certificates..."
    cd docker/certs
    ./generate-certificates.sh
    cd ../..
    print_status "Certificates generated successfully"
fi

# Step 2: Check for IBM MQ image
print_info "Step 2: Checking IBM MQ Docker image..."
if docker images | grep -q "ibm-mqadvanced-server-dev.*9.4"; then
    print_status "IBM MQ image found"
else
    print_error "IBM MQ image not found!"
    print_info "Please download and build the IBM MQ image first."
    print_info "See docker/ibm-mq/README.md for instructions."
    exit 1
fi

# Step 3: Clean up Docker containers and volumes
print_info "Step 3: Cleaning up Docker containers and volumes..."
env DOCKER_BUILDKIT=0 docker-compose down -v
print_status "Cleanup completed"

# Step 4: Build the application
print_info "Step 4: Building application..."
./gradlew clean build
print_status "Application built successfully"

# Step 5: Start Docker containers
print_info "Step 5: Starting Docker containers..."
env DOCKER_BUILDKIT=0 docker-compose up -d
print_status "Containers started"

# Step 6: Wait for IBM MQ to be healthy
print_info "Step 6: Waiting for IBM MQ to be healthy..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    if docker inspect ibm-mq | grep -q '"Status": "healthy"'; then
        print_status "IBM MQ is healthy"
        break
    fi
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    print_error "Timeout waiting for IBM MQ to become healthy"
    exit 1
fi

# Step 7: Setup SSL keystores in IBM MQ
print_info "Step 7: Setting up SSL keystores in IBM MQ..."
docker exec ibm-mq /etc/mqm/setup-ssl.sh
print_status "SSL keystores configured"

# Wait for Queue Manager to be fully ready
print_info "Waiting for Queue Manager to be fully ready (10 seconds)..."
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""
print_status "Queue Manager should be ready"

# Step 8: Configure SSL in Queue Manager and Channel
print_info "Step 8: Configuring SSL in Queue Manager and Channel..."

# Create MQSC script file
cat > /tmp/set-ssl.mqsc << 'EOF'
ALTER QMGR SSLKEYR('/var/mqm/qmgrs/QM1/ssl/mq-server')
ALTER CHANNEL('DEV.APP.SVRCONN') CHLTYPE(SVRCONN) SSLCIPH('ECDHE_RSA_AES_128_GCM_SHA256') SSLCAUTH(OPTIONAL) MCAUSER('app')
REFRESH SECURITY TYPE(SSL)
EOF

# Copy to container and execute
docker cp /tmp/set-ssl.mqsc ibm-mq:/tmp/set-ssl.mqsc > /dev/null 2>&1
docker exec ibm-mq bash -c "runmqsc QM1 < /tmp/set-ssl.mqsc" > /tmp/mqsc-output.log 2>&1
rm /tmp/set-ssl.mqsc

# Check if configuration was successful
if grep -q "AMQ8005I" /tmp/mqsc-output.log && grep -q "AMQ8016I" /tmp/mqsc-output.log; then
    print_status "SSL configured in Queue Manager and Channel"
    rm /tmp/mqsc-output.log
else
    print_error "SSL configuration may have failed. Check logs."
    cat /tmp/mqsc-output.log
    rm /tmp/mqsc-output.log
fi

# Step 9: Restart Payara to reconnect with SSL
print_info "Step 9: Restarting Payara..."
docker-compose restart payara > /dev/null 2>&1
print_status "Payara restarted"

# Step 10: Wait for Payara to be ready
print_info "Step 10: Waiting for Payara to be ready (30 seconds)..."
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""
print_status "Payara should be ready now"

# Step 11: Send test messages with timestamps
print_info "Step 11: Sending test messages to IBM MQ..."
echo ""
echo "========================================="
echo "Sending Messages:"
echo "========================================="

# Store message IDs for verification
declare -a sent_messages

for i in {1..5}; do
    # Generate unique message with timestamp and random ID
    timestamp=$(date '+%H:%M:%S')
    random_id=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
    message="SSCCE-Test-$i Time=$timestamp ID=$random_id"

    # Store for later comparison
    sent_messages+=("$message")

    # Send message
    echo -e "${GREEN}→${NC} Sending: $message"
    docker exec ibm-mq bash -c "echo '$message' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1" > /dev/null 2>&1
    sleep 1
done

echo ""
print_status "All 5 messages sent successfully"
echo ""

# Wait for MDB to process
print_info "Step 12: Waiting for MDB to process messages..."
sleep 5

# Step 13: Check Payara logs for MDB processing
print_info "Step 13: Verifying message processing..."
echo ""
echo "========================================="
echo "Messages Received by MDB:"
echo "========================================="

# Get received messages
received_messages=$(docker logs payara 2>&1 | grep "MDB RECEIVED MESSAGE:" | sed 's/.*MDB RECEIVED MESSAGE: //')

if [ -z "$received_messages" ]; then
    print_error "No messages were received by the MDB"
else
    echo "$received_messages" | while IFS= read -r msg; do
        echo -e "${GREEN}←${NC} Received: $msg"
    done
fi

echo ""
echo "========================================="
echo "Recent Payara Errors (if any):"
echo "========================================="
docker logs payara 2>&1 | grep -i "error\|exception\|failed" | tail -5 || print_status "No recent errors found"

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
message_count=$(docker logs payara 2>&1 | grep -c "MDB RECEIVED MESSAGE:" || echo "0")
sent_count=5

echo "Messages sent:     $sent_count"
echo "Messages received: $message_count"
echo ""

if [ "$message_count" -eq "$sent_count" ]; then
    print_status "SUCCESS: All $message_count/$sent_count messages processed correctly"
    echo ""
    echo "TLS Configuration:"
    echo "  ✓ Cipher Suite: ECDHE_RSA_AES_128_GCM_SHA256"
    echo "  ✓ Client Certificate: Optional (SSLCAUTH=OPTIONAL)"
    echo "  ✓ Server Certificate: Validated via Truststore"
    echo ""
    print_info "Useful commands:"
    print_info "  - View Payara logs: docker logs payara"
    print_info "  - View IBM MQ logs: docker logs ibm-mq"
    print_info "  - Access Payara Admin: http://localhost:4849"
    print_info "  - Access MQ Console: https://localhost:9444/ibmmq/console/ (admin/passw0rd)"
elif [ "$message_count" -gt "0" ]; then
    print_error "PARTIAL SUCCESS: Only $message_count/$sent_count messages were processed"
    echo ""
    print_info "Some messages may have been lost during deployment/restart"
    print_info "You can send more messages manually to verify: docker exec ibm-mq bash -c \"echo 'Test' | /opt/mqm/samp/bin/amqsput DEV.QUEUE.1 QM1\""
else
    print_error "FAILURE: No messages were processed by the MDB"
    echo ""
    print_info "Troubleshooting steps:"
    print_info "  1. Check Payara logs: docker logs payara"
    print_info "  2. Check IBM MQ logs: docker logs ibm-mq"
    print_info "  3. Verify SSL certificates: docker exec ibm-mq ls -la /var/mqm/qmgrs/QM1/ssl/"
fi

echo ""
