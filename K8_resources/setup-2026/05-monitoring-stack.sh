# 1. Install Metrics Server (for basic 'kubectl top' and dashboard bars)
kubectl apply -f https://github.com
# Patch for self-signed certs (common in lab setups)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 2. Add Repos and Install Headlamp
helm repo add headlamp https://github.io
helm repo update
helm upgrade --install headlamp headlamp/headlamp --namespace headlamp --create-namespace

# 3. Install Prometheus/Grafana Stack
helm repo add prometheus-community https://github.io
helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
