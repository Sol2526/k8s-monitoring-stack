#!/bin/bash
# this reads your devices.yaml and writes a prometheus configmap with your real IPs.
# Run this whenever you add or change devices.
# Usage: ./scripts/generate-config.sh

set -e

DEVICES_FILE="monitoring/prometheus/devices.yaml"
OUTPUT_FILE="monitoring/prometheus/configmap.yaml"

if [ ! -f "$DEVICES_FILE" ]; then
  echo ""
  echo "ERROR: $DEVICES_FILE not found."
  echo ""
  echo "  Copy the example file to get started:"
  echo "  cp monitoring/prometheus/devices.example.yaml monitoring/prometheus/devices.yaml"
  echo ""
  echo "  Then fill in your device IPs and run this script again."
  echo ""
  exit 1
fi

echo "Reading devices from $DEVICES_FILE..."

# parse ping targets from devices.yaml
PING_TARGETS=""
while IFS= read -r line; do
  ip=$(echo "$line" | grep -oP '(?<=ip: )[\d.]+' || true)
  if [ -n "$ip" ]; then
    PING_TARGETS="${PING_TARGETS}              - ${ip}\n"
  fi
done < "$DEVICES_FILE"

# parse ping labels for relabelingg
PING_LABELS=""
current_ip=""
while IFS= read -r line; do
  ip=$(echo "$line" | grep -oP '(?<=ip: )[\d.]+' || true)
  label=$(echo "$line" | grep -oP '(?<=label: )\S+' || true)
  if [ -n "$ip" ]; then current_ip="$ip"; fi
  if [ -n "$label" ] && [ -n "$current_ip" ]; then
    PING_LABELS="${PING_LABELS}          - targets: [\"${current_ip}\"]\n            labels:\n              device: \"${label}\"\n"
    current_ip=""
  fi
done < "$DEVICES_FILE"

# parse HTTP targets
HTTP_TARGETS=""
current_url=""
while IFS= read -r line; do
  url=$(echo "$line" | grep -oP '(?<=url: )\S+' || true)
  label=$(echo "$line" | grep -oP '(?<=label: )\S+' || true)
  if [ -n "$url" ]; then current_url="$url"; fi
  if [ -n "$label" ] && [ -n "$current_url" ]; then
    HTTP_TARGETS="${HTTP_TARGETS}          - targets: [\"${current_url}\"]\n            labels:\n              device: \"${label}\"\n"
    current_url=""
  fi
done < "$DEVICES_FILE"

# write the configmap
cat > "$OUTPUT_FILE" << YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:

      - job_name: "prometheus"
        static_configs:
          - targets: ["localhost:9090"]

      - job_name: "home-ping"
        metrics_path: /probe
        params:
          module: [icmp_ping]
        static_configs:
$(echo -e "$PING_LABELS")
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: blackbox-exporter:9115

      - job_name: "home-http"
        metrics_path: /probe
        params:
          module: [http_2xx]
        static_configs:
$(echo -e "$HTTP_TARGETS")
        relabel_configs:
          - source_labels: [__address__]
            target_label: __param_target
          - source_labels: [__param_target]
            target_label: instance
          - target_label: __address__
            replacement: blackbox-exporter:9115

      - job_name: "kubernetes-pods"
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: "true"
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: \$1:\$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod

      - job_name: "kubernetes-nodes"
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/\$1/proxy/metrics
YAML

echo "Config written to $OUTPUT_FILE"
echo ""
echo "Now apply it:"
echo "  kubectl apply -f $OUTPUT_FILE"
echo "  kubectl rollout restart deployment/prometheus -n monitoring"
