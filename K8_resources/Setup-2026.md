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

    sudo firewall-cmd --permanent --add-port=2379/tcp
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

### Set up Kubernetes repsotoitory
```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.35/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.35/rpm/repodata/repomd.xml.key
EOF

```

```bash
#sudo dnf install kubernetes-kubeadm kubernetes-client kubelet
 sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet
```


# Cluster Initialization with Kubeadm 
On the master node only, initialize the cluster. Cilium generally does not require a specific --pod-network-cidr unless you have specific IPAM requirements. 



```bash
# sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# # sudo dnf install -y containerd
# sudo dnf install -y containerd.io

# CRI-O 1.35.2
export KUBERNETES_VERSION=v1.35
export CRIO_VERSION=v1.35

# Add CRI-O Repository
cat <<EOF | sudo tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF

sudo dnf install -y cri-o
sudo systemctl daemon-reload
sudo systemctl enable --now crio

sudo kubeadm init --skip-phases=addon/kube-proxy --cri-socket=/var/run/crio/crio.sock

CONTROL_PLANE_IP="192.168.122.113"


cilium install \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=<CONTROL_PLANE_IP> \
  --set k8sServicePort=6443


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
sudo dnf install -y tar
sudo tar -C /usr/local/bin -xzvf cilium-linux-amd64.tar.gz

# remove compressed file
rm cilium-linux-amd64.tar.gz{,.sha256sum}


sudo firewall-cmd --add-port=4244/tcp --permanent

cilium install \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.122.133 \
  --set k8sServicePort=6443

```

## Install Cilium into the Cluster 
Cilium auto-detects kubeadm setups. Execute the installation: 
Kubernetes
```bash
#cilium install

#or

#cilium upgrade --set cni.binPath=/usr/libexec/cni

# Then Check it works 
kubectl get pods -n kube-system -l k8s-app=cilium -w

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

on K8 server
```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80 --address 0.0.0.0
```

On client Laptop (New Terminal):
Create a tunnel from the client laptop to the server. 
Replace paul@k8-cp-00.gardenofrot.cc with your actual SSH login:
```bash
ssh -L 12000:localhost:12000 paul@k8-cp-00.gardenofrot.cc

```

# Fix Cillium Setup

## The Node Bootstrap Script (setup-nodes.sh)

This script prepares the OS on every node before or during the Kubernetes join process.

```bash
#!/bin/bash
# Rocky 10 Runtime & Security Setup

# 1. Ensure binaries exist at the expected paths
# On Rocky 10, these are often provided by the crio-packages
sudo dnf install runc crun conmon -y

# 2. Configure CRI-O for Rocky 10 + systemd 257 compatibility
sudo mkdir -p /etc/crio/crio.conf.d/
cat <<EOF | sudo tee /etc/crio/crio.conf.d/10-runc.conf
[crio.runtime]
default_runtime = "runc"
conmon = "/usr/libexec/crio/conmon"
device_ownership_from_security_context = false

[crio.runtime.runtimes.runc]
runtime_path = "/usr/libexec/crio/runc"
runtime_type = "oci"

[crio.runtime.runtimes.crun]
runtime_path = "/usr/libexec/crio/crun"
runtime_type = "oci"
EOF

# 3. Disable SELinux (Required for runc execution on Rocky 10)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 4. Open Firewall for Cilium VXLAN & Gateway API
sudo firewall-cmd --permanent --add-port=8472/udp
sudo firewall-cmd --permanent --add-port=4240/tcp
sudo firewall-cmd --permanent --add-port=4244/tcp
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# 5. Apply changes
sudo systemctl daemon-reload
sudo systemctl restart crio
```

## Git Repository: cluster-init/

Save these files in your repository to recreate the network state.01-gateway-api.yamlbash# Apply standard Gateway API CRDs first
```bash
kubectl apply -f https://github.com
```

02-cilium-config.yaml (Helm Values)yaml

```yaml
# Used with: helm upgrade --install cilium cilium/cilium -f 02-cilium-config.yaml
kubeProxyReplacement: true
l2announcements:
  enabled: true
gatewayAPI:
  enabled: true
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
devices: "enp1s0"
```

03-network-infrastructure.yaml
```yaml
apiVersion: "cilium.io/v2"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "local-pool"
spec:
  blocks:
    - cidr: "192.168.122.200/29"
---
apiVersion: "cilium.io/v2"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: "default-l2-policy"
spec:
  interfaces:
    - ^enp1s0$
  externalIPs: true
  loadBalancerIPs: true
```

04-gateway-and-routes.yaml

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
---
# Application Route
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: cilium-test-1
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  rules:
  - matches:
    - path: { type: PathPrefix, value: / }
    backendRefs:
    - name: echo-same-node
      port: 8080
---
# Hubble UI Route (Hostname Based)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hubble-ui-route
  namespace: kube-system
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  hostnames:
  - "hubble.gardenofrot.cc"
  rules:
  - matches:
    - path: { type: PathPrefix, value: / }
    backendRefs:
    - name: hubble-ui
      port: 80

```
## Re-Creation Command Sequence

To rebuild the cluster network from scratch:
 1. Run setup-nodes.sh on all nodes.
 1. kubectl apply -f cluster-init/01-gateway-api.yaml
 1. helm install cilium cilium/cilium -n kube-system -f cluster-init/02-cilium-config.yaml
 1. kubectl apply -f cluster-init/03-network-infrastructure.yaml
 1. kubectl apply -f cluster-init/04-gateway-and-routes.yaml
 

 To use the Hubble UI from your laptop after re-deploying:
 
 Update Local Hosts: On your laptop (not the nodes), add the mapping:
 ```bash
 echo "192.168.122.200 hubble.local" | sudo tee -a /etc/hosts
```
Access the UI: Navigate to http://hubble.gardenofrot.cc in the browser.
Access the App: Navigate to http://192.168.122.200 (which matches the app-route above as it has no hostname restriction).
 

 # Setup Kubernetes Dashboard Headlamp

The easiest way to install Headlamp is via Helm. Create a dedicated namespace (e.g., headlamp) and deploy it there.

```bash
# Add the Headlamp repo
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update

# Install into a dedicated 'headlamp' namespace
helm upgrade --install headlamp headlamp/headlamp \
  --namespace headlamp \
  --create-namespace

kubectl create token headlamp-admin -n headlamp
  ```

## Install Grafana-style Metrics (Prometheus Stack)

To get the deep infrastructure metrics you see in Grafana, you should install the kube-prometheus-stack. This provides the Prometheus server that Headlamp "plugs into" to show those visual charts.

```bash
# Add the Prometheus community repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install the stack into a 'monitoring' namespace
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
  ```

## Link Headlamp to PrometheusOnce 
Prometheus is running, Headlamp can automatically detect it or be manually configured to show pod/node metrics.
 - **Automatic Detection**: Headlamp often auto-detects Prometheus if it's in the cluster.
 - Manual Config: In Headlamp Settings > Plugins > Prometheus, enter the service address. For the stack above, it is usually: monitoring/prometheus-kube-prometheus-prometheus:9090.
 
 ## Expose Headlamp via Gateway API
 Since you have the Cilium Gateway API working, you can expose Headlamp on a dedicated hostname (e.g., dashboard.local).
 ```yaml
 # headlamp-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: headlamp-route
  namespace: headlamp
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  hostnames:
  - "dashboard.local"
  rules:
  - matches:
    - path: { type: PathPrefix, value: / }
    backendRefs:
    - name: headlamp
      port: 80
```

Apply with: 
```bash 
kubectl apply -f headlamp-route.yaml
```

## Accessing the Dashboard
 1. Update Hosts: On your laptop, add 192.168.122.200 dashboard.local to your /etc/hosts.
 1. Generate Token: Headlamp requires a service account token to log in.
 ```bash
kubectl create serviceaccount headlamp-admin -n headlamp
kubectl create clusterrolebinding headlamp-admin --serviceaccount=headlamp:headlamp-admin --clusterrole=cluster-admin
kubectl create token headlamp-admin -n headlamp
```
Login: Paste the generated token into the UI at http://dashboard.gardenofrot.cc


# Expose Grafana via the Cilium Gateway API at grafana.gardenofrot.cc

Create an HTTPRoute in the monitoring namespace that points to the Grafana service created by the Helm chart.

## Identify the Grafana Service
First, confirm the exact name of the Grafana service in your monitoring namespace:
```bash
kubectl get svc -n monitoring | grep grafana

# prometheus-grafana

```

## Create the HTTPRoute
Create a file named grafana-route.yaml and apply it. This configuration links your existing Cilium Gateway to the Grafana service using your specific domain.
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: monitoring
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  hostnames:
  - "grafana.gardenofrot.cc"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: prometheus-grafana  # Use the service name from step 1
      port: 80
```

Apply it: 
```bash
kubectl apply -f grafana-route.yaml
```

## Update Your DNS or Hosts File
Since this is a headless/local environment, you must map the domain to your Gateway IP (192.168.122.200) on the machine where you are browsing.On your laptop:
```bash
echo "192.168.122.200 grafana.gardenofrot.cc" | sudo tee -a /etc/hosts
```
## 4. Retrieve Admin Credentials
As noted in your Helm installation output, you will need the admin password to log in once you reach http://grafana.gardenofrot.cc :
```bash
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
The default username is admin.

# Ensure SELinux is in enforcing mode

Creating the Configuration FileUse the following command to create the directory (if it doesn't exist) and the file with the necessary content:
```bash
sudo mkdir -p /etc/modules-load.d/
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```
After creating the file, load the modules into the current session so you don't have to reboot:
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

# Create Persistent Storage
Persistent storage in Kubernetes is best handled by implementing Dynamic Provisioning using StorageClasses. This eliminates the need to manually create individual disks for every application, allowing Kubernetes to automatically request and create storage as needed.

Need a software-defined storage layer to bridge your physical disks to Kubernetes.


## Longhorn (Recommended for Homelabs)

Turns the existing free space on your nodes into a distributed block store.Configuration 
Steps:
 - Install Prerequisites: On every node, install the iSCSI initiator and NFS client (for ReadWriteMany volumes).
```bash
#sudo dnf install -y iscsi-initiator-utils nfs-utils cryptsetup
sudo dnf install -y iscsi-initiator-utils nfs-utils device-mapper cryptsetup


```
Configure iSCSI Initiator:Generate a unique initiator name if one doesn't exist, then start the service.
```bash
# echo "InitiatorName=$(/sbin/iscsi-iname)" | sudo tee /etc/iscsi/initiatorname.iscsi
# sudo systemctl enable --now iscsid

# Generate a unique initiator name if not present
if [ ! -f /etc/iscsi/initiatorname.iscsi ]; then
  echo "InitiatorName=$(/sbin/iscsi-iname)" | sudo tee /etc/iscsi/initiatorname.iscsi
fi

sudo systemctl enable --now iscsid


```
Check Microarchitecture:Ensure your hardware/VM supports x86-64-v3, as Rocky 10 has dropped support for older v2 CPUs.
```bash
# Should return 'v3' or 'v4'
/lib64/ld-linux-x86-64.so.2 --help | grep supported
#   x86-64-v3 (supported, searched)
#   x86-64-v2 (supported, searched)
```


Deploy Longhorn via HelmThe cleanest way to install Longhorn is using its Official Helm Chart.
```bash

helm repo add longhorn https://charts.longhorn.io
helm repo update

# Install with Gateway API (HTTPRoute) enabled
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set httproute.enabled=true \
  --set "httproute.hostnames[0]=longhorn.gardenofrot.cc" \
  --set "httproute.parentRefs[0].name=my-gateway" \
  --set "httproute.parentRefs[0].namespace=longhorn-system"



# Add the repo
#helm repo add longhorn https://charts.longhorn.io
#helm repo update

# Install into the required longhorn-system namespace
#helm install longhorn longhorn/longhorn \
#  --namespace longhorn-system \
#  --create-namespace
```

### Or cleanuip and retry

```bash

kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag --type=merge -p '{"value": "true"}'

# Remove the crashing job so it can be recreated
kubectl -n longhorn-system delete job longhorn-uninstall

# Now try the helm uninstall again
helm uninstall longhorn -n longhorn-system

```

```bash
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set httproute.enabled=true \
  --set "httproute.hostnames[0]=longhorn.gardenofrot.cc" \
  --set "httproute.parentRefs[0].name=my-gateway" \
  --set "httproute.parentRefs[0].namespace=longhorn-system"
```

## Access UI via Cilium Gateway API
To use the Cilium Gateway API, first need a Gateway resource defined in your cluster, followed by an HTTPRoute to point to the Longhorn service.

A. Create the Gateway (Entry Point)This defines where Cilium listens (e.g., Port 80).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: longhorn-system
spec:
  gatewayClassName: cilium # Requires Cilium Gateway API to be enabled
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
```

# KASM install

```bash
helm uninstall kasm --namespace kasam-gardenofrot-cc
kubectl get pods -n kasam-gardenofrot-cc
 
# ensure all resources are deleted
```

```bash

# Create a dedicated namespace
kubectl create namespace kasm

# Optional: Create a dummy TLS secret if not using cert-manager
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=kasm.gardenofrot.cc"
kubectl create secret tls kasm-tls-cert -n kasm --cert=tls.crt --key=tls.key

```

## Deploy Kasm Workspaces
The Official Kasm Helm Chart is the recommended method. Need to clone the repository as the chart is currently in technical preview and best managed via the source files.
```bash
# Clone the repository
git clone https://github.com/kasmtech/kasm-helm
cd kasm-helm

# Install using your specific storage and domain
helm upgrade --install kasm ./charts/kasm \
  --namespace kasm \
  --set global.hostname="kasm.gardenofrot.cc" \
  --set postgresql.persistence.storageClass="longhorn" \
  --set certificate.secretName="kasm-tls-cert"

  ```

  Check Services:
```bash
kubectl get svc -n kasm


kubectl annotate service kasm-proxy-default -n kasm \
  service.cilium.io/backend-protocol=https --overwrite

```
File Name: kasm-route.yaml
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kasm-route
  namespace: kasm
spec:
  parentRefs:
  - name: my-gateway
    namespace: longhorn-system
  hostnames:
  - "kasm.gardenofrot.cc"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kasm-proxy-default
      port: 8443
```

```bash
kubectl annotate service kasm-proxy-default -n kasm \
  service.cilium.io/backend-protocol=https --overwrite
```
longhorn_gatway.yaml
```bash
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: longhorn-system
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "kasm.gardenofrot.cc"
    tls:
      mode: Terminate
      certificateRefs:
      - name: kasm-tls-cert # Ensure this secret exists in the longhorn-system namespace
    allowedRoutes:
      namespaces:
        from: All

```

### Move the TLS Secret (Important)

Cilium Gateway API requires the TLS secret to be in the same namespace as the Gateway. If you created kasm-tls-cert in the kasm namespace, the Gateway in longhorn-system cannot see it.Run this to copy the secret:
```bash
kubectl get secret kasm-tls-cert -n kasm -o yaml | \
sed 's/namespace: kasm/namespace: longhorn-system/' | \
kubectl apply -f -
```
Ensure the Service Annotation is still there

Even with the Gateway fixed, it still needs to know the "backend" (Kasm) requires HTTPS.
```bash
kubectl annotate service kasm-proxy-default -n kasm \
  service.cilium.io/backend-protocol=https --overwrite

  # Variation 1 (Newer Cilium)
kubectl annotate service kasm-proxy-default -n kasm \
  service.cilium.io/backend-protocol=https --overwrite

# Variation 2 (Standard Cilium)
kubectl annotate service kasm-proxy-default -n kasm \
  io.cilium/backend-protocol=https --overwrite

# Restart Cilium
kubectl rollout restart deployment cilium-operator -n kube-system
kubectl rollout restart ds cilium -n kube-system

```
```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set gatewayAPI.enableAppProtocol=true

 kubectl patch svc kasm-proxy-default -n kasm -p '{"spec":{"ports":[{"name":"proxy-https","port":8443,"targetPort":8443,"appProtocol":"https"}]}}'

```

kasm-tls-backend.yaml

```yaml
apiVersion: cilium.io/v2
kind: CiliumEnvoyConfig
metadata:
  name: kasm-backend-tls
  namespace: kasm
spec:
  services:
    - name: kasm-proxy-default
      namespace: kasm
      ports: [8443]
  backendSettings:
    - title: "force-tls-kasm"
      ports: [8443]
      l7:
        tls:
          untrusted: true # Trusts Kasm's internal self-signed cert
```

```bash
kubectl apply -f kasm-tls-backend.yaml
```

Update kasm-route.yaml with this content:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kasm-route
  namespace: kasm
spec:
  parentRefs:
  - name: my-gateway
    namespace: longhorn-system
  hostnames:
  - "kasm.gardenofrot.cc"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kasm-proxy-default
      port: 8080  # Changed from 8443 to 8080

```
```bash
kubectl apply -f kasm-route.yaml
kubectl annotate service kasm-proxy-default -n kasm service.cilium.io/backend-protocol-
kubectl annotate service kasm-proxy-default -n kasm io.cilium/backend-protocol-
```

Verify it.

Get your Admin credentials:


get KASM Secret:
```bash
kubectl get secret --namespace kasm kasm-secrets -o jsonpath="{.data.admin-password}" | base64 -d

```
(Username is admin@kasm.local).
Log in to the UI.Navigate to Admin -> Infrastructure -> Zones.

Click the Edit (pencil) icon on the Default zone.Update the Upstream Auth Address to: kasm.gardenofrot.cc.Set Proxy Port to 0 (this tells Kasm to use the port from your browser's URL).Click Save.

## How to add your first Server/Agent
To start running sessions, you need to install the Kasm Agent on a separate Linux machine (or a VM outside the cluster) and point it back to your Kubernetes control plane.Retrieve your Manager Token:You need this token so the new agent can "introduce" itself to your Kubernetes control plane. Run this on your Kubernetes master:
```bash
kubectl get secret --namespace kasm kasm-secrets -o jsonpath="{.data.manager-token}" | base64 -d

```
Install the Agent on a separate Linux VM:SSH into a fresh Linux VM (Ubuntu/Rocky) and run the Kasm installation script with the agent role:
```bash

cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz
tar -xf kasm_release_1.17.0.7f020d.tar.gz

sudo bash kasm_release/install.sh --role agent --public-hostname kasm.gardenofrot.cc --token [YOUR_MANAGER_TOKEN]
```
Verify in the UI:
Once the installation finishes, go back to Admin -> Infrastructure -> Servers. You should now see your new VM listed as a "Running" server.

Next Steps: Enable your Workspaces

Once the server appears, navigate to Workspaces -> Registry and install an image (like Ubuntu Desktop or Brave Browser). The images will automatically download to your new external Agent, and you'll be able to launch them from your dashboard.Do you have a spare VM or physical machine available to use as a Kasm Agent?

Install Docker first

```bash
# Remove the incorrect repo entry
sudo rm -f /etc/yum.repos.d/docker.com.repo

# Add the official RHEL repository (compatible with Rocky 10)
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Install the Docker engine and Compose plugin
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Update your system and install extra kernel modules
sudo dnf update -y
sudo dnf install -y kernel-modules-extra

# Load the required networking module
sudo modprobe xt_addrtype

# Now start and enable Docker
sudo systemctl enable --now docker

# verify
sudo docker ps

# Open ports for direct container access
sudo firewall-cmd --permanent --add-port=6901/tcp  # KasmVNC (Web Desktop)
sudo firewall-cmd --permanent --add-port=3389/tcp  # RDP
sudo firewall-cmd --permanent --add-port=5900/tcp  # Standard VNC
sudo firewall-cmd --permanent --add-port=22/tcp    # SSH (Already open by default usually)

sudo firewall-cmd --reload


sudo bash kasm_release/install.sh \
  --role agent \
  --public-hostname kasam-agent \
  --manager-hostname kasm.gardenofrot.cc \
  --manager-token <YOUR_TOKEN_HERE>

```


```bash
sudo bash kasm_release/install.sh   --role agent   --public-hostname kasam-agent   --manager-hostname kasm.gardenofrot.cc   --manager-token [YOUR_MANAGER_TOKEN]
```bash