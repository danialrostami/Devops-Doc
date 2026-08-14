# Kubernetes HA Cluster Installation With Kubeadm

A step-by-step installation guide for a Kubernetes cluster with **2 control-plane nodes**, **1 worker node**, **HAProxy**, and a **private container registry**.

>  Configuration values, IP addresses, ports, image references, command variants, and the original process flow are preserved as provided. Review the version values before production use because the source note contains more than one Kubernetes and image version set.

---

## Contents

1. [Cluster Component Map](#1-cluster-component-map)
2. [Deployment Paths](#2-deployment-paths)
3. [Common Prerequisites for All Nodes](#3-common-prerequisites-for-all-nodes)
4. [Configure Kernel Modules and Sysctl Parameters](#4-configure-kernel-modules-and-sysctl-parameters)
5. [Install and Configure containerd](#5-install-and-configure-containerd)
6. [Install kubeadm, kubelet, and kubectl](#6-install-kubeadm-kubelet-and-kubectl)
7. [Configure HAProxy](#7-configure-haproxy)
8. [Approach A: Internet-Based Installation](#8-approach-a-internet-based-installation)
   - [Pull Required Images](#81-pull-required-images)
   - [Initialize Master 1](#82-initialize-master-1)
   - [Configure kubectl](#83-configure-kubectl)
   - [Install Flannel from the Internet](#84-install-flannel-from-the-internet)
   - [Join Master 2 and Worker 1](#85-join-master-2-and-worker-1)
9. [Approach B: Private Registry / Restricted-Network Installation](#9-approach-b-private-registry--restricted-network-installation)
   - [Set Up the Private Registry](#91-set-up-the-private-registry)
   - [Tag and Push Kubernetes Images](#92-tag-and-push-kubernetes-images)
   - [Configure containerd to Use the Private Registry](#93-configure-containerd-to-use-the-private-registry)
   - [Initialize Master 1 Using the Private Registry](#94-initialize-master-1-using-the-private-registry)
   - [Join Master 2 and Worker 1](#95-join-master-2-and-worker-1)
   - [Install Flannel from the Private Registry](#96-install-flannel-from-the-private-registry)
10. [Verification](#10-verification)
11. [Configuration Checklist](#11-configuration-checklist)

---

## 1. Cluster Component Map

### 1.1 Topology

```text
                                Kubernetes API traffic
                                         TCP/6443
                                              |
                              +---------------+---------------+
                              |                               |
                    HAProxy / API endpoint             Optional Keepalived VIP
                    192.168.37.10                       (not configured here)
                              |
                    +---------+---------+
                    |                   |
          Master 1 / Control Plane   Master 2 / Control Plane
          192.168.37.13              192.168.37.14
          Private registry:5000
                    |
                    |
              Worker Node 1
              IP: <NODE1_IP>
```

### 1.2 Component and Address Table

| Component | Hostname / Role | IP address | Ports | Purpose |
|---|---|---:|---|---|
| HAProxy | API load balancer | `192.168.37.10` | `6443/TCP` | Load-balances Kubernetes API traffic to both control-plane nodes |
| Master 1 | `k8s-master`, initial control plane | `192.168.37.13` | `6443/TCP`, `5000/TCP` | Initializes the cluster and hosts the private registry |
| Master 2 | Second control plane | `192.168.37.14` | `6443/TCP` | Joins the cluster as a control-plane node |
| Worker 1 | `k8s-node1` | `<NODE1_IP>` | Kubernetes node ports as required by the selected CNI | Runs application workloads |
| Private registry | Registry service on Master 1 | `192.168.37.13:5000` | `5000/TCP` | Stores Kubernetes and Flannel images for offline or restricted deployments |

### 1.3 Required Traffic

- Every Kubernetes node must reach the HAProxy endpoint at `192.168.37.10:6443`.
- HAProxy must reach both API servers:
  - `192.168.37.13:6443`
  - `192.168.37.14:6443`
- Every Kubernetes node must reach the private registry at `192.168.37.13:5000` when using the registry-based installation.
- The registry is configured as an HTTP/insecure registry in the supplied containerd configuration. Use TLS for a production deployment.

---

## 2. Deployment Paths

This guide separates the installation into two clear approaches:

### Approach A — Internet-Based Installation

Use this path when all required nodes can access the Internet directly and can pull Kubernetes and CNI images from public registries.

### Approach B — Private Registry / Restricted-Network Installation

Use this path when one or more nodes do **not** have full Internet access and images must be served from a private registry at:

```text
192.168.37.13:5000
```

> Suggested reading order:
>
> 1. Complete the common setup sections first.
> 2. If your servers have Internet access, continue with **Approach A**.
> 3. If your servers have restricted Internet access, skip to **Approach B** after the common setup sections.

---

## 3. Common Prerequisites for All Nodes

Run the following steps on every Kubernetes node, including both control-plane nodes and all workers.

### 3.1 Install conntrack

```bash
sudo yum install -y conntrack
```

### 3.2 Disable Firewall and SELinux

```bash
# Disable and stop firewalld
sudo systemctl disable --now firewalld

# Set SELinux to permissive mode immediately
sudo setenforce 0

# Disable SELinux after reboot
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

### 3.3 Configure Hostnames

Use a unique hostname on each node.

```bash
# On Master 1
sudo hostnamectl set-hostname k8s-master

# On Worker 1
sudo hostnamectl set-hostname k8s-node1

# Set an appropriate unique hostname on Master 2, for example:
# sudo hostnamectl set-hostname k8s-master2
```

### 3.4 Configure `/etc/hosts`

Run on **all nodes** and replace the placeholders with the actual addresses.

```bash
cat <<EOF | sudo tee -a /etc/hosts
<MASTER_IP>   k8s-master
<NODE1_IP>    k8s-node1
<NODE2_IP>    k8s-node2
EOF
```

For the topology in this document, the entries should represent Master 1, Master 2, and Worker 1. Avoid adding duplicate entries when rerunning the command.

### 3.5 Disable Swap

Kubernetes requires swap to be disabled unless the cluster is explicitly configured for swap support.

```bash
sudo swapoff -a
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab
```

---

## 4. Configure Kernel Modules and Sysctl Parameters

### 4.1 Load Required Kernel Modules

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### 4.2 Configure Network Forwarding

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

---

## 5. Install and Configure containerd

Perform this section on all Kubernetes nodes.

### 5.1 Add the Docker Repository

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 5.2 Install containerd

```bash
sudo dnf install -y containerd.io
```

### 5.3 Generate the containerd Configuration

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

### 5.4 Enable containerd

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

## 6. Install kubeadm, kubelet, and kubectl

Perform this section on all Kubernetes nodes.

### 6.1 Add the Kubernetes Repository

The supplied note uses the Kubernetes `v1.31` repository:

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
```

### 6.2 Install Kubernetes Tools

```bash
sudo dnf install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

The kubelet may not become active until the node joins a Kubernetes cluster.

---

## 7. Configure HAProxy

HAProxy provides a stable Kubernetes API endpoint for control-plane and worker nodes.

### 7.1 Install and Enable HAProxy

Run on the HAProxy host, `192.168.37.10`:

```bash
sudo dnf install -y haproxy
sudo systemctl enable haproxy
```

### 7.2 HAProxy Configuration

Add the following configuration to `/etc/haproxy/haproxy.cfg` or merge it with the existing configuration:

```haproxy
# Frontend for Kubernetes API
frontend k8s-api
  bind *:6443
  mode tcp
  option tcplog
  default_backend K8s-ApiServer

# Backend for Kubernetes API
backend K8s-ApiServer
  mode tcp
  option tcplog
  option tcp-check
  balance roundrobin
  default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
  server k8s-api-1 192.168.37.13:6443 check
  server k8s-api-2 192.168.37.14:6443 check
```

Restart HAProxy after saving the configuration:

```bash
sudo systemctl restart haproxy
sudo systemctl status haproxy
```

### 7.3 Keepalived Note

For a highly available load-balancer endpoint, HAProxy is commonly deployed with Keepalived and a Virtual IP (VIP). The supplied note mentions Keepalived but does not include a Keepalived configuration. In the commands below, use `192.168.37.10` as the HAProxy endpoint exactly as supplied.

---

## 8. Approach A: Internet-Based Installation

Use this section when all nodes can reach public registries directly.

### 8.1 Pull Required Images

Run on Master 1, `192.168.37.13`:

```bash
sudo kubeadm config images pull
```

If you need to pull images manually:

```bash
sudo crictl pull registry.k8s.io/google_containers/etcd:3.5.16-0
sudo ctr image pull registry.k8s.io/google_containers/etcd:3.5.16-0
```

Verify the images:

```bash
sudo ctr -n k8s.io image ls | grep -E "(kube-|pause|coredns|etcd)"
```

> **If all servers do not have Internet access and you want to provide the required images through a registry, refer to [Approach B: Private Registry / Restricted-Network Installation](#9-approach-b-private-registry--restricted-network-installation).**

### 8.2 Initialize Master 1

Run on Master 1, `192.168.37.13`.

#### Standard initialization using the HAProxy endpoint

```bash
kubeadm init --control-plane-endpoint "<HA Proxy IP>:6443" --pod-network-cidr=10.244.0.0/16 --upload-certs
```

For this topology, use:

```text
192.168.37.10:6443
```

#### Alternative public-registry initialization 

```bash
kubeadm init \
  --control-plane-endpoint "<HA Proxy IP>:6443" \
  --kubernetes-version v1.34.1 \
  --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs
```

If HAProxy is not configured, you can use the IP address of the master itself:

```text
--control-plane-endpoint <IP of Master>:6443
```

### 8.3 Configure kubectl

Run as the user who will operate the cluster:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### Optional Bash Completion

```bash
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
alias k=kubectl
complete -o default -F __start_kubectl k
```

### 8.4 Install Flannel from the Internet

The cluster needs a CNI plugin before pod networking works correctly.

#### Pod network CIDR reference

| CNI plugin | Pod network CIDR |
|---|---|
| Flannel | `10.244.0.0/16` |
| Calico | `192.168.0.0/16` |
| Weave | `10.32.0.0/12` |
| Cilium | `10.0.0.0/8` or custom |

Always confirm the CIDR in the selected CNI documentation.

Apply Flannel:

```bash
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
```

### 8.5 Join Master 2 and Worker 1

At the end of `kubeadm init`, save the join commands printed by kubeadm.

#### Join Master 2 as a control-plane node

```bash
sudo kubeadm join <HaProxy_IP>:6443 \
  --token <token-from-master1> \
  --discovery-token-ca-cert-hash sha256:<hash-from-master1> \
  --control-plane \
  --certificate-key <cert-key-from-master1>
```

For this topology, `<HaProxy_IP>` is `192.168.37.10`.

#### Join Worker 1

```bash
sudo kubeadm join 192.168.37.10:6443 \
  --token <token-from-master1> \
  --discovery-token-ca-cert-hash sha256:<hash-from-master1>
```

---

## 9. Approach B: Private Registry / Restricted-Network Installation

Use this section when one or more cluster nodes do not have unrestricted Internet access and required images must be provided through:

```text
192.168.37.13:5000
```

### 9.1 Set Up the Private Registry

Run on Master 1 or the HAProxy host. The supplied topology places it on Master 1 at `192.168.37.13:5000`.

#### Basic registry container

```bash
docker run -d -p 5000:5000 --name registry --restart=always registry:2
```

#### Persistent registry storage

```bash
docker run -d -p 5000:5000 \
  --name registry \
  --restart=always \
  -v /var/lib/registry:/var/lib/registry \
  registry:2
```

### 9.2 Tag and Push Kubernetes Images

On a host with Internet access, pull the images first:

```bash
sudo kubeadm config images pull
```

Tag and Push images to registry:

```bash
for image in \
  registry.k8s.io/kube-apiserver:v1.34.1 \
  registry.k8s.io/kube-controller-manager:v1.34.1 \
  registry.k8s.io/kube-scheduler:v1.34.1 \
  registry.k8s.io/kube-proxy:v1.34.1 \
  registry.k8s.io/pause:3.10 \
  registry.k8s.io/coredns/coredns:v1.11.3 \
  registry.k8s.io/etcd:3.5.24-0; do

  # Tag the image for the local registry
  sudo ctr -n k8s.io image tag "$image" "<IP_Registry>:5000/${image#registry.k8s.io/}"

  # Push the image to the local registry
  sudo ctr -n k8s.io image push "<IP_Registry>:5000/${image#registry.k8s.io/}"
done
```

For this topology, replace `<IP_Registry>` with `192.168.37.13`.

### 9.3 Configure containerd to Use the Private Registry

Perform this section on **all Kubernetes nodes**.

#### Change the sandbox image

```bash
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.10.2"|sandbox_image = "192.168.37.13:5000/google_containers/pause:3.10"|' /etc/containerd/config.toml
```

#### Add the registry configuration

```bash
sudo sed -i '/\[plugins.'\''io.containerd.cri.v1.images'\''.registry\]/,/config_path/{
    /config_path/a\\
  [plugins.'\''io.containerd.cri.v1.images'\''.registry.mirrors]\
    [plugins.'\''io.containerd.cri.v1.images'\''.registry.mirrors."192.168.37.13:5000"]\
      endpoint = ["http://192.168.37.13:5000"]\
  [plugins.'\''io.containerd.cri.v1.images'\''.registry.configs]\
    [plugins.'\''io.containerd.cri.v1.images'\''.registry.configs."192.168.37.13:5000".tls]\
      insecure_skip_verify = true
}' /etc/containerd/config.toml
```

Restart containerd:

```bash
sudo systemctl restart containerd
```

Test the registry pull:

```bash
sudo crictl pull 192.168.37.13:5000/google_containers/pause:3.10
```

### 9.4 Initialize Master 1 Using the Private Registry

Run on Master 1, `192.168.37.13`:

```bash
sudo kubeadm init \
  --control-plane-endpoint "<HaProxy_IP>:6443" \
  --pod-network-cidr=10.244.0.0/16 \
  --image-repository <Registry_IP>:5000 \
  --upload-certs
```

For this topology:

```text
<HaProxy_IP>   = 192.168.37.10
<Registry_IP>  = 192.168.37.13
```

### 9.5 Join Master 2 and Worker 1

Use the commands generated by `kubeadm init`.

#### Join Master 2 as a control-plane node

```bash
sudo kubeadm join <HaProxy_IP>:6443 \
  --token <token-from-master1> \
  --discovery-token-ca-cert-hash sha256:<hash-from-master1> \
  --control-plane \
  --certificate-key <cert-key-from-master1>
```

#### Join Worker 1

```bash
sudo kubeadm join 192.168.37.10:6443 \
  --token <token-from-master1> \
  --discovery-token-ca-cert-hash sha256:<hash-from-master1>
```

The worker will automatically pull images from the private registry when the registry configuration is applied correctly.

### 9.6 Install Flannel from the Private Registry

#### Pull Flannel images on Master 1

```bash
# Pull the Flannel daemon image
docker pull ghcr.io/flannel-io/flannel:v0.28.9

# Pull the Flannel CNI plugin image
docker pull ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel3

# Tag both images for the private registry
docker tag ghcr.io/flannel-io/flannel:v0.28.9 \
  192.168.37.13:5000/flannel/flannel:v0.28.9

docker tag ghcr.io/flannel-io/flannel-cni-plugin:v1.9.1-flannel3 \
  192.168.37.13:5000/flannel/flannel-cni-plugin:v1.9.1-flannel3

# Push both images to the private registry
docker push 192.168.37.13:5000/flannel/flannel:v0.28.9
docker push 192.168.37.13:5000/flannel/flannel-cni-plugin:v1.9.1-flannel3
```

#### Download and modify the Flannel manifest

```bash
wget -q -O kube-flannel.yml \
  https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

sed -i 's|docker.io/flannel/|192.168.37.13:5000/flannel/|g' kube-flannel.yml
sed -i 's|ghcr.io/flannel-io/|192.168.37.13:5000/flannel/|g' kube-flannel.yml
```

- Optional: If using a specific network CIDR (default is 10.244.0.0/16 which matches your kubeadm init)
- - You can also modify the network if needed:

```bash
sed -i 's|10.244.0.0/16|10.244.0.0/16|g' kube-flannel.yml
```

Apply the manifest:

```bash
kubectl apply -f kube-flannel.yml
```

---

## 10. Verification

Run these commands from a node configured with the Kubernetes administrator kubeconfig.

### 10.1 Check Nodes

```bash
kubectl get nodes -o wide
```

### 10.2 Check All Pods

```bash
kubectl get pods --all-namespaces
kubectl get pods -n kube-flannel -o wide
kubectl get pods -n kube-system
```

### 10.3 Check Cluster Information

```bash
kubectl cluster-info
```

### 10.4 Check the Private Registry

```bash
curl -s http://192.168.37.13:5000/v2/flannel/flannel/tags/list | python3 -m json.tool
```

### 10.5 Check HAProxy Backend Reachability

From the HAProxy host, verify that both API-server backends accept connections:

```bash
nc -zv 192.168.37.13 6443
nc -zv 192.168.37.14 6443
```

---

## 11. Configuration Checklist

- [ ] All nodes use unique hostnames.
- [ ] All nodes have correct `/etc/hosts` entries.
- [ ] Swap is disabled.
- [ ] `overlay` and `br_netfilter` are loaded.
- [ ] IPv4 forwarding and bridge netfilter sysctl values are enabled.
- [ ] containerd uses the systemd cgroup driver.
- [ ] kubeadm, kubelet, and kubectl are installed on all nodes.
- [ ] HAProxy listens on `192.168.37.10:6443`.
- [ ] HAProxy can reach both control-plane API servers.
- [ ] The private registry is reachable at `192.168.37.13:5000` when using Approach B.
- [ ] The image versions used by kubeadm match the images in the private registry.
- [ ] Master 2 joined with `--control-plane` and `--certificate-key`.
- [ ] Worker 1 joined through the HAProxy endpoint.
- [ ] The selected CNI is installed with a matching pod CIDR.
- [ ] All nodes report `Ready`.
