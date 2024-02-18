# Kubernetes Dashboard
```bash
kubectl apply -f dashboard-adminuser.yaml
kubectl apply -f clusterrolebinding.yaml 
kubectl -n kubernetes-dashboard create token admin-user
kubectl apply -f admin-user-secret.yaml 
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
kubectl proxy
```

# Core DNS
https://serverfault.com/questions/1081685/kubernetes-coredns-is-in-crashloopbackoff-status-with-no-nameservers-found-err