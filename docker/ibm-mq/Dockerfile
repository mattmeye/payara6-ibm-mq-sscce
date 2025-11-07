# IBM MQ 9.4.2.0 Developer Image for ARM64 with SSL/TLS Support
# Built from https://github.com/ibm-messaging/mq-container

FROM localhost/ibm-mqadvanced-server-dev:9.4.2.0-arm64

# Accept IBM MQ License
ENV LICENSE=accept

# MQ Configuration
ENV MQ_QMGR_NAME=QM1

# Copy MQSC configuration files
# These are executed automatically during queue manager creation
COPY 01-create-queues.mqsc /etc/mqm/
COPY 02-setup-ssl-inline.mqsc /etc/mqm/
COPY 03-configure-ssl.mqsc /etc/mqm/

# SSL setup script - will be executed post-start
COPY setup-ssl.sh /etc/mqm/setup-ssl.sh

# Expose ports
# 1414: MQ Listener (now SSL/TLS only)
# 9443: MQ Web Console (HTTPS)
EXPOSE 1414 9443
