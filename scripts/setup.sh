#!/bin/bash
# spins up the full monitoring stack on a local Kind cluster
# Run in the root of the repo

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# check for devices.yaml before doing anything
if [ ! -f "monitoring/prometheus/devices.yaml" ]; then
  echo -e "${RED}ERROR: monitoring/prometheus/devices.yaml not found.${NC}"
  echo ""
  echo "  Set up your devices first:"
  echo "  cp monitoring/prometheus/devices.example.yaml monitoring/prometheus/devices.yaml"
  echo "  # Edit devices.yaml with your real IPs, then run:"
  echo "  ./scripts/generate-config.sh"
  echo ""
  exit 1
fi

echo -e "${GREEN}==> Generating Prometheus config from devices.yaml...${NC}"
./scripts/generate-config.sh

echo -e "${GREEN}==> Creating Kind cluster...${NC}"
kind create cluster --config cluster/kind-config.yaml

echo -e "${GREEN}==> Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready node --all --timeout=60s

echo -e "${GREEN}==> Creating monitoring namespace...${NC}"
kubectl apply -f namespaces/monitoring.yaml

echo -e "${GREEN}==> Deploying Prometheus...${NC}"
kubectl apply -f monitoring/prometheus/rbac.yaml
kubectl apply -f monitoring/prometheus/configmap.yaml
kubectl apply -f monitoring/prometheus/deployment.yaml

echo -e "${GREEN}==> Deploying Loki...${NC}"
kubectl apply -f monitoring/loki/deployment.yaml

echo -e "${GREEN}==> Deploying Promtail (log shipper)...${NC}"
kubectl apply -f monitoring/promtail/deployment.yaml

echo -e "${GREEN}==> Deploying Blackbox Exporter (home network probes)...${NC}"
kubectl apply -f monitoring/blackbox/deployment.yaml

echo -e "${GREEN}==> Deploying Grafana...${NC}"
kubectl apply -f monitoring/grafana/dashboard-configmap.yaml
kubectl apply -f monitoring/grafana/deployment.yaml

echo -e "${YELLOW}==> Waiting for pods to come up (this might take a minute)...${NC}"
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s
kubectl rollout status deployment/loki -n monitoring --timeout=120s
kubectl rollout status deployment/blackbox-exporter -n monitoring --timeout=120s
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

echo ""
echo -e "${GREEN}✓ Stack is up!${NC}"
echo ""
echo "  Grafana:    http://localhost:3000  (admin / admin)"
echo "  Prometheus: http://localhost:9090"
echo ""
echo "Tip: Run 'kubectl get pods -n monitoring' to check on everything."
