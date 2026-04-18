1. Set Up a Persistent Database 
Keycloak requires a production-grade external database like PostgreSQL for data persistence. 

    Create a dedicated network:
    bash

    podman network create keycloak-net

    Use code with caution.


    Deploy PostgreSQL:
bash

podman run -d \
  --replace \
  --name keycloak-db \
  --net keycloak-net \
  -v keycloak-db-data:/var/lib/postgresql/data:Z \
  -e POSTGRES_DB=keycloak \
  -e POSTGRES_USER=keycloak \
  -e POSTGRES_PASSWORD=your_secure_db_password \
  postgres:16

Use code with caution.
Note: The :Z flag on the volume mount ensures correct SELinux permissions on Fedora. 

2. Prepare SSL/TLS Certificates
Production mode enforces HTTPS. You must provide a valid certificate (server.crt) and private key (server.key). 

    Location: Place these in a directory on your host, e.g., /etc/keycloak/certs/.
    Permissions: Ensure the container user can read these files. 
```bash 
#on KeyClock Server
hostnme

ip a

# on IPA IdM sever
ssh freeipa.ga
rdenofrot.cc

kinit admin

ipa dnsrecord-add gardenofrot.cc keycloak --a-rec=192.168.122.82

ipa service-add HTTP/keycloak.gardenofrot.cc

dig keycloak.gardenofrot.cc


ipa service-add HTTP/keycloak.gardenofrot.cc
```

## On Web Server (KeyCloak)

The following command generates a new private key and requests the certificate from the FreeIPA CA.
 -K: The Kerberos principal for the service.
 -k: Path where the private key will be stored.
 -f: Path where the issued certificate will be stored.
 -D: The DNS Subject Alternative Name (SAN).

```bash
sudo ipa-getcert request \
  -K HTTP/keycloak.gardenofrot.cc \
  -k /etc/pki/tls/private/keycloak/keycloak.gardenofrot.cc.key \
  -f /etc/pki/tls/private/keycloak/keycloak.gardenofrot.cc.crt \
  -D keycloak.gardenofrot.cc
 
sudo chgrp -R keycloak-admins /etc/pki/tls/private/keycloak
sudo chmod -R 775 /etc/pki/tls/private/keycloak
sudo chmod g+s /etc/pki/tls/private/keycloak


```

# Setup svc-keycloak

```bash
ipa user-del svc_keycloak
```

```bash

ldapmodify -x -D "cn=Directory Manager" -W <<EOF
dn: uid=svc_keycloak,cn=sysaccounts,cn=etc,dc=gardenofrot,dc=cc
changetype: add
objectclass: account
objectclass: simplesecurityobject
uid: svc_keycloak
userPassword: YOUR_SECURE_PASSWORD
passwordExpirationTime: 20380119031407Z
nsIdleTimeout: 0
EOF
```

Verify account
```bash
ldapsearch -x -D "uid=svc_keycloak,cn=sysaccounts,cn=etc,dc=gardenofrot,dc=cc" -W -b "dc=gardenofrot,dc=cc" -s base "(objectclass=*)"

```

ipa role-add --desc="Read-Only Access for Keycloak" keycloak-role
ipa role-add-privilege keycloak-role --privilege="Read All User Entries"
# no command 'user-add-role'
#ipa user-add-role svc_keycloak --roles=keycloak-role
ipa role-add-member keycloak-role --users=svc_keycloak
```

3. Launch Keycloak in Production Mode
Use the start command instead of start-dev. You must also run a build step first if you change build-time options like the database type. 
```bash

podman run -it \
  --replace \
  --name keycloak-app \
  --net keycloak-net \
  -p 8443:8443 \
  -v ~/keycloak-certs:/opt/keycloak/conf/truststore:Z \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=your_secure_admin_password \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://keycloak-db:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=your_secure_db_password \
  -e KC_HOSTNAME=keycloak.gardenofrot.cc \
  -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/truststore/keycloak.gardenofrot.cc.crt \
  -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/truststore/keycloak.gardenofrot.cc.key \
  -e KC_TRUSTSTORE_PATHS=/opt/keycloak/conf/truststore/ca.crt \
  quay.io/keycloak/keycloak:latest \
  start --http-enabled=false
  start --optimized
```


## Production Configuration Summary
### Requirement 
	Production Setting	Reason

    - Command	start --optimized	Disables development features and uses pre-built config.
    - Hostname	KC_HOSTNAME	Required for secure cookie handling and token issuance.
    - HTTPS	Port 8443 (default)	Plain HTTP is disabled by default in production mode.
    - Database	External (PostgreSQL/MySQL)	Essential for high availability and data integrity.
    - Proxy	KC_PROXY	Set to edge, reencrypt, or passthrough if using a reverse proxy.

## Next Steps for Security

    Reverse Proxy: It is a best practice to run Keycloak behind a reverse proxy like Nginx or Apache to handle public traffic and certificate renewal (e.g., via Let's Encrypt).

    Resource Limits: Limit CPU and memory usage for the container to prevent a single instance from starving the host.
    Systemd Integration: Use Quadlet or podman generate systemd to ensure Keycloak starts automatically on boot. 


## Server cli history

```bash
sudo cat /etc/hostname
sudo hostnamectl set-hostname --pretty "keycloak.gardenofrot.cc"
sudo hostnamectl set-hostname --static "keycloak.gardenofrot.cc"
sudo firewall-cmd --state
sudo ipa-client-install --mkhomedir --domain gardenofrot.cc --server freeipa.gardenofrot.cc 

sudo ipa-client-install --uninstall
sudo ipa-client-install --mkhomedir --domain gardenofrot.cc --server freeipa.gardenofrot.cc 

exit
whoami
id
sudo yum install ipa-client
ls
sudo dnf update
sudo dnf upgrade
podman network list
hostname
podman
sudo dnf upgrade -y
sudo dnf install -y podman slirp4netns fuse-overlayfs
grep "$USER" /etc/subuid
grep "$USER" /etc/subgid
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
grep "$USER" /etc/subgid
grep "$USER" /etc/subuid
podman run --rm hello-world
podman info --format '{{.Host.Security.Rootless}}'
mkdir -p ~/.config/containers
cat << 'EOF' > ~/.config/containers/storage.conf
  [storage]
  driver = "overlay"
  [storage.options.overlay]
  mount_program = "/usr/bin/fuse-overlayfs"
  EOF
```
```bash
podman system migrate
podman network create keycloak-net
podman run -d   --name keycloak-db   --net keycloak-net   -v keycloak-db-data:/var/lib/postgresql/data:Z   -e POSTGRES_DB=keycloak   -e POSTGRES_USER=keycloak   -e POSTGRES_PASSWORD=your_secure_db_password   postgres:16
  
podman run -d   --name keycloak-app   --net keycloak-net   -p 8443:8443   -v /etc/keycloak/certs:/opt/keycloak/conf/truststore:Z   -e KEYCLOAK_ADMIN=admin   -e KEYCLOAK_ADMIN_PASSWORD=your_secure_admin_password   -e KC_DB=postgres   -e KC_DB_URL=jdbc:postgresql://keycloak-db:5432/keycloak   -e KC_DB_USERNAME=keycloak   -e KC_DB_PASSWORD=your_secure_db_password   -e KC_HOSTNAME=sso.example.com   -e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/truststore/server.crt   -e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/truststore/server.key   quay.io/keycloak/keycloak:latest   start --optimized
  
sudo shutdown
```
