# 
# 

https://kubernetes.io/docs/concepts/cluster-administration/logging/


```bash

#kubectl apply -f https://k8s.io/examples/debug/counter-pod.yaml
wget https://k8s.io/examples/debug/counter-pod.yaml
kubectl apply -f counter-pod.yaml

#get logs
kubectl logs counter


#can not access logs
kubectl logs counter -c count
kubectl logs --previous

#clean up
kubectl delete -f counter-pod.yaml

```

# Sidecar
```bash
wget https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/admin/logging/two-files-counter-pod-streaming-sidecar.yaml
kubectl apply -f two-files-counter-pod-streaming-sidecar.yaml
```

--------------------
# ELK install
https://www.elastic.co/guide/en/cloud-on-k8s/2.2/k8s-deploy-eck.html

Install custom resource definitions:

```bash
kubectl create -f https://download.elastic.co/downloads/eck/2.2.0/crds.yaml
```
The following Elastic resources have been created:

customresourcedefinition.apiextensions.k8s.io/agents.agent.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/apmservers.apm.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/beats.beat.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticmapsservers.maps.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticsearches.elasticsearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/enterprisesearches.enterprisesearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/kibanas.kibana.k8s.elastic.co created
Install the operator with its RBAC rules:

```bash

kubectl apply -f https://download.elastic.co/downloads/eck/2.2.0/operator.yaml
```

The ECK operator runs by default in the elastic-system namespace. It is recommended that you choose a dedicated namespace for your workloads, rather than using the elastic-system or the default namespace.

Monitor the operator logs:

```bash
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.5.3
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF
```
or 
```bash
kubectl apply -f ES_Clustyer_spec.yaml
```
View the current ES Cluster
```bash
kubectl get elasticsearch
```

# Share Host directory

https://sysguides.com/share-files-between-kvm-host-and-linux-guest-using-virtiofs/

cd /mnt/
sudo mkdir -v host-share
sudo mount -t virtiofs host_shared /mnt/host-share
sudo vim /etc/fstab

```
...

host_shared  /mnt/host-share virtiofs defaults   0 0

```
sudo mount -a


# NFS Share directory for Perssistant Volume (PV)
```
sudo dnf install nfs-utils

# enable the nfs server and required services by using –
sudo systemctl enable rpcbind
sudo systemctl enable nfs-server

sudo service rpcbind start
sudo service nfs-server start

# Check the status of your NFS server by using –
sudo systemctl status nfs-server
```
## Firewall on NFS Server
```bash
sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-interface=virbr1
sudo firewall-cmd --permanent --zone public --add-service mountd
sudo firewall-cmd --permanent --zone public --add-service rpc-bind
sudo firewall-cmd --permanent --zone public --add-service nfs
sudo firewall-cmd --reload

```


```
sudo mkdir -p /media/nfs
sudo nano /etc/exports
```
/media/nfs/ 127.0.0.1(rw,sync,no_subtree_check)
/media/nfs/ 192.168.100.163(rw,sync,no_subtree_check)
/media/nfs/ 192.168.100.235(rw,sync,no_subtree_check)
```
use the following options –

- ro – This specifies read-only permissions to a client
- rw – It grants read and write permission to the shared directory
- no_root_squash – It allows remote root users to use the server with the same permission as it has on its own system
- subtree_check – Using this option verifies that a file being accessed is in a subfolder on the same volume.
- no_subtree_check – It is the opposite of the previous option, when sharing an entire volume this option will speed up access to subdirectories and files.
- sync – This option ensures that any changes made are uploaded to the shared directory
- async – It ignores the synchronization check in favor of increased speed

```bash
sudo exportfs -avrf
```

## Connect to the NFS server from a client machine
First, set up client components of NFS on your system. 

```bash
sudo dnf -y install nfs-utils
```

```bash
# Create a directory to mount the remote directory /media/nfs –
sudo mkdir -p /mnt/nfs_client
```
Run the given command to mount the remote directory /media/nfs to /mnt/
```bash
#nfs_client at your client machine –
sudo mount -t nfs4 192.168.122.188:/media/nfs /mnt/nfs_client
sudo mount -t nfs4 192.168.1.134:/media/nfs /mnt/nfs_client
systemctl daemon-reload

```
The IP given in the command above is the NFS server IP address.

## Test the NFS setup
To test your NFS setup create a file inside the /media/nfs directory on the server, the same file will be available in /mnt/nfs_client directory on the client machine and vice-versa. That means our NFS setup is working fine.

nfs share
So you have successfully set up NFS on your Fedora system. Now you can share your experience in the comments below.


