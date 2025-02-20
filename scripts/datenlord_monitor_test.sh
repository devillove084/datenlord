#! /bin/sh

set -o errexit
set -o nounset
set -o xtrace

KUBE_STATE_METRICS_VERSION=${KUBE_STATE_METRICS_VERSION:-"v1.8.0"}
ALERTMANAGER_VERSION=${ALERTMANAGER_VERSION:-"v0.19.0"}
PROMETHEUS_VERSION=${PROMETHEUS_VERSION:-"v2.30.3"}
GRAFANA_VERSION=${GRAFANA_VERSION:-"8.2.0"}

# Datenlord Monitoring test
sudo chmod +x scripts/datenlord-monitor-deploy.sh
cat scripts/alertmanager_test_alert.yaml >> scripts/alertmanager_alerts.yaml
docker pull quay.io/coreos/kube-state-metrics:$KUBE_STATE_METRICS_VERSION
docker pull prom/alertmanager:$ALERTMANAGER_VERSION
docker pull prom/prometheus:$PROMETHEUS_VERSION
docker pull grafana/grafana:$GRAFANA_VERSION
kind load docker-image prom/prometheus:$PROMETHEUS_VERSION
kind load docker-image grafana/grafana:$GRAFANA_VERSION
sh scripts/datenlord-monitor-deploy.sh deploy
NODE_IP=`kubectl get nodes -A -o wide | awk 'FNR == 2 {print $6}'`
FOUND_PATH=`curl --silent $NODE_IP:30000 | grep Found`
test -n "$FOUND_PATH" || (echo "FAILED TO FIND PROMETHEUS SERVICE" && /bin/false)

# Datenlord Alerting test
n=0
until [ "$n" -ge 5 ]
do
  echo "checking"
  if curl --silent $NODE_IP:31000/api/v2/alerts | grep 'High Memory Usage';
  then
    exit
  else
    echo "waiting 15s"
    n=$((n+1)) 
    sleep 15
  fi
done

echo "FAILED TO FIND PROMETHEUS SERVICE" && /bin/false