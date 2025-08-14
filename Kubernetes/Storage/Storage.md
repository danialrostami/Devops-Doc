# Kubernetes Storage: Overview and Types

## What is Kubernetes Storage?
Storage in Kubernetes provides persistent data storage for applications running in pods.

## Why Use Kubernetes Storage?
- **Data persistence**: Preserve data across pod restarts
- **Data sharing**: Allow multiple pods to access the same data
- **Flexibility**: Move data between nodes/servers easily

## Storage Types


| Type               | Purpose                          | Use Case                          | Pros                              | Cons                              |
|--------------------|----------------------------------|-----------------------------------|-----------------------------------|-----------------------------------|
| **EmptyDir**       | Temporary pod storage            | Cache files, temporary workspace  | Simple, fast                      | Data lost when pod terminates     |
| **HostPath**       | Access node's local filesystem   | Node-specific data like logs      | Direct node storage access        | Not portable across nodes         |
| **PV/PVC**         | Long-term persistent storage     | Databases, critical app data      | Survives pod restarts, multi-backend support | Requires more configuration       |
| **ConfigMaps/Secrets** | Store config data and secrets | App configs, API keys, passwords  | Secure, Kubernetes-native         | Not for large data                |
| **Cloud Volumes**  | Cloud provider storage           | AWS EBS, Azure Disk deployments   | Scalable, reliable                | Cloud provider lock-in            |
| **NFS**            | Shared network storage           | Shared access across pods         | Multi-node access                 | Potential performance issues      |



### Key Components
- **PersistentVolume (PV)**: Cluster storage resource
- **PersistentVolumeClaim (PVC)**: Pod's storage request
- **StorageClass**: Defines storage "types" available

## Storage Engines: 

### What is a Storage Engine?
A storage engine is software that handles data storage, management, and retrieval. It acts as the "brain" of data storage, determining:
- How data is physically stored on disk
- Methods for data access and retrieval
- Data management techniques


### Storage Engine Types Comparison

| Type               | Description                      | Best For                          | Pros                              | Cons                              |
|--------------------|----------------------------------|-----------------------------------|-----------------------------------|-----------------------------------|
| **File Storage**   | Data stored as files with paths  | Documents, media, file sharing    | Simple, human-readable            | Poor performance at scale         |
| **Block Storage**  | Data split into fixed-size blocks | Databases, virtualization         | High performance, low latency     | Complex management                |
| **Object Storage** | Data stored as objects with metadata | Cloud storage, backups, unstructured data    | Massive scalability, API-based access | Higher latency                    |
| **Relational**     | Tabular data with relationships  | Transactional systems, Structured transactional data | ACID compliance, complex queries  | Poor horizontal scaling           |
| **NoSQL**          | Schemaless document/key-value    | Big data, IoT, social media       | Flexible schema, horizontal scale | Limited query capabilities        |
| **In-Memory**      | Data stored in RAM               | Caching, real-time systems        | Ultra-fast access                 | Volatile, expensive               |
| **Distributed**    | Data spread across multiple nodes | Cloud systems, big data         | Fault-tolerant, scalable          | Complex to implement              |
---
### Troubleshooting
#### Check PVC status
```
kubectl get pvc
```
#### View PV details
```
kubectl describe pv <pv-name>
```

#### Check storage classes
```
kubectl get storageclass
```
#### View mounted volumes in pod
```
kubectl exec <pod> -- df -h
```

