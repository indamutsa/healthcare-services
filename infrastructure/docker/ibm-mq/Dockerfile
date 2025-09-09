FROM --platform=linux/amd64 ibmcom/mq:latest

ENV LICENSE=accept
ENV MQ_QMGR_NAME=CLINICAL_QM
ENV MQ_APP_PASSWORD=clinical123
ENV MQ_ENABLE_EMBEDDED_WEB_SERVER=true

# No custom MQSC or qm.ini for now; run with image defaults

EXPOSE 1414 9443
