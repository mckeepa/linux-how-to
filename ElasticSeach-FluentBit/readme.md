# ElasticSearch FluentBit Kubernetes -   Elastic Cloud on Kubernetes (ECK)


Start with a clean Rancher install

##  Install the ECK Operator & Fluent Bit
First, we need to install the Elastic Cloud on Kubernetes (ECK) Operator and the Fluent Bit agent for log forwarding.

Create Namespace for Observability
Create a new namespace where all observability resources will reside.

```bash
  kubectl create ns observer
```

### Add Helm Repositories
Add the Elastic and Fluent Bit Helm repositories to your Helm configuration:
```bash
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts

```

Install the ECK Operator
The ECK Operator manages the deployment of Elasticsearch and Kibana. Install the operator with Helm.

```bash

helm install elastic-operator elastic/eck-operator -n observer --kubeconfig .kube/config 

kubectl logs -n observer sts/elastic-operator
```
## Deploy Elasticsearch Cluster
Deploy an Elasticsearch cluster that Fluent Bit will forward logs to. 

The deployment will use a Elasticsearch configuration with one node.

### Create an Elasticsearch YAML File
Save the following YAML configuration as elasticsearch.yaml:
```bash
 vi elasticsearch.yaml
 ```

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart-es
  namespace: observer
spec:
  version: 8.17.1  # Specify your desired Elasticsearch version
  nodeSets:
    - name: default
      count: 1  # Single-node cluster (scale as needed)
      config:
        node.store.allow_mmap: false  # Important for certain environments
  http:
    service:
      spec:
        type: LoadBalancer  # Use NodePort if LoadBalancer is not available
```

```bash 
 kubectl apply -f elasticsearch.yaml
```

### Apply the Kibana Configuration
Deploy Kibana by applying the configuration:
```bash
  vi kibana.yaml
```

```yaml
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart-kb
  namespace: observer
spec:
  version: 8.17.1  # Specify your desired Kibana version
  count: 1  # Single instance
  elasticsearchRef:
    name: quickstart-es
  http:
    service:
      spec:
        type: NodePort  # Use LoadBalancer if preferred

````

```bash
kubectl apply -f kibana.yaml
```

## Configure Fluent Bit for Log Forwarding
Fluent Bit will act as the log forwarder, sending logs from your Kubernetes nodes to Elasticsearch.

### Configure Fluent Bit Values File
You will need to create a configuration for Fluent Bit, specifying how it will connect to Elasticsearch. Create a Fluent Bit values file (e.g., fluentbit-values.yaml) and populate the output.conf section:

```bash
kubectl logs -n observer sts/elastic-operator
kubectl get crd

```

### Get the Password from Secrets, and IP from service 
```bash
# Get the Password for the Elastic User 
kubectl get secrets -n observer
kubectl get secret quickstart-es-es-elastic-user   -n observer
kubectl get secret quickstart-es-es-elastic-user -o jsonpath='{.data}'  -n observer

# Get the IP Address for the 
kubectl get service 
kubectl get service -n observer
kubectl get service quickstart-es-es-http  -n observer

# edit the file 
vi fluentbit-values.yaml

```
File Contents:
```yaml
data:
  output.conf: |
    [OUTPUT]
      Name             es
      Match            *
      Host             <elasticsearch_service_ip>  # Replace with Elasticsearch service IP
      Port             9200
      tls.verify       Off  # Security risk, enable in production
      tls.debug        3
      Index            fluentbit-forwarder
      Logstash_Format  Off
      tls.ca_file      /fluent-bit/tls/tls.crt
      tls.crt_file     /fluent-bit/tls/tls.crt
      HTTP_User        elastic
      HTTP_Passwd      <elasticsearch_password>  # Replace with actual password
      tls              On
      Suppress_Type_Name On
```

## Install Fluent Bit with Helm
Install Fluent Bit using Helm, referencing the values created:

```bash 
# install Fluent-bit
helm install fluent-bit fluent/fluent-bit -f fluentbit-values.yaml -n observer

# Get the Pod name 
kubectl get pods --namespace observer -l "app.kubernetes.io/name=fluent-bit,app.kubernetes.io/instance=fluent-bit" -o jsonpath="{.items[0].metadata.name}"
```

## Mount Certificates via Secret in Fluent Bit DaemonSet
To securely connect Fluent Bit to Elasticsearch over HTTPS, it needs the Elasticsearch TLS certificates mounted into the Fluent Bit container.

### Update Fluent Bit DaemonSet
Modify the Fluent Bit DaemonSet manifest to mount the necessary certificates stored in the quickstart-es-http-certs-public secret:

```yaml
volumeMounts:
- mountPath: /fluent-bit/tls
  name: tls-certs
  readOnly: true  # Ensure the certificates are read-only
volumes:
- name: tls-certs
  secret:
    secretName: quickstart-es-http-certs-public

```
The configuration mounts the certificates at /fluent-bit/tls within the Fluent Bit container. 

Ensure the tls.ca_file and tls.crt_file paths in your Fluent Bit configuration point to these mounted files (e.g., /fluent-bit/tls/tls.crt).


```bash

kubectl describe DaemonSet fluent-bit  --namespace observer

vi fluent-bit-DaemonSet-values.yaml
```
```yaml
volumeMounts:
- mountPath: /fluent-bit/tls
  name: tls-certs
  readOnly: true  # Ensure the certificates are read-only
volumes:
- name: tls-certs
  secret:
    secretName: quickstart-es-http-certs-public
```

helm install elastic-operator elastic/eck-operator -n observer --kubeconfig .kube/config 

helm upgrade fluent-bit fluent/fluent-bit --values fluent-bit-DaemonSet-values.yaml
```





### Referneces
Source: 
Setting Up the EFK Stack on Kubernetes with Elastic Cloud on Kubernetes (ECK) [https://saedf0.medium.com/setting-up-the-efk-stack-on-kubernetes-with-elastic-cloud-on-kubernetes-eck-bd4a38331486]

https://www.youtube.com/watch?v=GmcmhVengVU