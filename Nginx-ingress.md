
# Install kubernetes ingress-nginx


https://medium.com/tektutor/using-metal-lb-on-a-bare-metal-onprem-kubernetes-setup-6d036af1d20c



kubectl create deploy nginx --image=nginx:1.20
kubectl get deploy,rs,po
kubectl scale deploy/nginx --replicas=3
kubectl get deploy,rs,po
kubectl get deploy,rs,po -o=wide
kubectl expose deploy/nginx --type=LoadBalancer --port=80
kubectl get deploy,rs,po,svc -o=wide
kubectl describe svc/nginx
kubectl scale deploy/nginx --replicas=0
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml

# on Master and all workers
sudo firewall-cmd --permanent --add-port=7472/tcp --zone=trusted
sudo firewall-cmd --permanent --add-port=7472/udp --zone=trusted
sudo firewall-cmd --permanent --add-port=7946/tcp --zone=trusted
sudo firewall-cmd --permanent --add-port=7946/udp --zone=trusted
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

# for this directory
kubectl apply -f metal-lb-cm.yml

# v0.11 had errors, moved to metallb/v0.13.7 metallb-native.yaml
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
# kubectl apply -f metallb.yaml

# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl apply -f metallb-native.yaml 
kubectl scale deploy nginx --replicas=3

kubectl get pod  -n metallb-system
kubectl scale deploy nginx --replicas=3
kubectl expose deploy nginx --type=LoadBalancer --port=80

# scale ngix back up
kubectl scale deploy nginx --replicas=3   
kubectl get deploy,rs,po,svc -o=wide

kubectl expose deploy nginx --type=LoadBalancer --port=80


## Metal-lb BGP Configuration
https://metallb.universe.tf/configuration/

## Clean up
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations metallb-webhook-configuration
kubectl delete namespace metallb-system
kubectl get svc
kubectl delete svc nginx 
kubectl get namespace


# old -----------------------
```bash
 kubectl get pods --namespace=ingress-nginx
 kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.4.0/deploy/static/provider/cloud/deploy.yaml
 kubectl get pods --namespace=ingress-nginx
 kubectl wait --namespace ingress-nginx   --for=condition=ready pod   --selector=app.kubernetes.io/component=controller   --timeout=120s
 kubectl get pods --namespace=ingress-nginx
 ```

 # deploy demo application runing on port 80 in the continer
 ```bash
 kubectl create deployment demo --image=httpd --port=80
 kubectl expose deployment demo
 kubectl expose deployment kubernetes-dashboard
 
```



# Expose Demo application
```bash
 # create ingress object 
 kubectl create ingress demo-localhost --class=nginx   --rule="demo.localdev.me/*=demo:80"
 kubectl create ingress kubernetes-dashboard-localhost --class=nginx   --rule="kubernetes-dashboard.me/*=kubernetes-dashboard:8001"

 # temporary, expose port on this machine
 kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
 # ctl c,  to stop port-forwarding
 
 # Get EXTERNAL-IP from the "ingress-nginx-controller" running in the "ingress-nginx" namesapce  
 kubectl get service ingress-nginx-controller --namespace=ingress-nginx
 
 # add DNS entry to piHole.
 # "www.demo.io" -> "192.168.1.216"

 # Create ingress, 
 #           - listening on "www.demo.io:80"
 #           - Forwarding to exposed deployment "demo" 
 #     Ingress name: demo
 #     using class : nginx
 #     rule        : "www.demo.io/*"  to be forwarded to port 80 on exposed deploment demo
 kubectl create ingress demo --class=nginx   --rule="www.demo.io/*=demo:80"
 kubectl create ingress kubernetes-dashboard-localhost --class=nginx   --rule="kubernetes-dashboard.me/*=kubernetes-dashboard:8001" --namespace=kubernetes-dashboard
 ```