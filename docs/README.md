# Set Up the QUEUE

docker run -d \
  --name ibm-mq \
  -p 1414:1414 \
  -p 9443:9443 \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=CLINICAL_QM \
  -e MQ_APP_USER=clinical_app \
  -e MQ_APP_PASSWORD=clinical123 \
  devcoderz2014/ibmmq_9_4_0_0-arm64:1.0
