# k8s-monitoring-stack

A homelab monitoring stack running on Kubernetes. Collects metrics, logs, and pings your home network devices — all in one place with Grafana dashboards.

Just a solid foundation that works and is easy to build on.

---

## What's in here

| Tool | What it does |
|---|---|
| **Prometheus** | Scrapes and stores metrics |
| **Blackbox Exporter** | Pings your home devices and checks if they're alive |
| **Loki** | Stores logs from your cluster |
| **Promtail** | Ships logs from every node into Loki |
| **Grafana** | Dashboards for all of the above |

---

## Prerequisites

- Docker Desktop (running)
- `kind` — `brew install kind` or `winget install Kubernetes.kind`
- `kubectl` — `brew install kubectl` or `winget install Kubernetes.kubectl`

---

## Setup

### 1. Configure your devices

Copy the example devices file and fill in your real IPs:

```bash
cp monitoring/prometheus/devices.example.yaml monitoring/prometheus/devices.yaml
```

Open `devices.yaml` and replace the IPs with your actual devices. Run `arp -a` in your terminal to see everything currently on your network.

```yaml
devices:
  ping:
    - ip: x.x.x.x
      label: router
    - ip: x.x.x.x
      label: laptop
    - ip: x.x.x.x
      label: phone
    - ip: x.x.x.x
      label: smart-tv
  http:
    - url: http://10.0.0.1
      label: router-ui
```

> `devices.yaml` is gitignored — your real IPs will never be pushed to GitHub.

### 2. Generate the Prometheus config

```bash
chmod +x scripts/generate-config.sh
./scripts/generate-config.sh
```

This reads your `devices.yaml` and writes the Prometheus configmap with your IPs baked in.

### 3. Spin everything up

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Takes about 2-3 minutes. The setup script runs the config generator automatically if you forget.

---

## Accessing the stack

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |

---

## Adding or changing devices later

Edit `monitoring/prometheus/devices.yaml`, then:

```bash
./scripts/generate-config.sh
kubectl apply -f monitoring/prometheus/configmap.yaml
kubectl rollout restart deployment/prometheus -n monitoring
```

---

## Project structure

```
k8s-monitoring-stack/
├── cluster/
│   └── kind-config.yaml
├── namespaces/
│   └── monitoring.yaml
├── monitoring/
│   ├── prometheus/
│   │   ├── configmap.yaml              # Auto-generated. don't edit
│   │   ├── devices.example.yaml        # Template. safe to commit
│   │   ├── devices.yaml                # Real IPs. gitignored
│   │   ├── rbac.yaml
│   │   └── deployment.yaml
│   ├── blackbox/
│   │   └── deployment.yaml             # Pings home devices
│   ├── loki/
│   │   └── deployment.yaml
│   ├── promtail/
│   │   └── deployment.yaml
│   └── grafana/
│       ├── deployment.yaml
│       └── dashboard-configmap.yaml
└── scripts/
    ├── setup.sh                        # Stands everything up
    ├── generate-config.sh              # Builds configmap from devices.yaml
    └── teardown.sh                     # Tears it all down
```

---

## Useful commands

```bash
# Check pod status
kubectl get pods -n monitoring

# See logs from a specific component
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring deployment/prometheus

# Tear everything down
./scripts/teardown.sh
```

---

## What to add next

- **node-exporter** — deeper OS level metrics. Best for Linux machines running on network
- **Alertmanager** — get notified (email, Slack, etc.) when a device goes offline
- **kube-state-metrics** — richer Kubernetes object metrics
- **Persistent volumes** — so metrics survive pod restarts
- More Grafana dashboards — import community ones from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards)
