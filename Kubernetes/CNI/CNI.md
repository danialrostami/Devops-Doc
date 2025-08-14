# Kubernetes CNI (Container Network Interface) Guide

## What is CNI?
CNI (Container Network Interface) is a plugin-based networking standard that enables Kubernetes to:
- Assign IP addresses to Pods
- Establish network connectivity between Pods, nodes, and external services
- Manage network policies and routing

## Why CNI Matters
- **Pod-to-Pod communication**: Across same node or different nodes
- **External connectivity**: Access to databases, APIs, and internet
- **Ingress traffic**: Handling user requests to applications
- **Network isolation**: Security between applications

## How CNI Works
```mermaid
sequenceDiagram
    participant K as Kubelet
    participant C as CNI Plugin
    participant N as Network
    
    K->>C: Pod Created - Need Network
    C->>N: Allocate IP
    C->>N: Configure Routes
    C->>K: Network Ready
```
### Popular CNI Plugins
| Plugin       | Best For            | Key Features                     | Performance | Network Policies |
|--------------|---------------------|----------------------------------|-------------|------------------|
| Flannel      | Small clusters      | Simple overlay network           | Good        | ❌ No            |
| Calico       | Security-focused    | BGP routing, NetworkPolicies     | Excellent   | ✅ Yes           |
| Cilium       | Advanced clusters   | eBPF-based, L7 policies          | Best        | ✅ Yes           |
| Weave        | Medium clusters     | Easy setup, encryption           | Good        | ✅ Yes           |
| Cloud CNIs   | Native cloud integration | AWS/Azure/GCP VPC integration | Excellent   | ✅ Yes           |

---
## Flannel in Kubernetes?

Flannel is one of the simplest and most popular CNI plugins for Kubernetes that provides networking between Pods across different nodes.

## Key Features
- Lightweight overlay network solution
- Simple Layer 3 network fabric
- Uses etcd or Kubernetes API for network state storage
- Supports multiple backends (VXLAN, host-gw, etc.)
- Automatically assigns subnets to each node
- No built-in network policies (unlike Calico/Cilium)

## How Flannel Works
1. Each node runs a `flanneld` daemon
2. Flannel allocates a subnet lease to each node
3. Creates virtual network interfaces on each host
4. Encapsulates traffic between nodes using configured backend

## Flannel Networking Schematic

```mermaid
flowchart TB
    %% Left Node
    subgraph Node1["Node 1 (192.168.1.10)"]
        P1["Pod 1 (10.244.1.2)"] --> VETH1["veth0"]
        P2["Pod 2 (10.244.1.3)"] --> VETH2["veth1"]
        VETH1 --> CNI1["cni0 Bridge (10.244.1.1)"]
        VETH2 --> CNI1
        CNI1 --> FL1["flanneld (10.244.1.0/24) (VXLAN Endpoint)"]
        FL1 --> ETH1["eth0 (192.168.1.10)"]
    end

    %% Right Node
    subgraph Node2["Node 2 (192.168.1.11)"]
        P3["Pod 3 (10.244.2.2)"] --> VETH3["veth0"]
        P4["Pod 4 (10.244.2.3)"] --> VETH4["veth1"]
        VETH3 --> CNI2["cni0 Bridge (10.244.2.1)"]
        VETH4 --> CNI2
        CNI2 --> FL2["flanneld (10.244.2.0/24) (VXLAN Endpoint)"]
        FL2 --> ETH2["eth0 (192.168.1.11)"]
    end

    %% Network Connection
    ETH1 <-->|"VXLAN Tunnel (UDP 8472)"| ETH2
```
### Communication flow (pod1 --> pod4)
```
[Pod1 (10.244.1.2)]-> veth0 ->[cni0 (10.244.1.1)]-> [flanneld]->[eth0 (192.168.1.10)]-> VXLAN encap ->
                                                                                                 
->  VXLAN decap ->[eth0 (192.168.1.11)]->[flanneld]->[cni0 (10.244.2.1)]-> veth1 ->[Pod4 (10.244.2.3)]
```
---
