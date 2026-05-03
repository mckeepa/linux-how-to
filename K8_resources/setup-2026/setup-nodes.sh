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