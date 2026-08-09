#!/bin/bash
set -e

echo "=== [Step 3] Initializing Podman Volume Infrastructure ==="

# Cache sudo credentials upfront so the script runs unattended
sudo -v

echo "-> Configuring Debian rootless sub-UID namespaces..."
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER || true
podman system migrate

# List of required volumes
VOLUMES=("nc-db-data" "nc-app-data" "nc-app-config" "oo-data" "oo-logs")

# 1. Destructive check and initialization loop
echo "-> Provisioning Podman volumes (Wiping existing data if found)..."
for vol in "${VOLUMES[@]}"; do
    if podman volume exists "$vol"; then
        echo "   [!] Volume '$vol' already exists. Purging and resetting..."
        podman volume rm -f "$vol"
    fi
    podman volume create "$vol"
done

# 2. Extract physical host volume mount directory points
echo "-> Extracting volume mountpoints..."
CONFIG_PATH=$(podman volume inspect nc-app-config --format '{{.Mountpoint}}')
DATA_PATH=$(podman volume inspect nc-app-data --format '{{.Mountpoint}}')

# 3. Shift directory execution permissions to UID 33 (www-data) inside rootless space
echo "-> Realignment of user namespaces for Nextcloud internal engines..."
podman unshare chown -R 33:33 "$CONFIG_PATH"
podman unshare chown -R 33:33 "$DATA_PATH"

echo "=== [Step 3] Storage infrastructure deployed cleanly! ==="