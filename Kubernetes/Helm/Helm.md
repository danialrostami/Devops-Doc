# Helm: The Kubernetes Package Manager

## Overview
Helm is a package manager for Kubernetes that simplifies deploying and managing complex applications. It acts like `apt` or `yum` for Kubernetes, allowing you to package, share, and deploy applications easily.

## Problem Solved by Helm
Managing multiple Kubernetes YAML files (Deployment، Service، ConfigMap , ... ) manually becomes challenging because:
- Complexity increases with application size
- Reusability across environments (dev, staging, production) is difficult
- Updating applications is error-prone and time-consuming

## Benefiets
- **Simplified Management**: Package all resources together
- **Reusability**: Use charts across projects and environments
- **Easy Updates**: Upgrade with single commands
- **Version Management**: Rollback to previous versions
- **Customization**: Configure easily via values.yaml

## Helm Charts
A **Chart** is a packaged application containing all necessary Kubernetes resources:
```
my-chart/                 # Chart Directory
├── Chart.yaml           # Chart Metadata (name, version, description, etc.)
├── values.yaml          # Default Configuration Values
├── templates/           # Kubernetes Manifest Templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ...             # Other Kubernetes resources
|
└── charts/              # Directory for Dependent Sub-Charts
    ├── sub-chart-1/
    └── sub-chart-2/
```

## Key Components
- **Helm CLI**: Command-line tool for managing charts
- **Charts**: Application packages 
## Workflow
1. Install Helm on your system
2. Add repositories: `helm repo add [repo-name] [url]`
    - **Use pre-built charts** from repositories (e.g., nginx, mysql)
    - **Create your own chart** for custom applications using `helm create`
3. Search charts: `helm search repo [name]`
4. Use Helm Commands
    - Install: `helm install my-release chart-name`
    - Upgrade: `helm upgrade my-release chart-name`
    - Uninstall: `helm uninstall my-release`

5. Customize with values.yaml with Override default configurations in the chart's `values.yaml` 

## Essential Commands

| Command | Description |
| :--- | :--- |
| `helm repo add bitnami https://charts.bitnami.com/bitnami` | Add a Helm chart repository |
| `helm search repo nginx` | Search for charts in added repositories |
| `helm install my-nginx bitnami/nginx` | Install a chart release |
| `helm upgrade my-nginx bitnami/nginx --set replicaCount=3` | Upgrade a release with new configuration |
| `helm list` | List all deployed releases |
| `helm uninstall my-nginx` | Uninstall a release |
| `helm status my-nginx` | Show the status of a named release |
| `helm get values my-nginx` | Display the configured values for a release |
| `helm repo update` | Update information of available charts locally |
---
## Example: Deploying MySQL
```yaml
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-mysql bitnami/mysql
```
- Need to change replicas or database password?

**Option 1**: Using --set flag
```
helm upgrade my-mysql bitnami/mysql --set replicaCount=3
```
**Option 2**: Using custom values file

  - Get default values: `helm show values bitnami/mysql > custom-values.yaml`
  - Edit custom-values.yaml
  - Apply: `helm upgrade my-mysql bitnami/mysql -f custom-values.yaml`
---
