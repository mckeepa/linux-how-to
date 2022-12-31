# File Sharing (virtiofs) - used in Persistant Volumes (PV)

## on Client

mount -t virtiofs host_shared /mnt/host-share/

sudo mkdir -p /mnt/data/
sudo mount -t virtiofs host_shared /mnt/data/
ls -la /mnt/data/

findmnt 
findmnt /mnt/host-share

## follow creating a pod with mount
https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/

```bash
# This again assumes that your Node uses "sudo" to run commands
# as the superuser
sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/index.html"

```
pv-volume.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

```bash
# kubectl apply -f https://k8s.io/examples/pods/storage/pv-volume.yaml
kubectl apply -f pv-volume.yaml 
kubectl get pv task-pv-volume
```
## Create a PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
```

```bash
# kubectl apply -f https://k8s.io/examples/pods/storage/pv-claim.yaml
kubectl apply -f pv-claim.yaml 

# Now the output shows a STATUS of Bound.
kubectl get pv task-pv-volume

# The output shows that the PersistentVolumeClaim is bound to your PersistentVolume, task-pv-volume
kubectl get pvc task-pv-claim
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: task-pv-pod
spec:
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
        claimName: task-pv-claim
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage

```

```bash
# kubectl apply -f https://k8s.io/examples/pods/storage/pv-pod.yaml
kubectl apply -f pv-pod.yaml

#Verify that the container in the Pod is running;
kubectl get pod task-pv-pod
# Get a shell to the container running in your Pod:
kubectl exec -it task-pv-pod -- /bin/bash
```

In your shell, verify that nginx is serving the index.html file from the hostPath volume:
```bash 
# Be sure to run these 3 commands inside the root shell that comes from
# running "kubectl exec" in the previous step

# cURL already in the image
# apt update
# apt install curl
curl http://localhost/
Hello from Kubernetes storage
```

# Clean up
Delete the Pod, the PersistentVolumeClaim and the PersistentVolume:

```bash 
kubectl delete pod task-pv-pod
kubectl delete pvc task-pv-claim
kubectl delete pv task-pv-volume
```