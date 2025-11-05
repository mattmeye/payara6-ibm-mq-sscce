# IBM MQ 9.4.3.1 Developer Image for ARM64
# Built from https://github.com/ibm-messaging/mq-container

FROM localhost/ibm-mqadvanced-server-dev:9.4.3.1-arm64

# Accept IBM MQ License
ENV LICENSE=accept

# MQ Configuration
ENV MQ_QMGR_NAME=QM1
ENV MQ_APP_PASSWORD=passw0rd

# Copy MQSC configuration files
# These are executed automatically during queue manager creation
COPY 01-create-queues.mqsc /etc/mqm/
COPY 02-configure-security.mqsc /etc/mqm/

# Expose ports
# 1414: MQ Listener
# 9443: MQ Web Console
EXPOSE 1414 9443
