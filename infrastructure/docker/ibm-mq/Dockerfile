FROM devcoderz2014/ibmmq_9_4_0_0-arm64:1.0

ENV LICENSE=accept
ENV MQ_QMGR_NAME=CLINICAL_QM
ENV MQ_APP_PASSWORD=clinical123
ENV MQ_ENABLE_EMBEDDED_WEB_SERVER=true

COPY config/qm.ini /etc/mqm/qm.ini
COPY config/01-init.mqsc /etc/mqm/01-init.mqsc

EXPOSE 1414 9443
