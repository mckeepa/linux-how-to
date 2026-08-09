#!/bin/bash
set -e

echo "=== [Step 4] Orchestrating Quadlet Deployment & Lifecycle ==="

# 1. Establish systemd environment linkages for Debian 13
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

TARGET_DIR="${HOME}/.config/containers/systemd"
FILES=("nextcloud-net.network" "nextcloud-db.container" "onlyoffice-docs.container" "nextcloud-app.container")

# =========================================================================
# 2. GENERATE STATIC CONFIGURATION FILES (With Fixed Debian Dependencies)
# =========================================================================
echo "-> Generating static Quadlet configuration files locally..."

# 1. Network definition
cat << 'LOCAL_EOF' > nextcloud-net.network
[Unit]
Description=Sovereign Nextcloud Cloud Network Mesh

[Network]
NetworkName=nextcloud-net
LOCAL_EOF

# 2. PostgreSQL Database definition (Fixed dependency string name)
cat << 'LOCAL_EOF' > nextcloud-db.container
[Unit]
Description=Nextcloud PostgreSQL Database
After=nextcloud-net-network.service
Requires=nextcloud-net-network.service

[Container]
ContainerName=nextcloud-db
Image=docker.io/library/postgres:15-alpine
Network=nextcloud-net

Volume=nc-db-data:/var/lib/postgresql/data:Z
# Load sensitive values from user-scoped env file: %h/.config/nextcloud/secrets.env
EnvironmentFile=%h/.config/nextcloud/secrets.env
Environment=POSTGRES_DB=nextcloud POSTGRES_USER=nextcloud_user POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

[Install]
WantedBy=default.target
LOCAL_EOF

# 3. ONLYOFFICE Document Server definition (Fixed dependency string name)
cat << 'LOCAL_EOF' > onlyoffice-docs.container
[Unit]
Description=ONLYOFFICE Document Server
After=nextcloud-net-network.service
Requires=nextcloud-net-network.service

[Container]
ContainerName=onlyoffice-docs
Image=docker.io/onlyoffice/documentserver:latest
Network=nextcloud-net
PublishPort=8081:80
Volume=oo-data:/var/www/onlyoffice/Data:Z
Volume=oo-logs:/var/log/onlyoffice:Z
# Load JWT secret from user-scoped env file: %h/.config/nextcloud/secrets.env
EnvironmentFile=%h/.config/nextcloud/secrets.env
Environment=JWT_ENABLED=true JWT_SECRET=${JWT_SECRET} JWT_HEADER=Authorization

[Install]
WantedBy=default.target
LOCAL_EOF

# 4. Nextcloud Core App Engine definition (Fixed dependency string name)
cat << 'LOCAL_EOF' > nextcloud-app.container
[Unit]
Description=Nextcloud Application Server
After=nextcloud-net-network.service nextcloud-db.service onlyoffice-docs.service
Requires=nextcloud-net-network.service

[Container]
ContainerName=nextcloud-app
Image=docker.io/library/nextcloud:stable
Network=nextcloud-net
PublishPort=8080:80
Volume=nc-app-data:/var/www/html:Z
Volume=nc-app-config:/var/www/html/config:Z
# Load DB and admin passwords from user-scoped env file: %h/.config/nextcloud/secrets.env
EnvironmentFile=%h/.config/nextcloud/secrets.env
Environment=POSTGRES_HOST=nextcloud-db POSTGRES_DB=nextcloud POSTGRES_USER=nextcloud_user POSTGRES_PASSWORD=${POSTGRES_PASSWORD} NEXTCLOUD_ADMIN_USER=admin NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}

[Install]
WantedBy=default.target
LOCAL_EOF

# =========================================================================
# 3. DEPLOYMENT AND SERVICE LIFECYCLE MANAGEMENT
# =========================================================================

# Stop previous failed service iterations to clear execution locks
echo "-> Hard stopping old environment stacks..."
systemctl --user stop nextcloud-app.service onlyoffice-docs.service nextcloud-db.service 2>/dev/null || true
systemctl --user reset-failed 2>/dev/null || true

# Refresh target configuration directory paths
echo "-> Syncing layout files to systemd user paths..."
mkdir -p "$TARGET_DIR"
for file in "${FILES[@]}"; do
    cp "$file" "$TARGET_DIR/"
done

# Compile definitions into active systemd services
echo "-> Re-compiling systemd user service structures..."
systemctl --user daemon-reload

# Launch the fully compiled application stack sequentially
echo "-> Launching backend engine stacks..."
systemctl --user start nextcloud-db.service onlyoffice-docs.service

echo "-> Mounting nextcloud frontend interface..."
systemctl --user start nextcloud-app.service

echo "=== [Step 4] Quadlet environment deployed and started cleanly! ==="