These are my notes on an intallation and troble shhoting on a KubeAdm Install on Fedora release 35 (Thirty Five).




# Pre-Install Steps
There are a couple of pre-checks to do.

## Webpage for issues:


### Set hostname

```bash
sudo hostnamectl set-hostname kube-controlplane-00.k8
sudo hostnamectl set-hostname kube-wokernode-00.k8
sudo hostnamectl set-hostname kube-wokernode-01.k8
```


## Setup Static IP Address
I discovered that when the IP Address changes the Kubernates Cluster fails, so we'll need to set a staic IP Address.

```bash
$ nmcli dev status
$ ifconfig enp0s31f6 
# $ sudo nmcli connection modify id 'enp0s31f6'  Pv4.address 192.168.1.201/24
# example 2
$ sudo nmcli connection modify id 'enp0s31f6'  ipv4.address 192.168.122.128/24
or
$ sudo nmcli connection modify 908db235-c1e0-39c5-875e-1ee974c577ad IPv4.address 192.168.1.201/24
```

## Set the Default DNS 
```bash

$ ifconfig enp0s31f6 
$ sudo nmcli connection modify 'Wired connection 1' IPv4.dns 8.8.8.8
$ sudo nmcli connection modify 'Wired connection 1' IPv4.method manual
$ sudo nmcli connection down 'Wired connection 1'
$ sudo nmcli connection up 'Wired connection 1'
$ route -n
```

## Allow SSH
Check openssh-server is installed
```bash

$ rpm -qa | grep openssh-server
openssh-server-8.7p1-3.fc35.x86_64
```bash

### Check the status

```bash

$ sudo systemctl status sshd
```

### Enable and start:
```bash

sudo systemctl enable sshd
sudo systemctl start sshd
```

### Check the status
```bash
$ sudo systemctl status sshd
```

### Ensure the iptables can see the bridged traffic 
```bash

$ lsmod | grep br_netfilter
br_netfilter           32768  0
bridge                331776  1 br_netfilter
```
**Or load the filter** 
```bash
sudo modprobe br_netfilter
```

If br_netfilter is not set correctly 

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

### Check the Ports are open 

Check Firewall state
```bash
 sudo systemctl stop firewalld
 sudo firewall-cmd --state
```

```bash
$ firewall-cmd --list-all
FedoraWorkstation (active)
  target: default
  icmp-block-inversion: no
  interfaces: enp0s31f6 wlp5s0
  sources: 
  services: dhcpv6-client mdns samba-client ssh vnc-server
  ports: 1025-65535/udp 1025-65535/tcp
  protocols: 
  forward: no
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

From here: https://kubernetes.io/docs/reference/ports-and-protocols/

```bash
# Control Plane
sudo firewall-cmd --add-port=6443/tcp
sudo firewall-cmd --add-port=2379-2380/tcp
sudo firewall-cmd --add-port=10250/tcp
sudo firewall-cmd --add-port=10259/tcp
sudo firewall-cmd --add-port=10257/tcp
# Worker Nodes
sudo firewall-cmd --add-port=10250/tcp
sudo firewall-cmd --add-port=30000-32767/tcp
```

## Ensure Runtime is installed CRI-O

```bash

sudo yum install -y \
  containers-common \
  device-mapper-devel \
  git \
  glib2-devel \
  glibc-devel \
  glibc-static \
  go \
  gpgme-devel \
  libassuan-devel \
  libgpg-error-devel \
  libseccomp-devel \
  libselinux-devel \
  pkgconfig \
  make \
  runc
```


### Create the .conf file to load the modules at bootup
```bash
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF
```
```bash
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```
https://jhooq.com/amp/kubernetes-error-execution-phase-preflight-preflight/#error-file-content-proc-sys-net


```bash
sudo sysctl --system
# List the instance of CRI-O in the package repository 
dnf module list cri-o
Fedora 35 - x86_64 - Updates                                                                                                                                                5.7 kB/s | 4.2 kB     00:00    
Fedora 35 - x86_64 - Updates                                                                                                                                                1.3 MB/s | 2.9 MB     00:02    
Fedora Modular 35 - x86_64 - Updates                                                                                                                                        4.7 kB/s | 3.4 kB     00:00    
Last metadata expiration check: 0:00:01 ago on Mon 31 Jan 2022 21:31:41.
Fedora Modular 35 - x86_64
Name                               Stream                              Profiles                                 Summary                                                                                     
cri-o                              1.19                                default [d]                              Kubernetes Container Runtime Interface for OCI-based containers                             

Fedora Modular 35 - x86_64 - Updates
Name                               Stream                              Profiles                                 Summary                                                                                     
cri-o                              1.19                                default [d]                              Kubernetes Container Runtime Interface for OCI-based containers                             
cri-o                              1.20                                default [d]                              Kubernetes Container Runtime Interface for OCI-based containers                             
cri-o                              1.21                                default [d]                              Kubernetes Container Runtime Interface for OCI-based containers                             
cri-o                              1.22                                default [d]                              Kubernetes Container Runtime Interface for OCI-based containers                             
```

```bash
export VERSION=1.25
sudo dnf module enable cri-o:$VERSION
sudo dnf module enable cri-o:$VERSION
sudo dnf install cri-o

sudo systemctl daemon-reload
sudo systemctl enable crio
sudo systemctl start crio
```

crictl versioncd de    
### Add Repositories
```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
```


## Disbale swaps
Itentify the Swaps enabled
```bash

cat /proc/swaps

free -h

sudo swapoff -a 
     swapon -s

blkid
```

Results: 
```bash

/dev/zram0: LABEL="zram0" UUID="76c9891d-6aa4-4e17-8e2d-7745d1234cf9" TYPE="swap"

```


 ### Permanently disable swap:
```bash

swapoff /dev/zram0; zramctl --reset /dev/zram0
```

### Still not staying turnmed off.... so trying this.
```bash

sudo dnf remove zram-generator-defaults
sudo reboot
```

## Install docker 
Docker is needed to pull the images from the repositories. 



### Install KubeAdmin
```bash

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet
```



### Pull Images before install
Option command, to save some time when the actual install is occuring:
```bash

kubeadm config images pull
```
or 
```bash

kubeadm config images pull --cri-socket=/var/run/crio/crio.sock 
```

### Install Callico - Network manager
https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/crio/crio.sock 
```

I got an error:
```
[ERROR Port-10259]: Port 10259 is in use
```

I used netstat to find the process:

```bash
netstat -ltnp | grep -w ':10259'
```

Then removed the application using it, then re-ran the Init
```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/crio/crio.sock 
```

Did not start "again", with this error:
```bash

[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.

```

Error said to try this to trouble shot:
```bash

# journalctl -xeu kubelet
```

Output:
```bash
..
Jan 29 20:22:09 fedora kubelet[332005]: W0129 20:22:09.352987  332005 manager.go:159] Cannot detect current cgroup on cgroup v2
Jan 29 20:22:09 fedora kubelet[332005]: I0129 20:22:09.353102  332005 dynamic_cafile_content.go:156] "Starting controller" name="client-ca-bundle::/etc/kubernetes/pki/ca.crt"
Jan 29 20:22:09 fedora kubelet[332005]: I0129 20:22:09.399943  332005 server.go:693] "--cgroups-per-qos enabled, but --cgroup-root was not specified.  defaulting to /"
Jan 29 20:22:09 fedora kubelet[332005]: E0129 20:22:09.400023  332005 server.go:302] "Failed to run kubelet" err="failed to run Kubelet: running with swap on is not supported, please disable swap! or set --fail-swap-on f>
Jan 29 20:22:09 fedora systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE

...
```


Running  "kubeadm init ..." 

Now I get :
```
[ERROR FileAvailable--etc-kubernetes-manifests-kube-apiserver.yaml]: /etc/kubernetes/manifests/kube-apiserver.yaml already exists
```

**Back to basics... remove and re-install.**
```bash
 yum remove -y kubelet kubeadm kubectl
rm -R /etc/kubernetes/
```

or 
```bash
rm -f  /etc/kubernetes/manifests/*
```
or 



run **--kubeadm reset--** first to undo all of the changes from the first time you ran it.
Then run **--systemctl restart kubelet--**
Finally, when you run kubeadm init you should no longer get the error.



```bash
#I already had a Docker instance running :
docker -ps -a 
```

This showed multiple containers running.  :(

### Started ini again
```bash

kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/dockershim.sock
```


### Your Kubernetes control-plane has initialized successfully!

```bash
...
Coredn in pending state,


kubeadm reset --cri-socket=/var/run/crio/crio.sock
kubeadm reset --cri-socket=/var/run/dockershim.sock

kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/dockershim.sock 
kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/crio/crio.sock 
```

### Now I get error: 
```bash

[ERROR FileContent--proc-sys-net-ipv4-ip_forward]: /proc/sys/net/ipv4/ip_forward contents are not set to 1
```


Possibly have stale data in  (/etc/kubernetes) directory:
```bash

kubeadm reset
```

### Now set ip_forward content with 1:
```bash
# as sudo
sudo -i
echo 1 > /proc/sys/net/ipv4/ip_forward
```


### Now I get :
```bash

WARNING: Couldn't create the interface used for talking to the container runtime: docker is required for container runtime: exec: "docker": executable file not found in $PATH
```

!!!!! Started from scratch. Rebuild Fedora Server Started at the top. I belive a previous install of Docer or MicroK8 was running in the background.

Worked on a clean build... :)

## Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:
```bash

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Alternatively, if you are the root user, you can run:
```bash

  export KUBECONFIG=/etc/kubernetes/admin.conf
```

You should now deploy a pod network to the cluster.

Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:

  https://kubernetes.io/docs/concepts/cluster-administration/addons/


Then you can join any number of worker nodes by running the following on each as root:
```bash

kubeadm join 192.168.1.134:6443 --token ivlc5m.emalaa64qiqui5c6 \
	--discovery-token-ca-cert-hash sha256:824c566afdf8111419eacc8fd983690aca88c39ab5f685f9fb3656387efb2e69 
[root@fedora ~]#
```

#Joing Worker Node
```bash 
# kube-controlplane-00
kubeadm token create --print-join-command
kubeadm join kube-controlplane-00.k8:6443 --token dtn74m.t71fzza0fdvekte7 --discovery-token-ca-cert-hash sha256:8f769857e608971b5cf5bf5ea75cee376cfade7f7549bc486922104ae86f2d65 --v=2

``

## Setup Kubernetes Dashboard
Create a resourece file dashboard-adminuser.yaml:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---

```


Then run 
```bash

kubectl apply -f dashboard-adminuser.yaml
```

Get a token to login (I'll fix the real account later):

```bash

kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
kubectl proxy
```

#URL: "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"


## Setup CoreDNS 
Already running as part of the install... ?



## Setup Worker Node

[paul@localhost ~]$ sudo dnf install cri-o
[paul@localhost ~]$ sudo systemctl daemon-reload
[paul@localhost ~]$ sudo systemctl enable crio
[paul@localhost ~]$ sudo systemctl start crio
[paul@localhost ~]$ sudo systemctl status crio
[paul@localhost ~]$ 

sudo kubeadm init --pod-network-cidr=$CIDR --cri-socket=unix:///var/run/crio/crio.sock
sudo kubeadm init --pod-network-cidr=$CIDR --cri-socket=unix:///var/run/crio/crio.sock --control-plane-endpoint=kube-controlplane-00.k8


#from Control Plane
#kube-controlplane-00
kubeadm token create --print-join-command
sudo kubeadm join kube-controlplane-00.k8:6443 --token 3gcpnb.ft7fem7gq7ty4st0 --discovery-token-ca-cert-hash sha256:8f769857e608971b5cf5bf5ea75cee376cfade7f7549bc486922104ae86f2d65 
kubectl label node kube-workernode-00.k8 node-role.kubernetes.io/worker=worker


To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

sudo kubeadm join kube-controlplane-00.k8:6443 --token xdwt88.1e60vy33b3zxo41c \
	--discovery-token-ca-cert-hash sha256:eb990148433f6b81853b8ce893486d53b4f7894e150d474864a6a5952e5d59a0 --v=2


# NODE SET-UP


``` bash
[paul@localhost ~]$ cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

[paul@localhost ~]$ sudo setenforce 0
[paul@localhost ~]$ sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
[paul@localhost ~]$ sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
[paul@localhost ~]$ sudo systemctl enable --now kubelet


sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
et.bridge.bridge-nf-call-ip6tables = 1
EOF


cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo firewall-cmd --add-port=30000-32767/tcp
sudo firewall-cmd --add-port=10250/tcp

dnf module list cri-o
export VERSION=1.25
sudo dnf module enable cri-o:$VERSION
sudo dnf module enable cri-o:$VERSION
sudo dnf install cri-o
sudo systemctl daemon-reload
sudo systemctl enable crio
sudo systemctl start crio

echo 1 > /proc/sys/net/ipv4/ip_forward
curl sudo sysctl -w net.ipv4.ip_forward=1


kubeadm join kube-controlplane-00.k8:6443 --token 8ukrt0.qv6kodfjfq43g25v \
	--discovery-token-ca-cert-hash sha256:d5a3edfa1ba796f507a9aafacfa3a98cee61601605b2777b1c83e125b7cba35b --v=2
	
	
Here are following command which you can use -

$ sudo vi /etc/sysctl.conf
BASH
After opening the file sysctl.conf in edit mode, add the following line if its not there.

net.bridge.bridge-nf-call-iptables = 1
BASH
Then you need to execute

$ sudo sysctl -p
```