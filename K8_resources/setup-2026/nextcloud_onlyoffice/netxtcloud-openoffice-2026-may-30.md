# Sovereign Digital Workspace Setup Guide
### Nextcloud & ONLYOFFICE Docs with Rootless Podman and Quadlets on Fedora Server

This document provides an error-free, step-by-step blueprint to deploy a sovereign collaborative office suite modeled after EU privacy frameworks. It utilizes rootless **Podman**, Fedora-native **Quadlets** for production-grade systemd integration, and secure internal networking.

---

## Prerequisites & Architecture
* **Host OS**: Fedora Server (Fresh installation)
* **Access Level**: Standard non-root user with `sudo` privileges
* **Server Target IP**: `192.168.122.199`
* **Port Allocations**: 
  * Nextcloud Core Web Access: Port `8080`
  * ONLYOFFICE Document Server Access: Port `8081`

---

## Step 1: System Initialization & Firewall Tuning

Log in to your fresh Fedora Server as your non-root user. Run these commands to update package trees, grant persistent user execution limits, and map firewall openings.

```bash
# Update the operating system core packages
sudo dnf update -y

# Install Podman and crucial SELinux/security utilities
sudo dnf install -y podman policycoreutils-python-utils

# Enable user lingering so containers stay running after SSH logout
sudo loginctl enable-linger $USER

# Open network web routing ports through the Fedora host firewall
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --add-port=8081/tcp --permanent
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload
```

---

## Step 2: Storage Allocation & User Namespace Fixes

To prevent write failures during application setups, create persistent volumes and realign file permissions to match Nextcloud's internal web server user (`UID 33`).

```bash
# Create the required storage volumes
podman volume create nc-db-data
podman volume create nc-app-data
podman volume create nc-app-config
podman volume create oo-data
podman volume create oo-logs

# Extract the physical mount paths of the Nextcloud volumes
CONFIG_PATH=$(podman volume inspect nc-app-config --format '{{.Mountpoint}}')
DATA_PATH=$(podman volume inspect nc-app-data --format '{{.Mountpoint}}')

# Shift directory ownership inside the rootless namespace to UID 33 (www-data)
podman unshare chown -R 33:33 "$CONFIG_PATH"
podman unshare chown -R 33:33 "$DATA_PATH"
```

---

## Step 3: Provision Fedora-Native Quadlet Files

Quadlets are the modern standard for automating containers using systemd on Fedora. Create the systemd configurations in your user profile path so they start automatically at boot.

```bash
# Generate the required systemd config directory skeleton
mkdir -p ~/.config/containers/systemd/
cd ~/.config/containers/systemd/

# 1. Create the Isolated Network Mesh Quadlet
cat << 'EOF' > nextcloud-net.network
[Unit]
Description=Sovereign Nextcloud Cloud Network Mesh

[Network]
NetworkName=nextcloud-net
EOF

# 2. Create the Database Server Quadlet
cat << 'EOF' > nextcloud-db.container
[Unit]
Description=Nextcloud PostgreSQL Database

[Container]
ContainerName=nextcloud-db
Image=docker.io/library/postgres:15-alpine
Network=nextcloud-net
Volume=nc-db-data:/var/lib/postgresql/data:Z
Environment=POSTGRES_DB=nextcloud POSTGRES_USER=nextcloud_user POSTGRES_PASSWORD=YourSecurePasswordHere

[Install]
WantedBy=default.target
EOF

# 3. Create the Document Server Quadlet
cat << 'EOF' > onlyoffice-docs.container
[Unit]
Description=ONLYOFFICE Document Server

[Container]
ContainerName=onlyoffice-docs
Image=docker.io/onlyoffice/documentserver:latest
Network=nextcloud-net
PublishPort=8081:80
Volume=oo-data:/var/www/onlyoffice/Data:Z
Volume=oo-logs:/var/log/onlyoffice:Z
Environment=JWT_ENABLED=true JWT_SECRET=YourSuperSecretJWTKeyHere JWT_HEADER=Authorization

[Install]
WantedBy=default.target
EOF

# 4. Create the Nextcloud Core Web Application Quadlet
cat << 'EOF' > nextcloud-app.container
[Unit]
Description=Nextcloud Application Server
After=nextcloud-db.container onlyoffice-docs.container

[Container]
ContainerName=nextcloud-app
Image=docker.io/library/nextcloud:stable
Network=nextcloud-net
PublishPort=8080:80
Volume=nc-app-data:/var/www/html:Z
Volume=nc-app-config:/var/www/html/config:Z
Environment=POSTGRES_HOST=nextcloud-db POSTGRES_DB=nextcloud POSTGRES_USER=nextcloud_user POSTGRES_PASSWORD=YourSecurePasswordHere NEXTCLOUD_ADMIN_USER=admin NEXTCLOUD_ADMIN_PASSWORD=YourSecureAdminPassword

[Install]
WantedBy=default.target
EOF
```

---

## Step 4: Boot and Activate Your Office Architecture

Instruct systemd to compile your Quadlet unit definitions and safely start the stack in the correct sequence.

```bash
# Force systemd to process and compile the new container definitions
systemctl --user daemon-reload

# Start the integrated workspace architecture
systemctl --user start nextcloud-db.service onlyoffice-docs.service nextcloud-app.service

# Pause for 30 seconds to allow internal database initializations to finish cleanly
sleep 30
```

---

## Step 5: Inject Cross-Origin and Token Security Overrides

Execute these commands to clear private network request blocks and automatically inject the ONLYOFFICE integration connector directly through Nextcloud's terminal layer.

```bash
# 1. Permit ONLYOFFICE to fetch document data across private container network IPs
podman exec -it onlyoffice-docs sed -i 's/"allowPrivateIPAddress": false/"allowPrivateIPAddress": true/g' /etc/onlyoffice/documentserver/default.json
podman exec -it onlyoffice-docs supervisorctl restart all

# 2. Grant Nextcloud authorization to make local network requests
podman exec -u www-data nextcloud-app php occ config:system:set allow_local_remote_servers --value=true --type=boolean

# 3. Whitelist your Fedora machine's local LAN IP inside Nextcloud's Trusted Domains list
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 3 --value="192.168.122.199"

# 4. Fetch and deploy the official ONLYOFFICE plugin bundle straight into Nextcloud
podman exec -it -u www-data nextcloud-app php occ app:install onlyoffice
```

---

## Step 6: Link ONLYOFFICE and Nextcloud via Browser

1. Open your web browser and navigate directly to your instance domain/IP:
   ```text
   http://192.168.122.199:8080
   ```
2. Log in using your configured administration credentials:
   * **Username**: `admin`
   * **Password**: `YourSecureAdminPassword`
3. Click your user profile icon in the top right-hand corner and choose **Administration settings**.
4. Scroll down the left sidebar menu and click **ONLYOFFICE**.
5. Check the box for **Advanced server settings** and enter these exact server paths to bridge cross-origin loops:
   * **ONLYOFFICE Docs address**: `http://192.168.122`
   * **Secret key**: `YourSuperSecretJWTKeyHere`
   * **ONLYOFFICE Docs address for internal requests from the server**: `http://onlyoffice-docs/`
   * **Nextcloud address for internal requests from the document server**: `http://nextcloud-app/`
6. Click **Save**.

---

## Operational Lifecycle Management Commands

Your stack is now completely automated under systemd. Manage container lifecycles using these native user utilities:

* **Stop the Office Suite**: 
  `systemctl --user stop nextcloud-app onlyoffice-docs nextcloud-db`
* **Start the Office Suite**: 
  `systemctl --user start nextcloud-db onlyoffice-docs nextcloud-app`
* **Restart the Office Suite**: 
  `systemctl --user restart nextcloud-db onlyoffice-docs nextcloud-app`
* **Inspect Live Web Logs**: 
  `journalctl --user -u nextcloud-app.service -f`
