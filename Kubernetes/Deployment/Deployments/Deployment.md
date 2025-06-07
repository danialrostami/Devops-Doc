# Kubernetes Deployments:

## What is a Deployment?
A Deployment manages application updates and scaling in Kubernetes. It provides:
- Declarative updates for Pods/ReplicaSets
- Rolling updates & rollbacks
- Scaling capabilities
- Self-healing (replaces failed Pods)

## Basic Deployment Example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```
## Key Components Explained

- **apiVersion**: `apps/v1`  
  Indicates this is a Deployment resource.

- **kind**: `Deployment`  
  Specifies the type of workload (manages Pods and provides updates).

- **metadata**:
  - `name`: `nginx-deployment`  
    Unique identifier for this Deployment.
  - `labels`:  
    Key-value pairs (`app: nginx`) used for identification and management.

- **spec** (core configuration):
  - `replicas`: `3`  
    Number of identical Pod instances to maintain.
  - `selector`:  
    Controls which Pods the Deployment manages (matches Pods with `app: nginx` label).
  - `template`: Pod specification blueprint  
    - **metadata**:  
      Labels (`app: nginx`) applied to created

### Deployment Output

1- Check running pods
```
kubectl get po -n devops
```
```
| NAME                                | READY | STATUS  | RESTARTS | AGE  |
|-------------------------------------|-------|---------|----------|------|
| nginx-deployment-74676ff58f-bjqrh   | 1/1   | Running | 0        | 18m  |
| nginx-deployment-74676ff58f-dcj48   | 1/1   | Running | 0        | 18m  |
| nginx-deployment-74676ff58f-fxlx2   | 1/1   | Running | 0        | 18m  |
```
2- Check deployment
```
kubectl get deployments.apps -n devops -o wide
```

```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES       SELECTOR
nginx-deployment   3/3     3            3           31m   nginx        nginx:1.21   app=nginx
```
This command shows general information about Deployments in the `devops` namespace.

#### Column Descriptions:

| Column | Description |
|--------|-------------|
| **NAME** | Deployment name (e.g., `nginx-deployment`) |
| **READY** | Number of ready pods (e.g., `3/3` means 3 out of 3 pods are ready) |
| **UP-TO-DATE** | Number of pods updated to match the latest Deployment version (e.g., `3`) |
| **AVAILABLE** | Number of currently available pods that can process requests (e.g., `3`) |
| **AGE** | Time elapsed since Deployment creation (e.g., `31m` for 31 minutes) |
| **CONTAINERS** | Name of containers running in the pods (e.g., `nginx`) |
| **IMAGES** | Container images being used (e.g., `nginx:1.21`) |
| **SELECTOR** | Labels the Deployment uses to manage pods (e.g., `app=nginx`) |
---

## Deployment Key Features
#### 1. Scaling
Kubernetes Scaling Methods
#####  Scaling with kubectl scale

* Scale Up (Increase Pods):
```bash
kubectl scale deployment -n devops nginx-deployment --replicas=5
```
* Scale Down (Decrease  Pods):
```bash
kubectl scale deployment -n devops nginx-deployment --replicas=2
```

##### Scaling via YAML Manifest
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 5  # Adjust this value
```
##### Verifying Scaling
```
kubectl get pods -n devops
kubectl get deployment -n devops
```

- **READY** = Running Pods
- **UP-TO-DATE** = Synced Pods
- **AVAILABLE** = Healthy Pods

---
### 2. Update Strategies
#### Overview
Kubernetes provides robust update strategies to manage application deployments with different availability requirements. The strategy determines how Pods are replaced during updates.

#### Update Strategy Types

- #### RollingUpdate Mechanism:
1. **Gradual Replacement**:
   - Kubernetes replaces Pods incrementally
   - New Pods are brought up before old ones are terminated
2. **Parameters Control**:
   - `maxUnavailable`: Limits how many Pods can be down during update
   - `maxSurge`: Allows temporary over-provisioning of Pods
3. **Traffic Flow**:
   - Service continuously routes traffic to available Pods
   - No user-visible interruption

- **Use Cases**: 
  - Web applications
  - Microservices
  - APIs
---------

- #### Recreate Mechanism:
1. **Complete Termination**:
   - First terminates ALL existing Pods
   - Then creates ALL new Pods
2. **Behavior**:
   - No intermediate state with mixed versions
   - Clear "offline" period during switchover
3. **Traffic Impact**:
   - Service unavailable until new Pods are ready
   - All connections are dropped during update

- **Use Cases**:
  - Database migrations
  - Singleton applications
  - Jobs requiring exclusive access
 
## Strategy Comparison

| Feature          | RollingUpdate         | Recreate        |
|------------------|-----------------------|-----------------|
| **Availability** | Continuous            | Downtime        |
| **Resource Usage** | Temporary increase  | Normal          |
| **Rollback Speed** | Fast                | Slow            |
| **Complexity**   | Moderate              | Simple          |
| **Best For**     | Production services   | Batch jobs      |
---
#### How RollingUpdate Works (Step-by-Step)

1. **Initial State**  
   Cluster has N Pods running version v1  
   Example: 3 Pods (v1, v1, v1)

2. **Update Trigger**  
   New Deployment manifest with image v2 applied

3. **Update Process**:
```

    A[Initial: 🟢🟢🟢] --> B[Phase 1: 🟢🟢⚪→🟢🟢🟣]

    B --> C[Phase 2: 🟢⚪🟣→🟢🟣🟣]

    C --> D[Complete: ⚪🟣🟣→🟣🟣🟣]

```
---
**Configuration Parameters -> RollingUpdate**

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # Number/percentage of pods that can be unavailable during update
      maxSurge: 1          # Number/percentage of extra pods allowed
      
```
**Configuration Parameters -> Recreate**

```yaml
spec:
  strategy:
    type: Recreate
    template:
      spec:
        terminationGracePeriodSeconds: 60
      
```
---

### 3. Health Checks (Probes)

#### What Are Probes?
Mechanisms to check container health states:
- **Liveness**: Is the container running? (Restarts if unhealthy)
- **Readiness**: Is it ready to serve traffic? (Removes from service if not)
- **Startup**: Did the app start successfully? (Terminates if startup fails)

##### Probe Types & Use Cases
| Type         | Action on Failure               | When to Use                          |         Purpose        |
|--------------|---------------------------------|--------------------------------------|------------------------|
| **Liveness** | Restarts container              | Detect crashes/hangs                 | Is container running?  |
| **Readiness**| Removes from service endpoints  | During initialization/transient loads| Is container ready?    | 
| **Startup**  | Terminates container            | Slow-starting applications           | Is app initalized?     |

#### Probe Handlers (3 Methods)
##### 1. HTTP GET
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10
```
##### 2. TCP Socket
```yaml
readinessProbe:
  tcpSocket:
    port: 3306
  timeoutSeconds: 1
```
##### 3. Exec Command
```yaml
startupProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
```
#### Key Configuration Parameters
| Parameter              | Description                          | Default |
|------------------------|--------------------------------------|---------|
| `initialDelaySeconds`  | Wait time after container starts     | 0       |
| `periodSeconds`        | Check interval between probes        | 10      |
| `timeoutSeconds`       | Probe timeout duration               | 1       |
| `successThreshold`     | Consecutive successes to be healthy  | 1       |
| `failureThreshold`     | Consecutive failures to be unhealthy | 3       |

#### Complete Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: app
    image: nginx:latest
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /status
        port: 80
      initialDelaySeconds: 5
    readinessProbe:
      tcpSocket:
        port: 80
      periodSeconds: 5
    startupProbe:
      httpGet:
        path: /warmup
        port: 80
      failureThreshold: 30  # Allow 30*5=150s max startup
```
#### Key takeaways:
- 🚦 **Startup probes** prevent traffic to unready containers
- ⏱️ **Tune parameters** for your app's startup characteristics
- 🔍 **Always verify** with `kubectl get/describe` commands
- 🔄 **Combine probes** for complete health monitoring

---
#### 4. Rollbacks
```bash
# View rollout history
kubectl rollout history deployment/nginx-deployment

# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Rollback Status
kubectl rollout status deployment <deployment-name> -n <namespace>
```
#### Notes About Rollback in Kubernetes
1- To retain more versions, set revisionHistoryLimit in the Deployment:
```yaml
spec:
  revisionHistoryLimit: 5  # Keeps last 5 revisions
```
2- Use annotations to document the reason for changes in rollout history:
```yaml
metadata:
  annotations:
    kubernetes.io/change-cause: "Updated image to nginx:1.22 for security"
```
3- Rollback is Deployment-Specific

---

#### 5. Autoscaling (HPA)
```yaml
# Autoscale between 2-10 pods based on CPU
kubectl autoscale deployment nginx-deployment \
  --cpu-percent=50 \
  --min=2 \
  --max=10

```
##### Autoscaling with Manifest
1. ##### Deployment Manifest
First, define the Deployment (if you don't already have one):

Automatically scale Pods between 2-10 replicas when CPU usage exceeds 50%.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: app
        image: nginx
        resources:
          requests: { cpu: "250m" }  # Required for HPA
```
2. #### HPA (hpa.yaml)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```
* Key points:
- Deployment must have resources.requests.cpu
- HPA needs:

    Target Deployment reference

    Min/max replica counts

    CPU threshold (50% in this case)

3. #### Apply
```
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml
```
4. #### Check
```bash
kubectl get hpa -n <namespace>
```
```plaintext
NAME           REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
nginx-hpa      Deployment/nginx-deployment   60%/50%   2         10        3          5d4h
```
For output: `60%/50%  2   10  3`
- CPU usage at 60% (above 50% threshold)
- Will maintain between 2-10 Pods
- Currently running 3 Pods
- System will likely scale up soon

---

#### 6. Kubernetes Deployment Pause/Unpause

##### Overview
- **Pause**: Temporarily stops a deployment rollout.
- **Unpause**: Resumes a paused rollout.

##### Key Features
✅ **Batch changes**: Apply multiple updates while paused  
✅ **Rollout control**: Manually trigger when changes go live  
✅ **Safety check**: Verify changes before they deploy  

##### Commands
| Action | Command |
|--------|---------|
| Pause  | `kubectl rollout pause deployment <name>` |
| Unpause | `kubectl rollout resume deployment <name>` |
| Check Status | `kubectl rollout status deployment <name>` |

##### When to Use
- 🛑 Testing sensitive configuration changes
- 🔄 Making multiple related updates
- 👀 Verifying changes before production rollout

##### Workflow Example
1. Pause deployment
2. Apply changes (won't deploy)
```
kubectl set image deployment/nginx-deployment nginx=nginx:1.23
deployment.apps/nginx-deployment image updated
```
3. Test/verify changes
4. Unpause to deploy
5. Monitor rollout status

---

#### Kubernetes Deployment Commands

| Command | Description |
|---------|-------------|
| `kubectl create deployment <name> --image=<image>`| Creates a new deployment with the specified name and container image. |
| `kubectl get deployment <name>`| Shows detailed information about a specific deployment. |
| `kubectl describe deployment <name>`| Displays detailed information about a deployment including events and conditions. |
| `kubectl edit deployment <name>`| Opens the deployment manifest in the default editor for live editing. |
| `kubectl scale deployment <name> --replicas=<count>`| Scales the deployment to the specified number of replicas. |
| `kubectl rollout status deployment/<name>`| Shows the current rollout status of a deployment. |
| `kubectl rollout history deployment/<name>`| Displays the revision history of a deployment. |
| `kubectl rollout undo deployment/<name>`| Rolls back to the previous deployment revision. |
| `kubectl rollout undo deployment/<name> --to-revision=<number>`| Rolls back to a specific deployment revision. |
| `kubectl set image deployment/<name> <container>=<new-image>`| Updates the container image for a deployment. |
| `kubectl delete deployment <name>`| Deletes a deployment.|
| `kubectl apply -f <deployment-file.yaml>`| Applies a deployment configuration from a YAML file. |
| `kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","image":"<new-image>"}]}}}}'`| Patches a deployment with a partial update. |
| `kubectl autoscale deployment <name> --min=<min-pods> --max=<max-pods> --cpu-percent=<target>`| Creates an autoscaler for a deployment.| 
| `kubectl logs <pod-name> -n <Name-Space>`                 | View container logs              | 

---

#### Practical Example: Updating a Deployment
1- Edit the deployment:
```bash
kubectl edit deployment nginx-deployment
```
2- Change the image version:
```
containers:
- name: nginx
  image: nginx:1.22 # Updated version
```
3- Monitor the rollout:
```
kubectl rollout status deployment/nginx-deployment
```
---
#### Practical Example:Deployment with Startup Probe

##### Deployment Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    kubernetes.io/change-cause: 'change nginx image to 1.22'  # Audit trail for changes
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1  # Single pod instance
  selector:
    matchLabels:
      app: nginx  # Targets pods with this label
  template:
    metadata:
      labels:
        app: nginx  # Applied to created pods
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # Specific image version
        ports:
        - containerPort: 80  # Exposed container port
        startupProbe:
          httpGet:
            path: /         # Health check endpoint
            port: 80        # Port to check
          periodSeconds: 10  # Check every 10 seconds
          failureThreshold: 10 # Allow 10 failures before restart
```
##### Deployment Verification
```yaml
# Apply the configuration
kubectl apply -f startup-probe.yaml -n devops

# Check pod status
kubectl get po -n devops
```

```bash
NAME                   READY   STATUS    RESTARTS   AGE
nginx-769c67b8b4-cvh4h 1/1     Running   0          7s
```

##### Event Log Analysis
```yaml
kubectl describe -n devops po nginx-769c67b8b4-cvh4h
```

```bash
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  20s   default-scheduler  Successfully assigned
  Normal  Pulled     19s   kubelet            Image already present
  Normal  Created    19s   kubelet            Container created
  Normal  Started    19s   kubelet            Container started
```
---
  - Always define resource requests/limits
  - Use RollingUpdate for production workloads
  - Configure proper liveness/readiness probes
  - Set appropriate revisionHistoryLimit
  - Use namespaces for environment separation


