#!/bin/bash
set -e

# Download IBM MQ Jakarta JMS Resource Adapter from Maven Central
# Version: 9.4.3.1 (Jakarta EE 10 compliant)

RAR_FILE="wmq.jakarta.jmsra.rar"
MAVEN_URL="https://repo1.maven.org/maven2/com/ibm/mq/wmq.jakarta.jmsra/9.4.3.1/wmq.jakarta.jmsra-9.4.3.1.rar"

if [ -f "$RAR_FILE" ]; then
    echo "✅ $RAR_FILE already exists (16.8 MB)"
    exit 0
fi

echo "📥 Downloading IBM MQ Jakarta JMS Resource Adapter 9.4.3.1..."
echo "Source: $MAVEN_URL"

curl -L -o "$RAR_FILE" "$MAVEN_URL"

if [ -f "$RAR_FILE" ]; then
    SIZE=$(du -h "$RAR_FILE" | cut -f1)
    echo "✅ Downloaded successfully: $RAR_FILE ($SIZE)"
else
    echo "❌ Download failed"
    exit 1
fi
