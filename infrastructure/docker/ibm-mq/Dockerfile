FROM --platform=linux/amd64 ibmcom/mq:latest

ENV LICENSE=accept
ENV MQ_QMGR_NAME=CLINICAL_QM
ENV MQ_APP_PASSWORD=clinical123
ENV MQ_ENABLE_EMBEDDED_WEB_SERVER=true

# Copy custom qm.ini to configure the queue manager
COPY config/qm.ini /etc/mqm/qm.ini

# Copy MQSC scripts; the image runs /etc/mqm/*.mqsc on first start
COPY config/*.mqsc /etc/mqm/

EXPOSE 1414 9443
