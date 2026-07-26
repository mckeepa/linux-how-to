# As-Built Documentation: Authentik Identity Management Stack with LDAP Integration

This documentation outlines the production architecture, configuration details, and server integration paths for the central identity authentication engine running inside the `gardenofrot.cc` lab infrastructure.

---

## 1. System Architecture Infrastructure Mapping

| Attribute | Component Target Specification |
| :--- | :--- |
| **Hosting Platform** | Proxmox VE Virtual Switch Switch Environment |
| **Container Engine** | Rootless Podman Engine (`/usr/bin/podman-compose`) |
| **LXC Host Container IP**| `192.168.0.123` (Unprivileged Linux Container Environment) |
| **Reverse Proxy Host VM**| `192.168.0.101` (External Nginx Reverse Proxy Server Engine) |
| **Local Subnet Realm**   | `gardenofrot.cc` |
| **Authentication FQDN**  | `https://authentik.gardenofrot.cc` |
| **LDAP Engine Ports**    | Standard TCP Port `3389` (LDAP) / Secure TCP Port `6636` (LDAPS) |

---

## 2. Nginx Reverse Proxy VM Layout (`192.168.0.101`)

The reverse proxy maps incoming encrypted external queries on port `443` straight into Authentik's secure backend container ports via TLS re-encryption bridging paths.

### Active Path Routing Configuration File
File Location: `/etc/nginx/sites-available/authentik.conf` (linked to `/etc/nginx/sites-enabled/`)

```nginx
server {
    listen 80;
    server_name authentik.gardenofrot.cc;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name authentik.gardenofrot.cc;

    ssl_certificate /etc/letsencrypt/live/gardenofrot.cc/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gardenofrot.cc/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass https://192.168.0.123:9443;

        # Disable SSL verification due to internal container self-signed cert structures
        proxy_ssl_verify off;
        proxy_ssl_session_reuse on;
        proxy_ssl_server_name on;

        # Unified header mapping variables
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # Live WebSockets orchestration support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## 3. Podman Container Stack Deployments (`192.168.0.123`)

Because unprivileged containers cannot bind safely to well-known ports below `1024` on the parent host network interface loop, custom non-root system ports (`3389`/`6636`) are implemented. 

### Environmental Variables Definitions (`.env`)
```text
AUTHENTIK_TAG=2026.5.6
POSTGRES_USER=authentik
POSTGRES_DB=authentik
```

### Podman Stack Manifest Configuration (`docker-compose.yaml`)
```yaml
version: "3.4"

services:
  postgresql:
    image: docker.io/library/postgres:16-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d \[{POSTGRES_DB} -U\]{POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      max_retries: 5
      timeout: 5s
    volumes:
      - ./database:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: \${AUTHENTIK_PG_PASS:?error}
      POSTGRES_USER: \${POSTGRES_USER:-authentik}
      POSTGRES_DB: \${POSTGRES_DB:-authentik}

  redis:
    image: docker.io/library/redis:7-alpine
    command: --save 60 1 --loglevel warning
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      max_retries: 5
      timeout: 5s
    volumes:
      - ./redis:/data

  server:
    image: ghcr.io/goauthentik/server:\${AUTHENTIK_TAG:-latest}
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: \${POSTGRES_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: \${POSTGRES_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: \${AUTHENTIK_PG_PASS:?error}
      AUTHENTIK_SECRET_KEY: \${AUTHENTIK_SECRET_KEY:?error}
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
    ports:
      - "8000:8000"
      - "9443:9443"
    depends_on:
      - postgresql
      - redis

  worker:
    image: ghcr.io/goauthentik/server:\${AUTHENTIK_TAG:-latest}
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: \${POSTGRES_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: \${POSTGRES_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: \${AUTHENTIK_PG_PASS:?error}
      AUTHENTIK_SECRET_KEY: \${AUTHENTIK_SECRET_KEY:?error}
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
    depends_on:
      - postgresql
      - redis

  authentik-ldap:
    image: ghcr.io/goauthentik/ldap:\${AUTHENTIK_TAG:-latest}
    restart: unless-stopped
    ports:
      - "3389:3389"
      - "6636:6636"
    extra_hosts:
      - "authentik.gardenofrot.cc:192.168.0.101"
    environment:
      AUTHENTIK_HOST: https://authentik.gardenofrot.cc
      AUTHENTIK_INSECURE: "false"
      AUTHENTIK_TOKEN: "ak-outpost-embedded-token-password-string-goes-here"
```

---

## 4. Authentik Web Configuration Matrix

To successfully pipe directory properties over standard connections, the directory objects require explicit POSIX structuring mapping criteria metadata definitions.

### User Account Attribute Injection Parameters
Navigate to **Directory** ➔ **Users** ➔ **admin-paul** ➔ **Edit** ➔ **Advanced settings** ➔ **Attributes**:
```json
{
  "gidNumber": 10001,
  "uidNumber": 10001,
  "loginShell": "/bin/bash",
  "homeDirectory": "/home/admin-paul"
}
```

### Security Group Mapping Parameters
Navigate to **Directory** ➔ **Groups** ➔ **authentik-admins** ➔ **Edit** ➔ **Advanced settings** ➔ **Attributes**:
```json
{
  "gidNumber": 10001
}
```

### LDAP Provider Interface Mapping Profiles
Navigate to **Applications** ➔ **Providers** ➔ **gardenofrot.cc (Edit)**:
*   **Bind Mode**: `Cached binding`
*   **Search Mode**: `Direct querying` (Bypasses hidden caching loops for live server calls)
*   **Base DN**: `DC=gardenofrot,DC=cc`

---

## 5. Client Target Server Join Execution Matrix

Run these integration configurations on your Linux servers (e.g., Rocky Linux builds) to cleanly join them to your central authentication pool database realm.

### Step 1: Install Directory Client Components
```bash
sudo dnf install sssd sssd-ldap openldap-clients oddjob-mkhomedir -y
```

### Step 2: Establish the Client Daemon Profile Configurations
Create or overwrite the configuration inside `/etc/sssd/sssd.conf`:

```ini
[sssd]
services = nss, pam, sudo
config_file_version = 2
domains = gardenofrot.cc

[domain/gardenofrot.cc]
id_provider = ldap
auth_provider = ldap
ldap_schema = rfc2307bis

# Core Network Pathing Variables
ldap_uri = ldap://192.168.0.123:3389
ldap_search_base = dc=gardenofrot,dc=cc

# System Service Binding Credentials
ldap_bind_dn = cn=ldap-service,dc=gardenofrot,dc=cc
ldap_bind_authtok = <PASSWORD>

# Certificate Authority Bypass Rules For Internal Self-Signed Handshakes
ldap_id_use_start_tls = False
ldap_tls_reqcert = never
cache_credentials = True

# Native Authentik Object Dictionary Key Translations
ldap_user_object_class = posixAccount
ldap_user_name = sAMAccountName
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell

# Automatic Failback Mappings
fallback_homedir = /home/%u
default_shell = /bin/bash
```

### Step 3: Enforce Execution System Security Parameters
```bash
# Secure credential file permissions
sudo chmod 600 /etc/sssd/sssd.conf

# Activate auto home-directory worker modules
sudo systemctl enable --now oddjobd.service

# Clear the identity daemon cache files completely
sudo systemctl stop sssd
sudo rm -rf /var/lib/sss/db/*
sudo rm -rf /var/lib/sss/mc/*

# Fire SSSD server sync services live
sudo systemctl start sssd

# Force system profile authentication policies to accept sssd hooks
sudo authselect select sssd with-mkhomedir --force
```

### Step 4: Validate Operations Execution Paths
Run a live directory check from the machine console terminal:
```bash
getent passwd admin-paul
```
**Expected Output:**
`admin-paul:*:10001:10001:Paul McKee (admin):/home/admin-paul:/bin/bash`
