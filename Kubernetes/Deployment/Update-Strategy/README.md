# Kubernetes Deployment Update Strategies

## Overview
Kubernetes provides robust update strategies to manage application deployments with different availability requirements. The strategy determines how Pods are replaced during updates.

## Update Strategy Types

### RollingUpdate Mechanism
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

### Recreate Mechanism
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
## How RollingUpdate Works (Step-by-Step)

1. **Initial State**  
   Cluster has N Pods running version v1  
   Example: 3 Pods (v1, v1, v1)

2. **Update Trigger**  
   New Deployment manifest with image v2 applied

3. **Update Process**:

```mermaid
graph TD
    A[Initial State: 3 Pods v1] --> B[Terminate 1 Pod v1]
    B --> C[Create 1 Pod v2]
    C --> D[State: 2v1 + 1v2]
    D --> E[Terminate 1 Pod v1]
    E --> F[Create 1 Pod v2]
    F --> G[State: 1v1 + 2v2]
    G --> H[Terminate last Pod v1]
    H --> I[Create final Pod v2]
    I --> J[Final State: 3 Pods v2]
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


