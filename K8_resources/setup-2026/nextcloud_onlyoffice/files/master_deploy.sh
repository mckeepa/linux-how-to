#!/bin/bash
set -e

echo "========================================================================="
echo "🚀 STARTING MASTER DEPLOYMENT: SOVEREIGN DIGITAL WORKSPACE"
echo "========================================================================="

# 1. Establish absolute systemd environment linkages for Debian 13
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Cache sudo credentials upfront so the script runs unattended
sudo -v

# 2. Check for required local static configuration files
FILES=("nextcloud-db.container" "onlyoffice-docs.container" "nextcloud-app.container")
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "   [!] Error: Critical file '$file' missing from working directory." >&2
        echo "       Please execute ./step4_quadlets.sh once to populate static assets." >&2
        exit 1
    fi
done

# 3. Sequential Orchestration Pipeline
echo ""
echo "👉 Running Step 3: Initializing Storage Infrastructure..."
./step3_storage.sh

echo ""
echo "👉 Running Step 4: Compiling & Syncing Quadlet Service Matrix..."
./step4_quadlets.sh

echo ""
echo "👉 Running Step 5: Provisioning Domain Whitelists & Extension Engine..."
./step5_integration.sh

echo ""
echo "👉 Running Step 6: Finalizing Cryptographic Application Handshakes..."
./step6_linkage.sh

echo ""
echo "========================================================================="
echo "🎉 SUCCESS: Environment is fully operational and tracked in version control!"
echo "========================================================================="
podman ps