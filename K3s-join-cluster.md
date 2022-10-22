From the Master Node

Run these to outoput the commands for the Node
```bash
K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
K3S_EXTERNAL_IP=$(getent hosts pibox.local | awk '{print $1}' | head -1)

sudo echo -e "export K3S_TOKEN="$K3S_TOKEN"\nexport K3S_URL=https://$K3S_EXTERNAL_IP:6443\nexport INSTALL_K3S_EXEC=\"--docker --token \$K3S_TOKEN --server \$K3S_URL\""
```

Then run on K3s Worker Node:

Confirm env..

sudo nano /etc/systemd/system/k3s-agent.service.env


```
K3S_TOKEN='K1065613a2fa50dd99ef34a08164a5b6eaa176e51bdf2f4850e2b5aecd0e322200a::server:f49519a6575fd59c13c66c8783dbae0c'
K3S_URL='https://$(getent hosts pibox.local | awk '{print $1}' | head -1):6443'
```

## Install kuectl on local machine (not the contol plane or worker nodes)

Verify version
```bash
kubectl version --short
# or
kubectl version --client --output=yaml 
```

Install
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Download the Google Cloud public signing key
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

#Add the Kubernetes apt repository
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index with the new repository and install kubectl:
sudo apt-get update
sudo apt-get install -y kubectl

```