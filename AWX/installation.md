# AWX Installation on Minikube - Complete Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Install Minikube](#install-minikube)
3. [Install kubectl](#install-kubectl)
4. [Start Minikube Cluster](#start-minikube-cluster)
5. [Verify Minikube Installation](#verify-minikube-installation)
6. [Install Required Packages](#install-required-packages)
7. [Install Ansible](#install-ansible)
8. [AWX Operator Installation](#awx-operator-installation)
9. [Deploy AWX Instance](#deploy-awx-instance)
10. [Configure Persistent Storage](#configure-persistent-storage)
11. [Access AWX Web UI](#access-awx-web-ui)

---

## Prerequisites
1. Linux system (RHEL/Fedora/CentOS used in this guide)
2. Root or sudo privileges
3. Docker installed and running
4. Git installed

### Install Minikube

####  1. Download latest Minikube
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

#### 2. Install to /usr/local/bin
```
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

### 3.Verify installation
```
minikube version
```
---
### Install kubectl
```

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/

kubectl version --client
```
---
### Create AWX Projects Directory
```
sudo mkdir -p /opt/awx-projects
sudo chown $USER:$USER /opt/awx-projects
sudo chmod 755 /opt/awx-projects
```
---
### Start Minikube Cluster
- Start Minikube with Docker driver and volume mounting
```
minikube start   --driver=docker   --mount   --mount-string="/opt/awx-projects:/opt/awx-projects"   --force
```
#### Verify Minikube
```
minikube status

kubectl get nodes

kubectl get pods -A
```
----
### Install Required Packages
``` bash
sudo dnf install python3-pip epel-release python3-devel gcc openssl-devel -y
```
----
### Install Ansible
```
sudo dnf install -y ansible-core ansible

ansible --version

ansible localhost -m ping
```
----
### AWX Operator Installation
- Clone AWX Operator Repository
```
git clone https://github.com/ansible/awx-operator.git
cd awx-operator
```
- Checkout latest release tag
```
git checkout tags/$(git describe --tags --abbrev=0)
```
- Create Namespace for AWX Operator
```
kubectl create namespace awx
export NAMESPACE=awx
kubectl config set-context --current --namespace=$NAMESPACE
```
- Deploy AWX Operator
```
make deploy
```
- Verify operator deployment
```
kubectl get pods -n awx
```
- **Expected output:**
```
NAME                                               READY   STATUS    RESTARTS   AGE
awx-operator-controller-manager-58b7c97f4b-kf95s   2/2     Running   0          48s
```
---
### Deploy AWX Instance
```
cp awx-demo.yml ansible-awx.yml
```
vim ansible-awx.yml
```yaml
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
spec:
  service_type: nodeport
```
- Deploy AWX
```
kubectl apply -f ansible-awx.yml
```
- Check all resources in awx namespace
```
kubectl get all -n awx
```
- **Expected output**
```
NAME                                                   READY   STATUS      RESTARTS   AGE
pod/ansible-awx-migration-24.6.1-5sbq6                 0/1     Completed   0          23m
pod/ansible-awx-postgres-15-0                          1/1     Running     0          27m
pod/ansible-awx-task-5b8d47c9-9m6v9                    4/4     Running     0          26m
pod/ansible-awx-web-7b4c6655d6-9phn8                   3/3     Running     0          26m
pod/awx-operator-controller-manager-7946d576c9-wk4cq   2/2     Running     0          52m

NAME                                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/ansible-awx-postgres-15                           ClusterIP   None             <none>        5432/TCP       27m
service/ansible-awx-service                               NodePort    10.104.159.226   <none>        80:30902/TCP   26m
service/awx-operator-controller-manager-metrics-service   ClusterIP   10.97.62.248     <none>        8443/TCP       52m

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ansible-awx-task                  1/1     1            1           26m
deployment.apps/ansible-awx-web                   1/1     1            1           26m
deployment.apps/awx-operator-controller-manager   1/1     1            1           52m

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/ansible-awx-task-5b8d47c9                    1         1         1       26m
replicaset.apps/ansible-awx-web-7b4c6655d6                   1         1         1       26m
replicaset.apps/awx-operator-controller-manager-7946d576c9   1         1         1       52m

NAME                                       READY   AGE
statefulset.apps/ansible-awx-postgres-15   1/1     27m

NAME                                     STATUS     COMPLETIONS   DURATION   AGE
job.batch/ansible-awx-migration-24.6.1   Complete   1/1           2m25s      23m
```
---
## AWX Architecture - Complete Breakdown

### 📦 PODS (Running Containers)

#### 1. **ansible-awx-migration-24.6.1-5sbq6** ✅ *COMPLETED*

-   **Type:** One-time Job Pod
-   **Status:** Completed (ran successfully and finished)
-   **Purpose:** Database setup and schema migrations
-   **Analogy:** The construction crew that set up the database tables
-   **Why Completed:** It did its job (database setup) and exited

------------------------------------------------------------------------

#### 2. **ansible-awx-postgres-15-0** 🗄️ *RUNNING*

-   **Type:** Database Pod (StatefulSet)
-   **Status:** Running (1/1 ready)
-   **Purpose:** PostgreSQL database storing **ALL AWX data**
-   **Stores:** Users, inventories, job history, credentials, playbooks
-   **Why StatefulSet:** Data persists even if pod restarts

------------------------------------------------------------------------

#### 3. **ansible-awx-task-5b8d47c9-9m6v9** ⚡ *RUNNING*

-   **Type:** Task Execution Pod (4 containers)
-   **Status:** Running (4/4 ready)
-   **Purpose:** Runs Ansible playbooks and jobs
-   **Containers:**
    -   Main task runner
    -   Redis (cache + message broker)
    -   Support containers
-   **Analogy:** The "kitchen staff" that cooks (executes playbooks)

------------------------------------------------------------------------

#### 4. **ansible-awx-web-7b4c6655d6-9phn8** 🌐 *RUNNING*

-   **Type:** Web Interface Pod (3 containers)
-   **Status:** Running (3/3 ready)
-   **Purpose:** Web UI and REST API
-   **Containers:**
    -   nginx (web server)
    -   awx-web (Django application)
    -   redis (caching)
-   **Analogy:** The "restaurant front" where customers interact

------------------------------------------------------------------------

#### 5. **awx-operator-controller-manager-7946d576c9-wk4cq** 🎮 *RUNNING*

-   **Type:** Operator Pod (2 containers)
-   **Status:** Running (2/2 ready)
-   **Purpose:** Manages and watches AWX instances
-   **Containers:**
    -   kube-rbac-proxy (authentication)
    -   awx-manager (operator logic)
-   **Analogy:** The "building manager" that maintains everything

------------------------------------------------------------------------

### 🌐 SERVICES (Network Access)

#### 1. **ansible-awx-postgres-15**

-   **Type:** ClusterIP
-   **Port:** 5432
-   **Purpose:** Internal service for database access
-   **Access:** Only within Kubernetes cluster

------------------------------------------------------------------------

#### 2. **ansible-awx-service** 🚪 *YOUR ENTRY POINT*

-   **Type:** NodePort
-   **Port:** 80:30902
-   **Purpose:** Web UI access
-   **Access:** `http://192.168.49.2:30902`
-   **Why NodePort:** Makes AWX accessible from outside Kubernetes

------------------------------------------------------------------------

#### 3. **awx-operator-controller-manager-metrics-service**

-   **Type:** ClusterIP
-   **Port:** 8443
-   **Purpose:** Metrics and monitoring for operator

------------------------------------------------------------------------

### ⚙️ DEPLOYMENTS (Pod Managers)

#### 1. **deployment.apps/ansible-awx-task**

-   **Manages:** Task pods
-   **Replicas:** 1
-   **Purpose:** Ensures task runner is always available

#### 2. **deployment.apps/ansible-awx-web**

-   **Manages:** Web pods
-   **Replicas:** 1
-   **Purpose:** Ensures web interface is always available

#### 3. **deployment.apps/awx-operator-controller-manager**

-   **Manages:** Operator pods
-   **Replicas:** 1
-   **Purpose:** Ensures operator is always running

------------------------------------------------------------------------

### 🔄 REPLICASETS (Version Control for Pods)

Each Deployment uses a ReplicaSet to manage pod versions:

-   **ansible-awx-task-5b8d47c9** -- Manages task pod version
-   **ansible-awx-web-7b4c6655d6** -- Manages web pod version
-   **awx-operator-controller-manager-7946d576c9** -- Manages operator
    pod version

**Purpose:** Handle rolling updates and version tracking

------------------------------------------------------------------------

### 💾 STATEFULSET (Stateful Applications)

#### **statefulset.apps/ansible-awx-postgres-15**

-   **Manages:** Database pod
-   **Why StatefulSet:**
    -   Stable network identity
    -   Persistent storage
    -   Ordered deployment
-   **Pod Naming:** `ansible-awx-postgres-15-0` (predictable)

------------------------------------------------------------------------

### 🎯 JOB (One-time Tasks)

#### **job.batch/ansible-awx-migration-24.6.1**

-   **Status:** Complete ✅
-   **Completions:** 1/1
-   **Duration:** 2m25s
-   **Purpose:** Ran database migrations during setup

------------------------------------------------------------------------

### 🔄 How Data Flows Through AWX

    User Request → ansible-awx-service (NodePort 30902)
                        ↓
               ansible-awx-web (Web UI/API)
                        ↓
               ansible-awx-task (Playbook Execution)
                        ↓
               Target Servers (via SSH/Ansible)
                        ↑
              ansible-awx-postgres-15 (Data Storage)

---
### Configure Persistent Storage
1. /opt/manifests/pv-awx-projects.yaml
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: awx-projects-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /opt/awx-projects
    type: DirectoryOrCreate
```
2. /opt/manifests/pvc-awx-projects.yaml
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: awx-projects-pvc
  namespace: awx
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: ""
  volumeName: awx-projects-pv
```
3. Apply storage configurations
```
kubectl apply -f /opt/manifests/pv-awx-projects.yaml
kubectl apply -f /opt/manifests/pvc-awx-projects.yaml
```
4. Patch AWX instance
```
kubectl patch awx ansible-awx -n awx --type merge -p '{
  "spec": {
    "projects_persistence": true,
    "projects_existing_claim": "awx-projects-pvc",
    "projects_storage_access_mode": "ReadWriteMany"
  }
}'
```
5. Verify persistent volume
```
kubectl exec -n awx deployment/ansible-awx-web -c awx-web -- ls -la /var/lib/projects
```
---
### Access AWX Web UI
1. Port forward to access
```
kubectl port-forward -n awx svc/ansible-awx-service 8080:80 --address 0.0.0.0
```
2. Get admin password
```
kubectl get secret -n awx ansible-awx-admin-password -o jsonpath='{.data.password}' | base64 --decode
```
- `http://<YOUR-SERVER-IP>:8080`
