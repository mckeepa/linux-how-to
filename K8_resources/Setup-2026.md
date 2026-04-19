# Kubernetes Setup (kukeadm with cilium)

## Provision Fedora VMs in Proxmox
Create at least two VMs (e.g., Fedora Server 39/40/41) with the following minimum specs: 
 - Resources: 2 CPUs and 4GB RAM for the control plane; 1-2 CPUs and 2-4GB RAM for worker nodes.
 - Networking: Assign static IPs via Proxmox Cloud-Init settings or DHCP reservations.
 - Hardware: Ensure QEMU Guest Agent is enabled in the VM Options for better integration. 

## Prepare All Fedora Nodes
Fedora uses zram by default, which must be disabled for Kubernetes stability. 

Set host name
```bash
sudo hostnamectl set-hostname --pretty "k8-cp-00"
sudo hostnamectl set-hostname --static k8-cp-00
```

Disable Swap & zram:

```bash
sudo swapoff -a
sudo systemctl stop swap-create@zram0
sudo dnf remove zram-generator-defaults -y
# Permanently disable in fstab if a physical swap partition exists
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Fedora 43 System Prerequisites

Run these commands on all nodes (master and workers) to prepare the OS for Kubernetes. 
Update System: Use dnf to ensure all packages are current.
Disable Swap: Kubernetes requires swap to be disabled. Modern Fedora uses zram.

```bash
sudo systemctl stop swap-create@zram0
sudo dnf remove zram-generator-defaults
```

Configure Networking: Load necessary modules and set sysctl parameters.
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

# Persist settings

```bash
sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
```

SELinux & Firewall: Most guides recommend setting SELinux to permissive and disabling firewalld to avoid connectivity issues during setup. 

```bash
#!/bin/bash

# Detect if the node is a Control Plane or Worker node
echo "Choose node type: 1) Control Plane  2) Worker Node"
read -p "Selection: " NODE_TYPE

if [ "$NODE_TYPE" == "1" ]; then
    echo "Configuring Control Plane ports..."
    # API Server
    sudo firewall-cmd --permanent --add-port=6443/tcp
    # etcd
    sudo firewall-cmd --permanent --add-port=2379-2380/tcp
    # Kubelet, Scheduler, Controller Manager
    sudo firewall-cmd --permanent --add-port=10250/tcp
    sudo firewall-cmd --permanent --add-port=10259/tcp
    sudo firewall-cmd --permanent --add-port=10257/tcp
elif [ "$NODE_TYPE" == "2" ]; then
    echo "Configuring Worker Node ports..."
    # Kubelet API
    sudo firewall-cmd --permanent --add-port=10250/tcp
    # NodePort Services
    sudo firewall-cmd --permanent --add-port=30000-32767/tcp
    sudo firewall-cmd --permanent --add-port=30000-32767/udp
else
    echo "Invalid selection. Exiting."
    exit 1
fi

# Apply changes
sudo firewall-cmd --reload
echo "Firewall rules updated and reloaded."
````


## Install Container Runtime and KubeTools 
Container Runtime: Install containerd or cri-o. For containerd, ensure the SystemdCgroup is set to true in its configuration.
Kubernetes Packages: Install kubelet, kubeadm, and kubectl using Fedora versioned repositories if available.
```bash
sudo dnf install kubernetes-kubeadm kubernetes-client kubelet
sudo systemctl enable --now kubelet
```


# Cluster Initialization with Kubeadm 
On the master node only, initialize the cluster. Cilium generally does not require a specific --pod-network-cidr unless you have specific IPAM requirements. 



```bash
sudo dnf install -y containerd

```

```bash 
# Open Kubernetes API server port
sudo firewall-cmd --permanent --add-port=6443/tcp

# Open etcd server ports
sudo firewall-cmd --permanent --add-port=2379-2380/tcp

# Open Kubelet and control plane component ports
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10259/tcp
sudo firewall-cmd --permanent --add-port=10257/tcp

# Reload to apply changes
sudo firewall-cmd --reload

```



```bash
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/manifests/
sudo rm -rf /etc/kubernetes/pki/
sudo rm -f /etc/kubernetes/admin.conf
sudo rm -f /etc/kubernetes/kubelet.conf
sudo rm -f /etc/kubernetes/controller-manager.conf
sudo rm -f /etc/kubernetes/scheduler.conf


# Clear the etcd database:
# This resolves the [ERROR DirAvailable--var-lib-etcd] error.
sudo rm -rf /var/lib/etcd


# clean cni
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /etc/cni/net.d/

#Check for processes on K8s ports:
sudo ss -tulpn | grep -E '6443|10250|2379|2380'

sudo systemctl restart containerd
```

```bash
sudo kubeadm init --skip-phases=addon/kube-proxy

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml


sudo systemctl status containerd

# ---------------
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml


sudo systemctl restart containerd
sudo systemctl enable containerd

sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock version

sudo kubeadm init --skip-phases=addon/kube-proxy --cri-socket unix:///var/run/containerd/containerd.sock


```

Note: Skipping kube-proxy is recommended if you plan to use Cilium's "Kube-Proxy Replacement" mode for better performance. 

# Install Cilium CNI 
After initialization, configure your local kubectl and install Cilium using the Cilium CLI. 
Cilium Docs

Install Cilium CLI:
```bash
curl -LO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
```
## Deploy Cilium:
```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
cilium install
```
Verify: Use cilium status to confirm the network is healthy. 

--------

1. Install the Cilium CLI 
Run these commands on your control-plane node to download and install the latest CLI binary:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}

# verify download
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum

# decommpress
sudo tar -C /usr/local/bin -xzvf cilium-linux-amd64.tar.gz

# remove compressed file
rm cilium-linux-amd64.tar.gz{,.sha256sum}
```

## Install Cilium into the Cluster 
Cilium auto-detects kubeadm setups. Execute the installation: 
Kubernetes
```bash
cilium install
```
Optional (Kube-proxy Replacement): For higher performance, you can replace kube-proxy entirely using eBPF:
```bash
cilium install --set kubeProxyReplacement=true
```


Validate the Installation
Wait for deployment, then check status: 

```bash
cilium status --wait
```

If you have multiple nodes, verify with connectivity tests: 

```bash
cilium connectivity test
```

## Enable Observability (Hubble) 
Enable Hubble for network visibility: 

```bash
cilium hubble enable --ui
cilium hubble ui
```