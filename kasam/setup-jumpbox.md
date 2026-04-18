# Hardened Jumpbox Dockerfile

This Dockerfile uses the official Kasm Ubuntu Focal core as a base. It removes unnecessary tools, installs only required management utilities (SSH, ipa-client), and enforces a non-root user.

Dockerfile
```Dockerfile
# Start from Kasm official Ubuntu base
FROM kasmweb/core-ubuntu-jammy:1.18.0-rolling-daily
#FROM kasmweb/core-ubuntu-focal:1.17.0-rolling

USER root
# Install essential jumpbox tools (ssh, freeipa, net tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client freeipa-client dnsutils iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Harden: Remove tools like wget, curl, git to limit potential exploit paths
RUN apt-get purge -y wget curl git && apt-get autoremove -y

# Restrict permissions
RUN chmod 700 /usr/bin/ssh

# Finalize image as non-root
USER 1000

```

Dockerfile 2
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
## Build

```bash 
sudo docker build -t custom-jumpbox:v1 .
```

```Dockerfile
FROM kasmweb/core-ubuntu-jammy:1.18.0-rolling-daily
USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
WORKDIR $HOME

# 1. Install Jumpbox Tools & FreeIPA Client
RUN apt-get update && apt-get install -y --no-install-recommends \
    remmina \
    remmina-plugin-rdp \
    remmina-plugin-secret \
    firefox \
    openssh-client \
    freeipa-client \
    dnsutils \
    iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Create Desktop Shortcuts (Safe Loop)
# This finds the first available .desktop file for each tool
RUN mkdir -p $HOME/Desktop && \
    find /usr/share/applications/ -name "*remmina*.desktop" -exec cp {} $HOME/Desktop/remmina.desktop \; -quit && \
    find /usr/share/applications/ -name "*firefox*.desktop" -exec cp {} $HOME/Desktop/firefox.desktop \; -quit

# 3. Hardening for FreeIPA Jumpbox
# Remove tools that could bypass security or exfiltrate data
RUN apt-get purge -y wget curl git && \
    apt-get autoremove -y && \
    chmod 700 /usr/bin/ssh

# 4. Finalise Profile Permissions
RUN chown -R 1000:0 $HOME && \
    find $HOME/Desktop/ -name "*.desktop" -exec chmod +x {} \;

# Revert to standard user for runtime
ENV HOME=/home/kasm-user
WORKDIR $HOME
USER 1000


```

# Create the Template in Kasm

## Add Workspace: 
In Admin UI, go to Workspaces > Add (Type: Container, Image: custom-jumpbox:v1).
Assign: Assign the workspace to authorized FreeIPA user groups. 

## Hardening the Workspace (Lockdown)
In the Edit Workspace panel, apply these settings:
 - Data Transfer: Disable Upload and Download to restrict file exfiltration.
 - Clipboard: Set to None or Inbound-only.
 - Networking: Use Docker Run Config to set cap_drop: ["ALL"] and ensure network isolation.
 - Access Control: Utilise Web Filtering for domain allowlist and configure strict session time limits.




## Hardening for FreeIPA Users
Since your users are coming from FreeIPA, the workspace should be restricted to prevent "living off the land" attacks:

## Restrict the Shell: 
In the Kasm Workspace settings, you can set the Docker Run Config Override to use a restricted shell if they only need CLI tools, though standard bash is usually fine if sudo is disabled.

## Immutability: 
Ensure Persistent Profiles is turned ON so users can save their Remmina connections, but keep Allow Sudo turned OFF.

## App Armor / Seccomp:
Ensure the Kasm Agent host has AppArmor enabled. Kasm applies a default profile that prevents containers from accessing sensitive host syscalls.


## SSO Login: 
When setting up the Workspace in Kasm, use the following Docker Config JSON to automatically pass the FreeIPA username into the container environment:
```json
{"env": {"USER": "{username}", "KASM_USER": "{username}"}}
```

Build Command:
```bash
sudo docker build --load -t custom-jumpbox:v1 .
```
