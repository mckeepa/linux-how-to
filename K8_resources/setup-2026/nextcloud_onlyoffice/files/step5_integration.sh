#!/bin/bash
set -e

echo "=== [Step 5] Initializing Stack & Injecting Proxy Rules ==="

# 1. Establish absolute systemd environment linkages for Debian 13
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# 2. Part 5: Refresh context and start up the full environment stack cleanly
echo "-> Refreshing systemd user context structures..."
systemctl --user daemon-reload

echo "-> Spawning service definitions..."
systemctl --user start nextcloud-db.service onlyoffice-docs.service nextcloud-app.service

echo "-> Pausing for 30 seconds to let database table migrations settle..."
sleep 30

# 3. Dynamic Loop: Wait until Nextcloud's core interface is completely ready for configurations
echo "-> Checking Nextcloud command-line availability..."
for i in {1..30}; do
    if podman exec -u www-data nextcloud-app php occ status >/dev/null 2>&1; then
        echo "   [+] Nextcloud engine is ready for configurations."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "   [!] Error: Nextcloud failed to initialize within expected timeframes." >&2
        exit 1
    fi
    echo "   [-] Waiting for internal container installation loops (Attempt $i/30)..."
    sleep 5
done

# =========================================================================
# Part 6: Reverse Proxy Integration & Domain Whitelisting
# =========================================================================

# 1. Allow ONLYOFFICE to query across private container networks
echo "-> Modifying ONLYOFFICE cross-origin private network query rules..."
podman exec -it onlyoffice-docs sed -i 's/"allowPrivateIPAddress": false/"allowPrivateIPAddress": true/g' /etc/onlyoffice/documentserver/default.json
podman exec -it onlyoffice-docs supervisorctl restart all > /dev/null

# 2. Grant Nextcloud authorization to route local backend loops
echo "-> Allowing Nextcloud to make local internal network calls..."
podman exec -u www-data nextcloud-app php occ config:system:set allow_local_remote_servers --value=true --type=boolean

# 3. Add the Reverse Proxy IP (192.168.0.101) to Nextcloud Trusted Proxies
echo "-> Whitelisting nginx-proxy (192.168.0.101) as a trusted gateway..."
podman exec -u www-data nextcloud-app php occ config:system:set trusted_proxies 0 --value="192.168.0.101"

# 4. Whitelist both local IP paths and the external domain strings
echo "-> Binding trusted local and public domains..."
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 1 --value="192.168.0.116"
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 2 --value="nextcloud.gardenofrot.cc"
podman exec -u www-data nextcloud-app php occ config:system:set trusted_domains 3 --value="office.gardenofrot.cc"

# 5. Tell Nextcloud to pass web headers correctly through SSL
echo "-> Enforcing SSL proxy headers and routing overwrite flags..."
podman exec -u www-data nextcloud-app php occ config:system:set overwritehost --value="nextcloud.gardenofrot.cc"
podman exec -u www-data nextcloud-app php occ config:system:set overwriteprotocol --value="https"

# 6. Fetch and deploy the official ONLYOFFICE plugin bundle straight into Nextcloud
echo "-> Injecting ONLYOFFICE workspace extension module (Downloading)..."
podman exec -it -u www-data nextcloud-app php occ app:install onlyoffice

echo "=== [Step 5] Script orchestration complete! Environment fully integrated. ==="