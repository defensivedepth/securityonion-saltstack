#!/bin/bash

MASTER={{ MASTER }}
VERSION="HH1.1.3"
TRUSTED_CONTAINERS=( \
"so-core:$VERSION" \
"so-cyberchef:$VERSION" \
"so-acng:$VERSION" \
"so-sensoroni:$VERSION" \
"so-fleet:$VERSION" \
"so-soctopus:$VERSION" \
"so-steno:$VERSION" \
"so-playbook:$VERSION" \
"so-thehive-cortex:$VERSION" \
"so-thehive:$VERSION" \
"so-thehive-es:$VERSION" \
"so-wazuh:$VERSION" \
"so-kibana:$VERSION" \
"so-auth-ui:$VERSION" \
"so-auth-api:$VERSION" \
"so-elastalert:$VERSION" \
"so-navigator:$VERSION" \
"so-filebeat:$VERSION" \
"so-suricata:$VERSION" \
"so-logstash:$VERSION" \
"so-bro:$VERSION" \
"so-idstools:$VERSION" \
"so-fleet-launcher:$VERSION" \
"so-freqserver:$VERSION" \
"so-influxdb:$VERSION" \
"so-grafana:$VERSION" \
"so-telegraf:$VERSION" \
"so-redis:$VERSION" \
"so-mysql:$VERSION" \
"so-curtor:$VERSION" \
"so-elasticsearch:$VERSION" \
"so-domainstats:$VERSION" \
"so-tcpreplay:$VERSION" \
)

for i in "${TRUSTED_CONTAINERS[@]}"
do
  # Pull down the trusted docker image
  docker pull --disable-content-trust=false docker.io/soshybridhunter/$i
  # Tag it with the new registry destination
  docker tag soshybridhunter/$i $MASTER:5000/soshybridhunter/$i
  docker push $MASTER:5000/soshybridhunter/$i
done
