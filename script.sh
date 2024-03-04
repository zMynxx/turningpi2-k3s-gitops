helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 56.20.1 -n kube-prometheus-stack --create-namespace
helm install loki grafana/loki --version 5.43.3 -n loki --create-namespace
helm install promtail grafana/promtail --version 6.15.5 -n promtail --create-namespace


#################################
# https://docs.appsealing.com/guide/4.%20On-Premise/7.%20Logging_and_monitoring_with_Prometheus_Grafana_Loki.html#what-is-this-content-based-on
helm repo add prometheus-community  https://prometheus-community.github.io/helm-charts

cat <<EOF > values.yaml

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}

grafana:
  sidecar:
    datasources:
      defaultDatasourceEnabled: true
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki-loki-distributed-query-frontend.monitoring:3100
EOF

kubectl create namespace monitoring
helm install prom prometheus-community/kube-prometheus-stack -n monitoring --values values.yaml
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat <<EOF > promtail-values.yaml
config:
  clients:
    - url: "http://loki-loki-distributed-gateway/loki/api/v1/push"
EOF

helm upgrade --install loki grafana/loki-distributed -n monitoring --set service.type=LoadBalancer
helm upgrade --install promtail grafana/promtail -f promtail-values.yaml -n monitoring


