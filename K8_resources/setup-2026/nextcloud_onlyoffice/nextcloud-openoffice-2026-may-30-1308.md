# Sovereign Digital Workspace Setup Guide
### Nextcloud Hub & ONLYOFFICE Docs with Rootless Podman, Quadlets, and Nginx SSL on Fedora Server

This blueprint delivers an enterprise-grade, error-free deployment of a secure digital workspace modeled after EU digital sovereignty frameworks. It segregates application logic into rootless container namespaces, manages services with Fedora-native **Quadlets**, unifies multi-port traffic behind an **Nginx Reverse Proxy**, and secures all traffic via local **SSL/TLS**.

---

## 🏗️ Architecture Blueprint & Parameters
*   **Host OS**: Fedora Server (Fresh, non-root user execution context)
*   **Target Domain Layout**:
    *   Nextcloud Workspace Portal: `https://gardenofrot.cc`
    *   ONLYOFFICE Document Server: `https://gardenofrot.cc`
*   **Internal Podman Overlay Network**: `nextcloud-net` (Handled natively via Systemd)
*   **Host Physical Network IP Mapping Reference**: `192.168.122.199`

---

## Step 1: System Initialization & Firewall Tuning

Log in to your fresh Fedora Server as your non-root user. Run these commands to update package trees, grant persistent user runtime execution privileges, and configure host network firewall mappings.

```bash
# Update the operating system core package tree
sudo dnf update -y

# Install Podman container management engine and security utilities
sudo dnf install -y podman policycoreutils-python-utils nginx crypto-policies

# Enable user lingering so containers boot and run persistently without an active SSH session
sudo loginctl enable-linger $USER

# Configure the host firewalld zones to accept standard secure web traffic
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload
```

---

## Step 2: Storage Volume Provisioning & Namespace Mapping

Create local persistent storage volumes for database clusters and application configuration trees. Re-align user namespace boundaries to grant Nextcloud's internal web server process (`UID 33`) write authorizations.

```bash
# Allocate stateful application volumes
podman volume create nc-db-data
podman volume create nc-app-data
podman volume create nc-app-config
podman volume create oo-data
podman volume create oo-logs

# Extract the absolute physical host paths of the Nextcloud volumes
CONFIG_PATH=$(podman volume inspect nc-app-config --format '{{.Mountpoint}}')
DATA_PATH=$(podman volume inspect nc-app-data --format '{{.Mountpoint}}')

# Map permissions across rootless namespaces directly to UID 33:33 (www-data)
podman unshare chown -R 33:33 "$CONFIG_PATH"
podman unshare chown -R 33:33 "$DATA_PATH"
```

---

## Step 3: Provision Fedora-Native Quadlet Files

Quadlets are the modern standard for automating containers using systemd on Fedora. Create the systemd configurations in your user profile path so they start automatically at boot.

```bash
# Generate the mandatory user systemd directory skeletons
mkdir -p ~/.config/containers/systemd/
cd ~/.config/containers/systemd/

# 1. Create the Private Internal Network Mesh Quadlet
cat << 'EOF' > nextcloud-net.network
[Network]
NetworkName=nextcloud-net
EOF

# 2. Create the Database Server Quadlet
cat << 'EOF' > nextcloud-db.container
[Unit]
Description=Nextcloud PostgreSQL Database Cluster

[Container]
ContainerName=nextcloud-db
Image=docker.io/library/postgres:15-alpine
Network=nextcloud-net.network
Volume=nc-db-data:/var/lib/postgresql/data:Z
Environment=POSTGRES_DB=nextcloud
Environment=POSTGRES_USER=nextcloud_user
Environment=POSTGRES_PASSWORD=YourSecurePasswordHere

[Install]
WantedBy=default.target
EOF

# 3. Create the Document Server Quadlet (With Internal Multi-Host Resolution Mappings)
cat << 'EOF' > onlyoffice-docs.container
[Unit]
Description=ONLYOFFICE Document Server Engine

[Container]
ContainerName=onlyoffice-docs
Image=docker.io/onlyoffice/documentserver:latest
Network=nextcloud-net.network
PublishPort=8081:80
AddHost=cloud.gardenofrot.cc:192.168.122.199
AddHost=office.gardenofrot.cc:192.168.122.199
Volume=oo-data:/var/www/onlyoffice/Data:Z
Volume=oo-logs:/var/log/onlyoffice:Z
Environment=JWT_ENABLED=true
Environment=JWT_SECRET=YourSuperSecretJWTKeyHere
Environment=JWT_HEADER=Authorization

[Install]
WantedBy=default.target
EOF

# 4. Create the Nextcloud Core Application Quadlet (With Internal Multi-Host Resolution Mappings)
cat << 'EOF' > nextcloud-app.container
[Unit]
Description=Nextcloud Application Core Web Server
After=nextcloud-db.service onlyoffice-docs.service

[Container]
ContainerName=nextcloud-app
Image=docker.io/library/nextcloud:stable
Network=nextcloud-net.network
PublishPort=8082:80
AddHost=cloud.gardenofrot.cc:192.168.122.199
AddHost=office.gardenofrot.cc:192.168.122.199
Volume=nc-app-data:/var/www/html:Z
Volume=nc-app-config:/var/www/html/config:Z
Environment=POSTGRES_HOST=nextcloud-db
Environment=POSTGRES_DB=nextcloud
Environment=POSTGRES_USER=nextcloud_user
Environment=POSTGRES_PASSWORD=YourSecurePasswordHere
Environment=NEXTCLOUD_ADMIN_USER=admin
Environment=NEXTCLOUD_ADMIN_PASSWORD=YourSecureAdminPassword

[Install]
WantedBy=default.target
EOF
```

---

## Step 4: Boot and Activate Your Service Architecture

Instruct systemd to compile your newly written Quadlet unit definitions and safely start the stack in the correct sequence.

```bash
# Force systemd to process and compile the container configuration blocks
systemctl --user daemon-reload

# Start the integrated workspace services
systemctl --user start nextcloud-db.service onlyoffice-docs.service nextcloud-app.service

# Pause for 30 seconds to allow the internal frameworks to perform automated first-boot tasks
sleep 30
```

---

## Step 5: Establish the Hardened Nginx SSL Proxy Layer

Generate local secure SSL/TLS certificates and map incoming traffic streams using subdomains to isolate individual application context scopes.

```bash
# 1. Create a dedicated repository path for security keys
sudo mkdir -p /etc/nginx/ssl

# 2. Issue a custom 2048-bit RSA cryptographic certificate bundle
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nextcloud.key \
  -out /etc/nginx/ssl/nextcloud.crt \
  -subj "/C=EU/ST=Sovereign/L=Local/O=DigitalWorkspace/CN=*.gardenofrot.cc"

# 3. Securely deploy the multi-subdomain proxy routing configurations using sudo tee
sudo tee /etc/nginx/conf.d/nextcloud.conf << 'EOF' > /dev/null
# Main Nextcloud Portal Subdomain Configuration
server {
    listen 80;
    listen 443 ssl;
    server_name cloud.gardenofrot.cc;

    ssl_certificate /etc/nginx/ssl/nextcloud.crt;
    ssl_certificate_key /etc/nginx/ssl/nextcloud.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    # Optimize transport constraints to handle large chunks and media streaming files
    proxy_buffering off;
    client_max_body_size 10G;

    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# ONLYOFFICE Core Engine Subdomain Configuration
server {
    listen 80;
    listen 443 ssl;
    server_name office.gardenofrot.cc;

    ssl_certificate /etc/nginx/ssl/nextcloud.crt;
    ssl_certificate_key /etc/nginx/ssl/nextcloud.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
EOF

# 4. Tune SELinux policies to permit Nginx to execute proxy routing to container ports
sudo setsebool -P httpd_can_network_connect 1

# 5. Verify configuration integrity and restart Nginx
sudo nginx -t && sudo systemctl restart nginx
```

---

## Step 6: Inject Subdomain Routing & Certificate Overrides

Apply explicit environment variables into Nextcloud's configuration layer via the terminal to permit local network proxy connections, trust incoming domain headers, and download the web integrations application.

```bash
# 1. Register the subdomain targets into Nextcloud's trusted security list
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 1 --value="cloud.gardenofrot.cc"
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 2 --value="office.gardenofrot.cc"
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 3 --value="192.168.122.199"

# 2. Inform Nextcloud that it runs entirely behind a secure proxy layer
podman exec -u www-data nextcloud-app php occ config:system:set trusted_proxies 0 --value="127.0.0.1"

# 3. Permit outbound communication to local subnets for document handshakes
podman exec -u www-data nextcloud-app php occ config:system:set allow_local_remote_servers --value=true --type=boolean

# 4. Turn off strict self-signed certificate validation blocks for internal network cURL paths
podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice verify_peer_off --value="true" --type=boolean
podman exec -u www-data nextcloud-app php occ config:system:set curl.options --value='{"10015": false, "64": false}' --type=json

# 5. Disable self-signed validation blocks inside the ONLYOFFICE engine container
podman exec -it onlyoffice-docs sed -i 's/"rejectUnauthorized": true/"rejectUnauthorized": false/g' /etc/onlyoffice/documentserver/default.json
podman exec -it onlyoffice-docs supervisorctl restart all

# 6. Fetch, extract, and deploy the official ONLYOFFICE connector engine plug-in


podman exec -it -u www-data nextcloud-app php occ app:install onlyoffice


podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice DocumentServerUrl --value="gardenofrot.cc"podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice-docs/"podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice StorageUrl --value="http://nextcloud-app/"podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice jwt_secret --value="YourSuperSecretJWTKeyHere"podman exec -u www-data nextcloud-app php occ config:system:set onlyoffice jwt_header --value="Authorization"

Perform a clean restart of the application container core

systemctl --user restart nextcloud-app.service%%MAGIT_PARSER_PROTECT%%``

Configure local host resolutions on your client machine's hosts file (C:\Windows\System32\drivers\etc\hosts or /etc/hosts):

192.168.122.199 cloud.gardenofrot.cc office.gardenofrot.cc


Log in using your administration parameters:Username: adminPassword: YourSecureAdminPassword

Manage your container platform using native systemd commands:


Stop the Office Suite:systemctl --user stop nextcloud-app onlyoffice-docs nextcloud-dbStart the Office Suite:systemctl --user start nextcloud-db onlyoffice-docs nextcloud-appRestart the Office Suite:systemctl --user restart nextcloud-db onlyoffice-docs nextcloud-appInspect Live Log Output:journalctl --user -u nextcloud-app.service -f

