# Argo CD

## Definition
GitOps continuous delivery tool for Kubernetes. It automates application deployment and lifecycle management by syncing the live state of your applications with their desired state defined in a Git repository.


## GitOps vs. Classic CI/CD

| Aspect | Classic CI/CD | GitOps |
| :--- | :--- | :--- |
| **Paradigm** | Push-based (e.g., Jenkins, GitLab CI) | Pull-based (e.g., ArgoCD, Flux) |
| **Source of Truth** | CI/CD Pipeline Configuration | Git Repository |
| **Operation** | Tools push changes to servers | System continuously polls Git and applies changes |
| **Key Advantage** | Mature, widely adopted | Better control, security, and auditability |

## ArgoCD Architecture & Components
```mermaid
flowchart TD
    A[User]
    
    subgraph ArgoCDNamespace [ArgoCD Namespace]
        B[ArgoCD UI]
        E[API Server<br>/REST API/]
        F[Repo Server]
        G[Application Controller]
    end

    subgraph ExternalSystems [External Systems]
        H[Git Repository]
        I[Kubernetes Cluster]
    end

    A -- "Uses Web Browser" --> B
    A -- "Uses Terminal" --> C[argocd CLI]
    
    B -- "Makes API Calls" --> E
    C -- "Makes API Calls" --> E
    
    A -- "Direct API Access" --> E

    E -- "Forwards Requests" --> F
    E -- "Manages & Commands" --> G
    
    F -- "Pulls Manifests" --> H
    G -- "Monitors & Reconcilies" --> I
```


- **User Interfaces** : These are the entry points for humans and other systems (UI, CLI, REST API).

- **API Server** : The central hub and gateway for all communication. It receives commands from the UIs and orchestrates the other components.

- **Repo Server** : The "fetcher." Its only job is to connect to the Git repository, pull the latest manifests (YAML, Helm charts, customize files), and process them into raw Kubernetes resources.

- **Application Controller** : The "brain" or "reconciler." It continuously compares the desired state from the Repo Server with the actual, live state in the Kubernetes cluster and makes changes to align them.

  ---

### Quick Installation
```yaml
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access via port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Access UI at**: https://localhost:8080`

### Accessing ArgoCD UI & CLI

#### 1. Get Initial Admin Password
The default admin password is stored in a Kubernetes secret:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

#### 2. Install ArgoCD CLI
```
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```
#### 3. Login via CLI
```yaml
argocd login <ARGOCD_SERVER_ADDRESS> --username admin --password <PASSWORD>
```
---

### Production Installation with Ingress & TLS
#### 1. Basic Installation
```yaml
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
#### 2. Configure Service Type
**Default**: ArgoCD uses ClusterIP (internal cluster access only)  
**Goal**: Enable external access  
**Action**: Modify the `argocd-server` service configuration
```yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
```
#### 3. Create Ingress Resource
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - argocd.your-domain.com
      secretName: argocd-tls-secret
  rules:
    - host: argocd.your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```
#### 4. Create TLS Secret (if using manual certificates)
```yaml
kubectl create secret tls argocd-tls-secret \
  --cert=cert.crt \
  --key=cert.key \
  -n argocd
```
---
## Applications and Sync

### Application Definition
In ArgoCD, an **Application** defines what to deploy, from where, and how:
- **Source**: Git repository URL, path, and revision (branch/tag)
- **Destination**: Target cluster and namespace
- **Tooling**: Deployment method (plain YAML, Helm, Kustomize, etc.)

### Sync Operation
**Sync** means reconciling the desired state (in Git) with the live state (in cluster):
- **Manual Sync**: User-triggered deployment
- **Auto Sync**: Automatic deployment when Git changes
- **OutOfSync**: Status when live state differs from Git

### Sample Application YAML
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/nginx-deploy
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true          
      selfHeal: true       
```
This application will:
- **Source**: Deploy contents from the `manifests` folder in the GitHub repository
- **Target**: Deploy to the `default` namespace in the Kubernetes cluster
- **Revision**: Use the latest commit (`HEAD`) from the repository
- **`prune: true`**: Automatically removes resources from the cluster if they are deleted from Git
- **`selfHeal: true`**: Automatically reverts any manual changes made directly in the cluster back to the state defined in Git
---
## Git Repository Configuration

- **Public Repos**: No credentials needed

- **Private Repos**: Require SSH keys or HTTPS credentials

### 1.SSH Connection (Recommended)
```bash
argocd repo add git@github.com:my-org/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```
### 2.HTTPS Connection
```bash
argocd repo add https://github.com/my-org/myrepo.git \
--username myuser \
--password mytoken
```
---
##  AppProject: Access Control in ArgoCD
AppProject is a resource in kubernetes that restricts what applications can do:

- **Namespace Restrictions**: Control which namespaces applications can deploy to
- **Git Repository Whitelisting**: Specify allowed source Git repositories
- **Cluster Access Management**: Define permitted target clusters
- **RBAC Configuration**: Set team-specific role-based access control rules

### Sample AppProject
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: dev-team
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/my-org/dev-repos/*   # Only repo located under the `dev-repos/` are permitted.
  destinations:
    - namespace: dev
      server: https://kubernetes.default.svc
  namespaceResourceBlacklist:
    - group: ""
      kind: Secret                                 # Prevent Secret creation
```
---
## ArgoCD Deployment Management

### Overview
ArgoCD automates Kubernetes deployments, providing control, visibility, and rollback capabilities.

### Sync Modes
### 🔧 Manual Sync
- Changes in Git trigger **OutOfSync** status but require manual deployment
- Trigger via CLI: `argocd app sync my-app`
- Or use the Sync button in UI
### 🤖 Auto Sync
- Automatically deploys Git changes immediately
- Enable in YAML:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```
### Sync Policy Features

#### ✅ Automated
Enables automatic deployment without manual intervention

#### 🧹 Prune
Removes cluster resources that were deleted from Git

#### ♻️ Self-Heal
Automatically reverts manual cluster changes to match Git state
#
### ArgoCD Status Monitoring

| Status Type   | Status      | Description |
|---------------|-------------|-------------|
| Sync Status   | Synced      | Git state matches cluster state |
|               | OutOfSync   | Differences exist between Git and cluster |
| Health Status | Healthy     | All resources functioning properly |
|               | Progressing | Resources being created or updated |
|               | Degraded    | Problems exist in resources (e.g., CrashLoopBackOff) |
|               | Missing     | Required resources not found in the cluster |

- **Check Status**
```bash
argocd app get my-app
```
### 🔍 Comparison Tools
View differences between Git and cluster states

- UI: Use "Diff" button

- CLI: `argocd app diff my-app`
```
- replicas: 2
+ replicas: 3
```
### ⏪ Rollback Capabilities
**Revision History**

  - ArgoCD maintains complete deployment history

  - Each sync creates a new revision (using Git commit hash)

**Rollback Methods**
- **UI**: Application → History → Select previous version → Rollback
- **CLI**
```yaml
argocd app history my-app
argocd app rollback my-app <revision-id>
```
---

# Git Repository Structure for GitOps with ArgoCD
A well-organized Git repository structure is crucial for effective GitOps implementation with ArgoCD, especially for multi-environment projects using different deployment tools.

## Repository Structures by Tool
### 1. Plain YAML Structure
```
k8s/
├── deployment.yaml
├── service.yaml
└── ingress.yaml
```
- Simplest approach - direct Kubernetes manifest files
- ArgoCD only needs the path to the YAML files
---
### 2. Kustomize Structure (Recommended for multi-environment)
```
k8s/
├── base/
│   ├── kustomization.yaml  # ← Lists base resources + common config
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml  # ← Points to base + dev patches
    │   └── patch.yaml
    └── prod/
        ├── kustomization.yaml  # ← Points to base + prod patches
        └── patch.yaml
```
- Layered approach with base configuration and environment-specific patches
- Each overlay's `kustomization.yaml` specifies base references and patches

#### Sample Kustomize Structure:
- **In the base/ Directory**

The base/kustomization.yaml file defines the common, reusable set of resources for your application.
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 1. List of all resource files in the base directory
resources:
  - deployment.yaml
  - service.yaml

# 2. Common labels or annotations applied to ALL resources
commonLabels:
  app: my-app
  environment: base


# 3. (Optional) Image overrides - if you want to set a default image
images:
  - name: nginx
    newTag: v1.0.0
```
-  **In the overlays/ Directory**

An overlay's kustomization.yaml customizes the base for a specific environment (dev, staging, prod, etc.).
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 1. Point back to the base directory
bases:
  - ../../base

# 2. (Optional) Patches to modify the base resources
patchesStrategicMerge:
  - patch.yaml
# or
patches:
  - path: patch.yaml
    target:
      kind: Deployment

# 3. Environment-specific configurations
namespace: dev-namespace

# 4. Override images for this environment
images:
  - name: nginx
    newTag: latest-dev

# 5. Environment-specific labels/annotations
commonLabels:
  environment: dev

commonAnnotations:
  deployed-at: "2023-10-01"
```
---
### 3. Helm Structure
```
charts/
└── my-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```
- **Chart-based approach** for complex applications
- Can use custom charts or public charts from repositories
---
## ArgoCD Integration Examples
### Kustomize Configuration:

- ArgoCD automatically detects kustomization.yaml
- Can customize with name prefixes and image overrides
```yaml
spec:
  source:
    repoURL: https://github.com/my-org/my-app
    path: overlays/dev
    targetRevision: main
    kustomize:
      namePrefix: dev-
      images:
        - my-app:1.2.3
```
### Helm Configuration (External Repository)

```yaml
spec:
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 13.2.2
    helm:
      values: |
        service:
          type: ClusterIP
```
---
### 4. Multi-Environment Best Practices
```
apps/
├── base/                 # Common base configuration
│   ├── deployment.yaml
│   └── kustomization.yaml
├── dev/                  # Development environment
│   ├── kustomization.yaml
│   └── values.yaml
├── staging/              # Staging environment
│   └── ...
└── prod/                 # Production environment
    └── ...
```
Alternative Helm Structure
```
apps/
├── chart/
│   └── templates/...
├── envs/
│   ├── dev/
│   │   └── values.yaml
│   ├── staging/
│   └── prod/
```
- you would create three separate applications, each pointing to a different environment path and configuration:

  - **For Staging :**
```yaml
source:
  path: envs/staging
  helm:
    valueFiles:
      - values.yaml
```


