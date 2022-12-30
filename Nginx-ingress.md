# Install kubernetes ingress-nginx

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