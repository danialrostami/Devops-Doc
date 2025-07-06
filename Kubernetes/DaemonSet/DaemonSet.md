# Kubernetes DaemonSet Overview

## What is a DaemonSet?
A DaemonSet is a Kubernetes workload type that ensures a specific pod runs on all (or selected) nodes in a cluster. When you deploy a DaemonSet, Kubernetes automatically creates one instance of your pod on each specified node.

### Key Use Cases

#### 1. Log Collection
- Deploys log collectors (Fluentd, Logstash, Filebeat) on each node

#### 2. Monitoring
- Runs monitoring agents (Prometheus Node Exporter, Datadog) on every node

#### 3. Networking
- Manages service-to-service communication and traffic routing

#### 4. Node-Specific Services
- Runs security agents or custom processing services

#### 5. Hardware Support
- Installs special drivers/software for nodes with specific hardware

### Key Characteristics
- Automatic scaling - adds/removes pods when nodes join/leave
- Node targeting - runs on all nodes or selected via nodeSelectors
- Self-healing - replaces failed pods automatically
---
## Fluentd Log Collection DaemonSet on Kubernetes

Assume we have a cluster with 3 Worker Nodes and want to deploy Fluentd log collection on all nodes using a DaemonSet.

### 1. Creating the DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-log-collector
  labels:
    app: fluentd
  namespace: devops
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.16.1-debian-elasticsearch7-1.0
        env:
          - name: FLUENT_ELASTICSEARCH_HOST
            value: "elasticsearch.devops.svc.cluster.local" # Elasticsearch address
          - name: FLUENT_ELASTICSEARCH_PORT
            value: "9200"
        volumeMounts:
          - name: varlog
            mountPath: /var/log
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
            readOnly: true
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
```
### 2. Applying the Configuration
```
kubectl apply -f fluentd-daemonset.yaml -n devops
```
### 3. Checking DaemonSet Status
```
kubectl get daemonset -n devops
```
```
NAME                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
fluentd-log-collector   3         3         3       3            3           <none>          1m
```
### 4. Verifying Pods
```
kubectl get pods -o wide -n devops
```
```
NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
fluentd-log-collector-abc12   1/1     Running   0          1m    10.244.1.2    worker-node-1  <none>           <none>
fluentd-log-collector-def34   1/1     Running   0          1m    10.244.2.3    worker-node-2  <none>           <none>
fluentd-log-collector-ghi56   1/1     Running   0          1m    10.244.3.4    worker-node-3  <none>           <none>
```
### Key Points:

- The DaemonSet ensures one Fluentd pod runs on each worker node  
- Pods automatically get created when new nodes are added to the cluster  
- Fluentd collects logs from `/var/log` and `/var/lib/docker/containers`  
- Logs are forwarded to Elasticsearch at the specified address  
