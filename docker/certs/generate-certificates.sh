#!/bin/bash
# Certificate Generation Script for IBM MQ SSL/TLS Authentication
# This script creates a Certificate Authority (CA) and generates
# server certificates for IBM MQ and client certificates for Payara

set -e

CERTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_DIR="${CERTS_DIR}/ca"
MQ_DIR="${CERTS_DIR}/mq"
PAYARA_DIR="${CERTS_DIR}/payara"

# Certificate validity (10 years)
VALIDITY_DAYS=3650

# Certificate details
CA_SUBJECT="/C=DE/ST=NSA/L=BADHARZBURG/O=SSCCE/OU=Development/CN=SSCCE-CA"
MQ_SUBJECT="/C=DE/ST=NSA/L=BADHARZBURG/O=SSCCE/OU=Development/CN=ibm-mq"
PAYARA_SUBJECT="/C=DE/ST=NSA/L=BADHARZBURG/O=SSCCE/OU=Development/CN=payara"

echo "========================================="
echo "Certificate Generation for IBM MQ + Payara"
echo "========================================="

# Clean up old certificates
echo "Cleaning up old certificates..."
rm -rf "${CA_DIR}" "${MQ_DIR}" "${PAYARA_DIR}"
mkdir -p "${CA_DIR}" "${MQ_DIR}" "${PAYARA_DIR}"

# ==========================================
# 1. Create Certificate Authority (CA)
# ==========================================
echo ""
echo "1. Creating Certificate Authority..."
cd "${CA_DIR}"

# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -new -x509 -days ${VALIDITY_DAYS} -key ca.key -out ca.crt \
  -subj "${CA_SUBJECT}"

echo "   ✓ CA Certificate created: ${CA_DIR}/ca.crt"

# ==========================================
# 2. Create IBM MQ Server Certificate
# ==========================================
echo ""
echo "2. Creating IBM MQ Server Certificate..."
cd "${MQ_DIR}"

# Generate MQ server private key
openssl genrsa -out mq-server.key 4096

# Generate MQ server certificate signing request (CSR)
openssl req -new -key mq-server.key -out mq-server.csr \
  -subj "${MQ_SUBJECT}"

# Create extension file for server certificate
cat > mq-server-ext.cnf << EOF
subjectAltName = DNS:ibm-mq,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

# Sign MQ server certificate with CA
openssl x509 -req -days ${VALIDITY_DAYS} \
  -in mq-server.csr \
  -CA "${CA_DIR}/ca.crt" \
  -CAkey "${CA_DIR}/ca.key" \
  -CAcreateserial \
  -out mq-server.crt \
  -extfile mq-server-ext.cnf

# Create PKCS12 keystore for MQ (IBM MQ prefers this format)
# Password: mqserver
openssl pkcs12 -export \
  -in mq-server.crt \
  -inkey mq-server.key \
  -certfile "${CA_DIR}/ca.crt" \
  -out mq-server.p12 \
  -name "ibmmq" \
  -password pass:mqserver

# Create JKS keystore for MQ (alternative format)
keytool -importkeystore \
  -srckeystore mq-server.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass mqserver \
  -destkeystore mq-server.jks \
  -deststoretype JKS \
  -deststorepass mqserver \
  -noprompt

# Import CA certificate into MQ truststore
keytool -import \
  -trustcacerts \
  -alias ca \
  -file "${CA_DIR}/ca.crt" \
  -keystore mq-truststore.jks \
  -storepass mqserver \
  -noprompt

echo "   ✓ MQ Server Certificate created: ${MQ_DIR}/mq-server.crt"
echo "   ✓ MQ Server Keystore: ${MQ_DIR}/mq-server.p12"

# ==========================================
# 3. Create Payara Client Certificate
# ==========================================
echo ""
echo "3. Creating Payara Client Certificate..."
cd "${PAYARA_DIR}"

# Generate Payara client private key
openssl genrsa -out payara-client.key 4096

# Generate Payara client certificate signing request (CSR)
openssl req -new -key payara-client.key -out payara-client.csr \
  -subj "${PAYARA_SUBJECT}"

# Create extension file for client certificate
cat > payara-client-ext.cnf << EOF
subjectAltName = DNS:payara,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = clientAuth
EOF

# Sign Payara client certificate with CA
openssl x509 -req -days ${VALIDITY_DAYS} \
  -in payara-client.csr \
  -CA "${CA_DIR}/ca.crt" \
  -CAkey "${CA_DIR}/ca.key" \
  -CAcreateserial \
  -out payara-client.crt \
  -extfile payara-client-ext.cnf

# Create PKCS12 keystore for Payara (contains client cert + key)
# Password: payara
openssl pkcs12 -export \
  -in payara-client.crt \
  -inkey payara-client.key \
  -certfile "${CA_DIR}/ca.crt" \
  -out payara-client.p12 \
  -name "payara-mq-client" \
  -password pass:payara

# Create JKS keystore for Payara
keytool -importkeystore \
  -srckeystore payara-client.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass payara \
  -destkeystore payara-client.jks \
  -deststoretype JKS \
  -deststorepass payara \
  -noprompt

# Import CA certificate into Payara truststore
keytool -import \
  -trustcacerts \
  -alias ca \
  -file "${CA_DIR}/ca.crt" \
  -keystore payara-truststore.jks \
  -storepass payara \
  -noprompt

# Import MQ server certificate into Payara truststore
keytool -import \
  -trustcacerts \
  -alias ibm-mq \
  -file "${MQ_DIR}/mq-server.crt" \
  -keystore payara-truststore.jks \
  -storepass payara \
  -noprompt

echo "   ✓ Payara Client Certificate created: ${PAYARA_DIR}/payara-client.crt"
echo "   ✓ Payara Client Keystore: ${PAYARA_DIR}/payara-client.p12"

# ==========================================
# 4. Generate Certificate Information
# ==========================================
echo ""
echo "========================================="
echo "Certificate Summary"
echo "========================================="
echo ""
echo "CA Certificate:"
openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject -issuer -dates

echo ""
echo "MQ Server Certificate:"
openssl x509 -in "${MQ_DIR}/mq-server.crt" -noout -subject -issuer -dates

echo ""
echo "Payara Client Certificate:"
openssl x509 -in "${PAYARA_DIR}/payara-client.crt" -noout -subject -issuer -dates

echo ""
echo "========================================="
echo "Keystores and Truststores"
echo "========================================="
echo "IBM MQ:"
echo "  - Keystore:   ${MQ_DIR}/mq-server.p12 (password: mqserver)"
echo "  - Truststore: ${MQ_DIR}/mq-truststore.jks (password: mqserver)"
echo ""
echo "Payara:"
echo "  - Keystore:   ${PAYARA_DIR}/payara-client.p12 (password: payara)"
echo "  - Truststore: ${PAYARA_DIR}/payara-truststore.jks (password: payara)"
echo ""
echo "✓ All certificates generated successfully!"
echo ""
