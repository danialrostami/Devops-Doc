# Kubernetes Object Management

## 1. Live Objects (Imperative Commands)

Live Objects are created and managed directly through CLI commands, similar to `docker run` in Docker.

**How to work with Live Objects:**
- Use imperative commands like `kubectl create` or `kubectl edit`
- Fast and simple method
- Changes are applied directly to the cluster
- Configuration is not typically saved

**Example:**
```bash
kubectl create deployment my-app --image=nginx
```
## 2.Individual Files (Declarative)

Each resource is defined in a YAML configuration file (manifest) that specifies all details.

How it works:  

  - Create a YAML file with desired configuration  
  - Apply it using `kubectl apply -f`  

Example Manifest:
``` yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app.kubernetes.io/name: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```
Apply with:
```bash
kubectl apply -f my-app.yaml
```

## 3. Declarative Object Configuration

Advanced method for managing multiple configuration files in a directory structure.

How it works:

  - Store related manifests in a directory

  - Apply all configurations together

Example Directory Structure:

configs/

├── deployment.yaml

├── service.yaml

└── ingress.yaml

Apply all:
``` bash
kubectl apply -f configs/
```

## 4. Helm (Package Manager)

Helm is Kubernetes' package manager that simplifies deployment of complex applications.

Key Features:

  - Uses "Charts" (pre-configured application packages)

  - Manages dependencies and configurations

  - Ideal for production environments

---
### Kubernetes Manifest Structure

Every manifest must contain these four required fields:
#### 1. apiVersion

Specifies which API version to use.

Examples:

  * Pod: v1

  * Deployment: apps/v1

#### 2. kind

Defines the type of resource to create.

Examples:

  * Pod

  * Deployment

  * Service

#### 3. metadata

Contains identifying information.

Required:

  * name: Unique identifier for the object

Optional:

  * labels: For categorization

  * annotations: Additional metadata

#### 4. spec

Describes the desired state of the object.

Example Pod spec:
```yaml
spec:
  containers:
  - name: nginx
    image: nginx:latest
```

## Understanding spec vs status

| Field          | Description                          | Managed By     | Example Content                          |
|----------------|--------------------------------------|----------------|------------------------------------------|
| **spec**       | Desired state of the object          | User (you)     | `containers:`, `replicas: 3`, `image: nginx` |
| **status**     | Current actual state of the object   | Kubernetes     | `phase: Running`, `conditions: Ready`    |

- Never modify `status` manually - it's controlled by Kubernetes


Complete Example Manifest
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
status:
  phase: Running
  conditions:
  - type: Ready
    status: "True"
```

Key Takeaways

 Four mandatory fields in every manifest:

  - apiVersion

- kind

- metadata

- spec

Choose the right management approach:
## 2. Choosing the Right Management Approach

| Approach Type       | Method               | When to Use                                      | Pros                                      | Cons                                      | Example Command                          |
|---------------------|----------------------|--------------------------------------------------|-------------------------------------------|-------------------------------------------|------------------------------------------|
| **Imperative**      | Direct CLI Commands  | Quick tests, learning, troubleshooting          | Fast execution, simple one-off commands   | Not reproducible, hard to track changes  | `kubectl run nginx --image=nginx:latest` |
| **Declarative**     | YAML Manifests       | Production environments, CI/CD pipelines        | Version controllable, reproducible       | More initial setup required               | `kubectl apply -f deployment.yaml`       |
| **Package Manager** | Helm Charts          | Complex applications with multiple components   | Handles dependencies, templating, versions | Learning curve, additional tooling needed | `helm install my-app ./chart`            |



