#!/bin/bash
# Custom IBM MQ entrypoint that sets up SSL/TLS before starting the queue manager
set -e

echo "========================================="
echo "IBM MQ Custom Entrypoint"
echo "========================================="

# Start the queue manager in the background to create the directory structure
echo "Starting queue manager initialization..."
/usr/local/bin/mq.sh &
MQ_PID=$!

# Wait for queue manager directory to be created
QMGR_NAME="${MQ_QMGR_NAME:-QM1}"
echo "Waiting for queue manager ${QMGR_NAME} to be created..."
while [ ! -d "/var/mqm/qmgrs/${QMGR_NAME}" ]; do
  sleep 2
done

# Wait a bit more for queue manager to fully initialize
echo "Queue manager directory created, waiting for initialization..."
sleep 10

# Run the SSL setup script
echo "Running SSL setup script..."
if [ -f /etc/mqm/setup-ssl.sh ]; then
  /etc/mqm/setup-ssl.sh
else
  echo "WARNING: SSL setup script not found!"
fi

# Wait for the MQ process to complete
echo "Waiting for queue manager to complete startup..."
wait $MQ_PID
