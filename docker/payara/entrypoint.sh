#!/bin/bash
set -e

# Copy domain.xml from mounted template if it exists
if [ -f /tmp/domain-template.xml ]; then
    echo "Copying domain.xml template to configuration directory..."
    cp -f /tmp/domain-template.xml /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml
    chown payara:payara /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml
    chmod 644 /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml
fi

# Execute the original Payara entrypoint
exec /opt/payara/scripts/entrypoint.sh "$@"
