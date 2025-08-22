## Pod Affinity: Quick Summary

## What It Is
A Kubernetes feature to control Pod placement relative to other Pods.
In simple terms, it lets you specify that a Pod should be scheduled close to (or away from) another Pod, potentially on the same node or within the same failure domain.

## The Two Main Types
- **Affinity (Attraction)**: Force Pods to run *near* each other
- **Anti-Affinity (Repulsion)**: Force Pods to run *away* from each other

## Why Use It?
- **Performance**: Keep communicating Pods close (e.g., app + cache)
- **Reliability**: Spread Pods across nodes (anti-affinity) for high availability
- **Efficiency**: Group resource-heavy Pods together.
#
### Pod Affinity Example 

**Goal**: Ensure an application pod runs on the same node as its database.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  labels:
    app: my-app
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - my-database
          topologyKey: "kubernetes.io/hostname"
  containers:
  - name: app-container
    image: nginx
```
- The `app-pod` will **only be scheduled** on a node that already has a pod running with the label `app: my-database`.

## Pod Anti-Affinity Example
**GOAL**: Prevent similar pods from running on the same node for high availability
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  labels:
    app: my-app
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - my-app
          topologyKey: "kubernetes.io/hostname"
  containers:
  - name: app-container
    image: nginx
```
- The `requiredDuringSchedulingIgnoredDuringExecution`  means that the Pod Affinity or Anti-Affinity rule must be followed during scheduling, but it is not enforced or rechecked after the pod is running.

- The `app-pod` will **avoid being scheduled** on any node that already has a pod running with the label `app: my-app`.
---
## Node Affinity in Kubernetes

### Overview
Node Affinity is a Kubernetes feature that allows you to specify which nodes a Pod should or should not run on. It provides control over Pod placement based on node labels and characteristics.

### Key Use Cases
- **Resource Management**: Target Pods to nodes with specific resources (e.g., GPU, high memory)
- **Performance Optimization**: Ensure Pods run on hardware that meets application requirements
- **Compliance**: Enforce rules like running Pods in specific zones or regions
- **Prevention**: Avoid unsuitable nodes (e.g., under-resourced nodes)


## Types of Node Affinity

### 1. RequiredDuringSchedulingIgnoredDuringExecution
- **Strict rule**: Pod will only run on nodes meeting the condition
- **Result**: Pod won't schedule if no matching node is available

### 2. PreferredDuringSchedulingIgnoredDuringExecution  
- **Flexible rule**: Kubernetes prefers nodes meeting the condition
- **Result**: Pod will still schedule on other nodes if no preferred node available

### Example: Zone Preference
**Goal**: Prefer running a Pod on nodes labeled `zone: us-east-1`, but allow it to run elsewhere if needed.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: zone-pod
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - "us-east-1"
  containers:
  - name: zone-container
    image: nginx
```
- Kubernetes will prefer nodes with the label zone: `us-east-1`

- If no such node is available, the Pod will still schedule on other nodes
- weight: Relative priority (1-100) when multiple preferences exist

## Node Anti-Affinity
Node Anti-Affinity allows you to specify which nodes a Pod should **avoid**. Instead of saying "where a Pod should run," you specify "where a Pod should **not** run."
#
### When to Use
- Spreading similar Pods across nodes
- Avoiding nodes with limited resources
- Preventing traffic concentration on a single node
- Enforcing custom exclusion rules
#
### Types

### 1. RequiredDuringSchedulingIgnoredDuringExecution
- **Strict Rule**: Pod will not run on nodes matching the condition.
- **Result**: Pod won't schedule if no other nodes are available.

### 2. PreferredDuringSchedulingIgnoredDuringExecution  
- **Flexible Rule**: Kubernetes prefers nodes that don't match the condition.
- **Result**: Pod will still schedule on other nodes if no preferred node is available.

#
### Example: Excluding Specific Nodes
**Goal**: Prevent a Pod from running on nodes labeled `zone: us-east-1`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: anti-affinity-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: zone
            operator: NotIn     # <-- "In" operator for affinity
            values:             # <-- "NotIn" operator for anti-affinity
            - "us-east-1"
  containers:
  - name: nginx-container
    image: nginx
```
- uses `nodeAffinity` with the `NotIn` operator instead of a nodeAntiAffinity 
