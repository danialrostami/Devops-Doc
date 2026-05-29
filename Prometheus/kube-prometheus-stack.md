# kube-prometheus-stack Installation Guide (Helm)

This document describes how to install a full Kubernetes monitoring stack using Helm. This guide is generic and applicable to any Kubernetes cluster.

- **Prometheus**: Metrics storage and querying engine.
- **Alertmanager**: Handles alerts sent by client applications such as Prometheus.
- **Grafana**: Feature-rich metrics dashboard and graph editor.
- **kube-state-metrics**: Listens to the Kubernetes API server and generates metrics about the state of objects.
- **node-exporter**: Prometheus exporter for hardware and OS metrics.
- **Pushgateway**: Optional component for short-lived service metrics.

## Table of Contents

1. [Step 0 — Preconditions](#step-0--preconditions)
2. [Step 1 — Create namespace](#step-1--create-namespace)
3. [Step 2 — Add Helm repo](#step-2--add-helm-repo)
4. [Step 3 — Create `values.yaml`](#step-3--create-reusable-valuesyaml)
   - [Persistence and StorageClass notes](#persistence-and-storageclass-notes)
   - [`values.yaml` example](#valuesyaml-example)
5. [Step 4 — Install `kube-prometheus-stack`](#step-4--install-kube-prometheus-stack)
6. [Step 5 — Install Pushgateway](#step-5--install-pushgateway)
7. [Step 6 — Verify installation](#step-6--verify-installation)
   - [Pods, Services, and controllers](#pods-services-and-controllers)
   - [PVCs / persistence](#pvcs--persistence)
8. [Step 7 — Access Grafana / Prometheus / Alertmanager](#step-7--access-grafana--prometheus--alertmanager)
9. [Step 8 — Prometheus validation (Targets & queries)](#step-8--prometheus-validation-targets--queries)
10. [Step 9 — Grafana: add/check Prometheus data source](#step-9--grafana-addcheck-prometheus-data-source)
11. [Step 10 — Create a simple dashboard (examples)](#step-10--create-a-simple-dashboard-examples)
12. [Step 11 — Import prepared Grafana dashboards](#step-11--import-prepared-grafana-dashboards)
13. [Notes: Node Exporter behavior](#notes-node-exporter-behavior)

---

## Step 0 — Preconditions

Make sure `kubectl` points to the correct cluster/context and Helm is installed.

```bash
kubectl config current-context
kubectl get nodes -o wide
helm version
```

### Install Helm (if needed)

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

## Step 1 — Create namespace

```bash
kubectl create namespace monitoring
```

---

## Step 2 — Add Helm repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm repo list
```

Expected example output:

```text
NAME                    URL
prometheus-community    https://prometheus-community.github.io/helm-charts
```

---

## Step 3 — Create `values.yaml`

This `values.yaml` enables:

- **Prometheus persistence** (PVC)
- **Alertmanager persistence** (PVC)
- **Grafana persistence** (PVC)
- **Grafana NodePort** service
- **kube-state-metrics** (explicit)
- **node-exporter** (explicit)
- **Pushgateway** is installed as a separate chart in Step 5

> You may need to adjust **`storageClassName`** (or remove it) depending on your cluster.

### Persistence and StorageClass notes

Persistence depends on having a working StorageClass and dynamic provisioning:

1. Install/configure a **StorageClass** first.
2. Install the Helm chart with **persistence enabled**.
3. The chart creates **PVCs**.
4. Kubernetes dynamically provisions **PVs** (if a provisioner exists).

Check StorageClasses:

```bash
kubectl get storageclass -o yaml
```

Your cluster might have `gp2`, `gp3`, `standard`, `longhorn`, `rook-ceph-block`, etc.

- Either set `storageClassName: <your-class>`
- Or remove `storageClassName` to use the **cluster default** StorageClass.

### `values.yaml` example

Create a file named `values.yaml`:

```yaml
# values.yaml

# --- Grafana ---
grafana:
  adminPassword: "CHANGE-ME"   # change this
  persistence:
    enabled: true
    type: pvc
    storageClassName: standard  # change/remove depending on your cluster
    accessModes: ["ReadWriteOnce"]
    size: 1Gi

  service:
    type: NodePort
    nodePort: 30001  # must be in 30000-32767

# --- Prometheus ---
prometheus:
  service:
    type: NodePort
    nodePort: 30002

  prometheusSpec:
    retention: 15d
    retentionSize: "1GB"   # optional safety cap; tune later

    # persistence via PVC
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard  # change/remove depending on your cluster
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi

# --- Alertmanager ---
alertmanager:
  service:
    type: NodePort
    nodePort: 30003

  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard  # change/remove depending on your cluster
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi

# --- Make sure these are enabled ---
kube-state-metrics:
  enabled: true

prometheus-node-exporter:
  enabled: true
```

> Security note: don’t hardcode real admin passwords in Git. Prefer a Kubernetes Secret or external secret manager.

---

## Step 4 — Install `kube-prometheus-stack`

```bash
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

Upgrade later (same values):

```bash
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## Step 5 — Install Pushgateway

```bash
helm install pushgateway prometheus-community/prometheus-pushgateway \
  -n monitoring
```

---

## Step 6 — Verify installation

### Pods, Services, and controllers

```bash
kubectl get all -n monitoring
```

You should see (names may vary slightly):

- Prometheus (StatefulSet) — ready
- Alertmanager (StatefulSet) — ready
- Grafana (Deployment) — running
- kube-state-metrics (Deployment) — running
- node-exporter (DaemonSet) — running
- Pushgateway (Deployment) — running

To inspect services specifically:

```bash
kubectl get svc -n monitoring
```

### PVCs / persistence

```bash
kubectl get pvc -n monitoring
```

Expected: PVCs for Prometheus, Alertmanager, and Grafana are `Bound`.

---

## Step 7 — Access Grafana / Prometheus / Alertmanager

If you used `NodePort` in `values.yaml`, access from outside the cluster (depending on your environment/networking) is typically:

- Grafana: `http://<NODE-IP>:30001`
- Prometheus: `http://<NODE-IP>:30002`
- Alertmanager: `http://<NODE-IP>:30003`

Find a node IP:

```bash
kubectl get nodes -o wide
```

> If your nodes do not have reachable external IPs, consider using an Ingress/LoadBalancer (cloud) or `kubectl port-forward` (quick access).

---

## Step 8 — Prometheus validation (Targets & queries)

Open Prometheus UI and verify scraping.

### Check Targets

Prometheus UI:

- **Status → Targets**

Each row is a **scrape endpoint** (`/metrics`) and shows whether it is being scraped successfully.

### Run basic queries

In Prometheus UI → **Graph** (or **Explore** in Grafana):

- Check general health:

```promql
up
```

Interpretation:

- `up == 1` → target is being scraped successfully
- `up == 0` → target is known but currently failing scrape

Some targets may be `DOWN` (control-plane components, secured endpoints, TLS/auth differences). This is common and not necessarily fatal if core metrics are available.

---

## Step 9 — Grafana: add/check Prometheus data source

1. Open Grafana UI
2. Go to: **Connections → Data sources**
3. Add (or verify) **Prometheus**

If Grafana is running inside the same cluster, use the internal service DNS name:

```text
http://prometheus-stack-kube-prom-prometheus.monitoring:9090
```

Save & test.

### Verify in Grafana

Grafana → **Explore** → select the Prometheus data source → run:

```promql
up
```

---

## Step 10 — Create a simple dashboard (examples)

Grafana:

**Dashboards → New → New dashboard → Add visualization**

Choose Prometheus data source.

### Panel 1: Node Memory Used (GiB)

- Panel title: `Node Memory Used (GiB)`
- Query (PromQL):

```promql
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024^3
```

Click **Apply** → **Save**.

### Panel 2: Count of pods by phase

- Panel title: `Pods by phase`
- Query:

```promql
sum by (phase) (kube_pod_status_phase{namespace=~".*"})
```

Suggested visualizations:

- Bar gauge
- Pie chart (if available)
- Time series

---

## Step 11 — Import prepared Grafana dashboards

### 1) Node Exporter Full (Dashboard ID: 1860)

URL:

- https://grafana.com/grafana/dashboards/1860-node-exporter-full/

Covers:

- node CPU/memory usage
- filesystem and network
- general node visibility

### 2) kube-state-metrics v2 (Dashboard ID: 13332)

URL:

- https://grafana.com/grafana/dashboards/13332-kube-state-metrics-v2/

Covers:

- pod phase/status
- node status
- deployments/replicas health
- namespaces/workload objects
- cluster object visibility

### Import steps

Grafana:

**Dashboards → New → Import** → upload JSON (or paste JSON) → choose the Prometheus data source → **Import**.

---

## Notes: Node Exporter behavior

`node-exporter` runs as a **DaemonSet**.

- On a single-node cluster, you get **1** `node-exporter` pod.
- On an N-node cluster, you typically get **one per eligible node**.

Some control-plane/master nodes are **tainted**, so scheduling may differ depending on:

- chart tolerations
- your cluster’s node taints/labels
- whether you allow monitoring on control-plane nodes
