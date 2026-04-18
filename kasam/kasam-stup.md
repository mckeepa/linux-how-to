This is a complete end-to-end deployment guide for installing Kasm Workspaces on Rocky Linux 10 and integrating it with FreeIPA so that VDI workspace users authenticate using FreeIPA identities.

This assumes:

 - Rocky 10 server for Kasm
 - FreeIPA server already running
 - DNS working between both
 - TLS/LDAPS enabled on FreeIPA

Architecture Overview

Typical architecture:

Users
  │
  ▼
Kasm Web UI (Rocky Linux)
  │
  ├── Docker Workspace Containers
  │
  └── LDAP Authentication
        │
        ▼
      FreeIPA (LDAP / Kerberos)

FreeIPA provides:
 - user authentication
 - group membership
 - identity mapping to workspaces

Kasm acts as:
 - VDI orchestrator
 - container session manager

# Prepare Rocky Linux 10 Server

## Update system:
```bash
sudo dnf update -y
sudo dnf install -y curl wget unzip tar vim
```

Install required utilities:
```bash
sudo dnf install -y \
lsof \
openssl \
policycoreutils \
nc \
firewalld
```
Start firewall:
```bash
sudo systemctl enable --now firewalld
```
# Install Docker

Kasm uses Docker containers for desktops.

## Add Docker repo and Install Docker:

```bash
sudo dnf config-manager --add-repo \
https://download.docker.com/linux/centos/docker-ce.repo
 
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Start Docker:
```bash
sudo systemctl enable docker
sudo systemctl start docker

# Verify:

docker --version
docker compose version
```

# Configure Firewall

Open Kasm ports:
```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=3389/tcp
sudo firewall-cmd --reload
```
# Download Kasm Workspaces

Move to temp directory and Download latest version:
```bash

cd /tmp

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.18.1.tar.gz

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.18.1.tar.gz

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.18.1.tar.gz

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_network_plugin_images_amd64_1.18.1.tar.gz

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_logging_plugin_images_amd64_1.18.1.tar.gz



tar -xf kasm_release_1.18.1.tar.gz

sudo bash kasm_release/install.sh --offline-workspaces /tmp/kasm_release_workspace_images_amd64_1.18.1.tar.gz --offline-service /tmp/kasm_release_service_images_amd64_1.18.1.tar.gz --offline-network-plugin /tmp/kasm_release_network_plugin_images_amd64_1.18.1.tar.gz --offline-logger-plugin /tmp/kasm_release_logging_plugin_images_amd64_1.18.1.tar.gz


# -----------------------------------
cd /tmp

curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_latest.tar.gz

# Extract:

tar -xf kasm_release_latest.tar.gz
cd kasm_release*
```
# Install Kasm

```bash 

  https://kasm-static-content.s3.amazonaws.com/kasm_release_1.18.1.tar.gz?hsCtaAttrib=199942409299

```

Run unattended install:
```bash
sudo bash install.sh --accept-eula
```

Installer will:

 - create /opt/kasm
 - configure services
 - install Docker images
 - generate credentials

At the end you will see:
```text
Kasm UI: https://SERVER_IP
Admin: admin@kasm.local
Password: ********

Save the password.
```

# Access the Kasm Admin UI

## Open browser:

https://SERVER_IP
https://192.168.122.228/

## Login using:

admin@kasm.local

# Install Workspace Images

Go to:   Admin → Workspaces → Registry

Install base images such as:

 - Ubuntu Desktop
 - Debian Desktop
 - Chrome
 - Firefox

These run as Docker containers.

## Prepare FreeIPA for Kasm LDAP

On the FreeIPA server create a service account for Kasm.

Example:

ipa user-add kasmldap \
--first=Kasm \
--last=Service \
--password

Create group for VDI users:
```bash
ipa group-add kasm-users

# Add users:
ipa group-add-member kasm-users --users user1

```
Determine your LDAP base:

Example:

dc=example,dc=lab

Typical FreeIPA DN format:

uid=user1,cn=users,cn=accounts,dc=example,dc=lab

# Test LDAP Connectivity

From the Kasm server install LDAP tools:
```bash 
sudo dnf install -y openldap-clients
```
Test LDAP bind:

ldapsearch -x \
-H ldaps://ipa.example.lab \
-D "uid=kasmldap,cn=users,cn=accounts,dc=example,dc=lab" \
-W \
-b "cn=users,cn=accounts,dc=example,dc=lab"

If this works, Kasm will work.

10. Configure LDAP Authentication in Kasm

Login to Kasm Admin UI.

Navigate:

Access Management
Authentication
LDAP
Add Configuration

Enter:

Name

FreeIPA LDAP

URL

ldaps://ipa.example.lab:636

Search Base

cn=users,cn=accounts,dc=example,dc=lab

Search Filter

(&(objectClass=posixAccount)(uid={0}))

Group Membership Filter

(&(objectClass=groupOfNames)(member={0}))

Email Attribute

mail

Service Account DN

uid=kasmldap,cn=users,cn=accounts,dc=example,dc=lab

Enable:

Search Subtree
Auto Create App User
Enabled

Kasm supports external authentication providers like LDAP so organizations can use existing directory services for authentication and authorization.

# Map FreeIPA Groups to Kasm Groups

Create group mapping.

Navigate:

Access Management
Groups

Create group:

FreeIPA Users

Then add SSO mapping:

SSO Provider: FreeIPA LDAP
Group Attributes:
cn=kasm-users,cn=groups,cn=accounts,dc=example,dc=lab

Users in that group will automatically gain access.

# Configure Workspace Permissions

Assign workspace access to group.

Example:

Admin → Workspaces
Ubuntu Desktop
Edit
Permissions

Add:

FreeIPA Users
# Test FreeIPA Login

Log out of admin account.

Login using FreeIPA user:

user1@example.lab

Kasm should:

authenticate via LDAP

create a user profile

assign workspace permissions

# Ensure Workspace Sessions Use LDAP Identity

You can expose the LDAP username inside containers using environment variables.

Edit workspace config:

Admin
Workspaces
Edit Workspace
Docker Run Config

Add:

-e USERNAME={username}
-e EMAIL={email}

This lets containers know which LDAP user launched them.

# Join Containers to FreeIPA Domain

For full Linux desktop identity integration.

Build custom workspace image.

Example Dockerfile:

FROM kasmweb/ubuntu-desktop:1.15.0

RUN apt update && \
apt install -y freeipa-client


During container startup run:

ipa-client-install

This allows:

Kerberos login

SSSD identity resolution

FreeIPA home directories

# Verify Running Services

Check Kasm containers:

docker ps

Check logs:

```bash
docker logs kasm_api
```

# Security Hardening (Recommended)

Disable default user accounts except admin.

Kasm recommends using an external identity provider such as LDAP instead of relying on local accounts.

# Useful Admin Commands

Restart Kasm stack:

sudo systemctl restart docker

Check API logs:

docker logs kasm_api
Final Result

Users will:

open Kasm web portal

authenticate with FreeIPA credentials

launch VDI workspace

run isolated container session

Authentication, user groups, and permissions come from FreeIPA.


# Docker File - jumpbox

```Dockerfile
FROM kasmweb/core-ubuntu-jammy:1.18.0-rolling-daily
USER root

# Set the seeding directory for new user profiles
ENV HOME /home/kasm-default-profile
WORKDIR $HOME

# 1. Install Jumpbox Tools & FreeIPA Client
# We install remmina (with RDP/SSH plugins) and firefox
RUN apt-get update && apt-get install -y --no-install-recommends \
    remmina \
    remmina-plugin-rdp \
    remmina-plugin-ssh \
    firefox \
    openssh-client \
    freeipa-client \
    dnsutils \
    iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Create Desktop Shortcuts in the seeding profile
# Kasm copies contents from kasm-default-profile to the user's home on first launch
RUN mkdir -p $HOME/Desktop && \
    cp /usr/share/applications/remmina.desktop $HOME/Desktop/ && \
    cp /usr/share/applications/firefox.desktop $HOME/Desktop/

# 3. Hardening: Remove risky tools and restrict binary permissions
# We remove common tools often used in lateral movement
RUN apt-get purge -y wget curl git && \
    apt-get autoremove -y && \
    chmod 700 /usr/bin/ssh

# 4. Set ownership for the Kasm seeding process
RUN chown -R 1000:0 $HOME && \
    find $HOME/Desktop/ -name "*.desktop" -exec chmod +x {} \;

# Revert to standard user for the running container
ENV HOME /home/kasm-user
WORKDIR $HOME
USER 1000

```

```bash
docker images -a
sudo docker images -a
sudo docker run --rm -it custom-jumpbox:v1 /bin/bash
sudo docker build --load -t custom-jumpbox:v1 .
sudo docker images | grep custom-jumpbox
docker buildx ls
sudo docker buildx ls
sudo docker build --output type=docker -t custom-jumpbox:v1 .
sudo docker images
sudo docker system info | grep -i "Data Space"
sudo docker system info
sudo systemctl restart docker
sudo docker images
sudo docker build --output type=docker -t custom-jumpbox:v1 .
sudo docker images
sudo docker restart kasm_agent
sudo reboot now
top
sudo docker images
sudo docker images -a
ls
vi dockerfile
sudo docker build --load -t custom-jumpbox:v1 .
sudo shutdown now
sudo dnf update

  ```