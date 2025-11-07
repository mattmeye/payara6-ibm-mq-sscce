#!/bin/bash
# IBM MQ SSL/TLS Keystore Setup Script
# This script is executed after the queue manager starts
# It converts and imports certificates into MQ's CMS keystore format

set -e

QMGR_NAME="${MQ_QMGR_NAME:-QM1}"
SSL_DIR="/var/mqm/qmgrs/${QMGR_NAME}/ssl"
CERTS_DIR="/mnt/certs"

echo "========================================="
echo "IBM MQ SSL/TLS Keystore Setup"
echo "========================================="

# Wait for queue manager to be created
echo "Waiting for queue manager ${QMGR_NAME} to be created..."
while [ ! -d "/var/mqm/qmgrs/${QMGR_NAME}" ]; do
  sleep 2
done

# Create SSL directory
echo "Creating SSL directory: ${SSL_DIR}"
mkdir -p "${SSL_DIR}"
cd "${SSL_DIR}"

# Check if certificates exist
if [ ! -f "${CERTS_DIR}/mq/mq-server.p12" ]; then
  echo "ERROR: MQ server certificates not found at ${CERTS_DIR}/mq/"
  exit 1
fi

# IBM MQ uses CMS (Cryptographic Message Syntax) keystore format
# We need to use the runmqakm (or runmqckm) utility to create it

echo "Creating CMS keystore for IBM MQ..."

# Create CMS keystore database
runmqakm -keydb -create -db mq-server.kdb -pw mqserver -type cms -stash

# Import CA certificate into keystore
echo "Importing CA certificate..."
runmqakm -cert -add -db mq-server.kdb -stashed \
  -label "CA_CERT" \
  -file "${CERTS_DIR}/ca/ca.crt" \
  -format ascii

# Import PKCS12 keystore (contains server cert + private key)
echo "Importing MQ server certificate and private key..."
runmqakm -cert -import -target mq-server.kdb -target_stashed \
  -file "${CERTS_DIR}/mq/mq-server.p12" -pw mqserver \
  -target_type cms -type pkcs12

# Rename the certificate label to IBM MQ's expected format
# IBM MQ expects: ibmwebspheremq<qmgr_name_lowercase>
# For QM1, this is 'ibmwebspheremqqm1'
EXPECTED_LABEL="ibmwebspheremq$(echo ${QMGR_NAME} | tr '[:upper:]' '[:lower:]')"
echo "Renaming certificate to '${EXPECTED_LABEL}'..."
runmqakm -cert -rename -db mq-server.kdb -stashed \
  -label "ibmmq" \
  -new_label "${EXPECTED_LABEL}"

# List certificates in keystore
echo ""
echo "Certificates in keystore:"
runmqakm -cert -list -db mq-server.kdb -stashed

# Set correct permissions
echo "Setting permissions..."
chmod 640 mq-server.kdb mq-server.sth
chown mqm:mqm mq-server.kdb mq-server.sth mq-server.crl mq-server.rdb 2>/dev/null || true

echo ""
echo "✓ SSL/TLS keystore setup completed successfully!"
echo "  Keystore: ${SSL_DIR}/mq-server.kdb"
echo ""
