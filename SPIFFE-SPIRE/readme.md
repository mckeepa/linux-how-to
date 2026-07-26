# Secure Applications - SPIFFE using SPIRE 


## Staring startment

I have Windows IIS servers currently running hosted on-premises. Certificate rotation every few hours seems reasonable. I have not used SPIRE or Envoy proxy before. I'd like to prove the technology stack, by building a simple set of services that run in a podman container, on a rocky linux server, a windows service running in a local vm, and then add an Azure service. I want to do this proof of concept in an interactive process so I can document each step so that I can build out a design that can be used by technical staff if the testing works to a level that would be suitable for production systems and to be maintainable/sustainable into the future.
—-----------------------------------------------------------------------------------------------------------------


Because SPIRE and Envoy have distinct concepts, this will be built out incrementally, step by step. 

To ensure this PoC matches your long-term goal of a production-ready, sustainable design, the build will use a 4-Phase Roadmap:

## The PoC Delivery Roadmap

1. Phase 1: The Core Control Plane (Local Linux)
Set up a Rocky Linux host.
Deploy the Central SPIRE Server.
Run a Podman container acting as a local microservice.
Issue the first automated X.509 certificate rotation loop.

1. Phase 2: Extending to Windows (Local VM)
Install the SPIRE Agent on a Windows Server VM.
Configure Windows Node Attestation.
Bind a local Windows Service (simulating IIS) to the SPIRE identity loop.

1. Phase 3: The Data Plane (Envoy Proxies & FortiGate Mock)
Introduce Envoy sidecars next to Podman and Windows.
Enforce local mutual TLS (mTLS) traffic between them.
Route traffic through a mock integration zone proxy (simulating your FortiGate/IBM Gateway).

1. Phase 4: Cloud Bridging (Azure Integration)
Connect an Azure VM or Service into the central SPIRE trust bundle using Azure Managed Identities (MSI).

#  Phase 1, Step 1: Setting up the Linux Environment
To make this sustainable for your technical staff, we will avoid complex container orchestrators for the control plane and deploy SPIRE as standard Linux system services.

## Prepare the Rocky Linux Host
Log into your Rocky Linux machine and ensure you have the required utilities installed:
```bash
# Update the system and install curl, tar, and podman
sudo dnf update -y
sudo dnf install -y curl tar podman
```

## Download and Install SPIRE
Download the official SPIRE binaries and place them into standard Linux system directories (/opt/spire).

```bash
# Create directories for SPIRE installation and configurations

sudo mkdir -p /opt/spire/bin /opt/spire/conf /opt/spire/data/server
# Download the latest stable SPIRE release (Linux amd64)
cd /tmp
# curl -L -O https://github.com
curl -L -O https://github.com/spiffe/spire/releases/download/v1.15.1/spire-1.15.1-linux-amd64-musl.tar.gz

# Extract and move the binaries to our opt directory
tar -zxvf spire-1.15.1-linux-amd64-musl.tar.gz

# only needed on the Server
sudo cp spire-1.15.1/bin/spire-server /opt/spire/bin/

# only needed on the Client Agent
sudo cp spire-1.15.1/bin/spire-agent /opt/spire/bin/

# Clean up temporary files
rm -rf spire-1.*
```

## Create the SPIRE Minimal Server Configuration
Configure the central server. 

For the initial local step, a built-in token-based node attestor will be used (**switch to TPM/Azure later**) and set the data directory.

Create the server configuration file at ***/opt/spire/conf/server.conf***:

```bash
sudo vi /opt/spire/conf/server.conf
```

```yaml
server {
    # Allow any traffic to register
    bind_address = "0.0.0.0"
    # Default is 9081
    bind_port = "9081"
    trust_domain = "poc.internal"
    data_dir = "/opt/spire/data/server"
    log_level = "DEBUG"
    # Setting up the certificate rotation configuration
    ca_subject = {
        country = ["AU"],
        organization = ["PoC Corp"],
        common_name = "PoC Root CA",
    }
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "/opt/spire/data/server/datastore.sqlite3"
        }
    }
    NodeAttestor "join_token" {}
    KeyManager "disk" {
        plugin_data {
            keys_path = "/opt/spire/data/server/keys.json"
        }
    }
}
```

## Launch the SPIRE Server
For this first interactive test, run the server directly in the terminal to see how it initialises the database, creates the root keys, and awaits agent connections.

```bash
# Start the SPIRE server in the foreground
sudo /opt/spire/bin/spire-server run -config /opt/spire/conf/server.conf
```

The server command above should starte the SPIRE Server Service for SPIFFE. 
The log messages indicating that the SQLite database has been successfully initialised, the poc.internal trust domain has been established, and the server is listening on port 8081.


# Join Client Agent 
Generate a one-time secure Join Token from the server, configure the local SPIRE Agent, and execute the node attestation handshake

## Phase 1, Step 2: Running the Local SPIRE Agent
Keep the current server terminal running with the SPIRE Server Service running. 

Go to a second Server, open a terminal window on  Linux host to execute the following steps.

### Generate the Join Token on the Server Host
Request the SPIRE Server to generate a unique token. The agent will use this token to prove its initial identity. 
Tell the server that this token is specifically for our Rocky Linux node.

```bash
# Generate a token with a specific Node SPIFFE ID
# Note: You may need to run this as root/sudo depending on your installation path permissions

# sudo /opt/spire/bin/spire-server \
#   -config /opt/spire/conf/server.conf \
#   -spiffeID spiffe://poc.internal/spire/agent/$NEW_HOSTNAME \
#   token generate

# /opt/spire/bin/spire-server token generate -spiffeID spiffe://poc.internal/spire/agent/$NEW_HOSTNAME

# sudo -E /opt/spire/bin/spire-server \
#     token generate 
#     -spiffeID spiffe://poc.internal/manual/ \
#     $NEW_HOSTNAME

sudo -E /opt/spire/bin/spire-server token generate \
  -spiffeID spiffe://poc.internal/manual/$HOSTNAME \
  -ttl 1800
```

Copy the output string exactly. 
It will look like this: 
```bash
Token: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
Token: a9dc89dd-696e-4559-acd7-fa5bd3ce9873
spiffeID = a9dc89dd-696e-4559-acd7-fa5bd3ce9873


SPIFFE_ID='90364f46-48dc-467c-a94a-dc0452778998'
SPIFFE_ID='a9dc89dd-696e-4559-acd7-fa5bd3ce9873'
echo $SPIFFE_ID
a9dc89dd-696e-4559-acd7-fa5bd3ce9873
```

## Create the SPIRE Agent Configuration
Next step is to tell the agent how to talk to the server and what identity mechanism to use.

Create directories for the agent's runtime files:
```bash 
sudo mkdir -p /opt/spire/conf /opt/spire/data/agent
# Open Firewall
# Add the port to the public zone permanently 
sudo firewall-cmd --permanent --zone=public --add-port=9081/tcp 
# Reload the firewall to apply the changes 
sudo firewall-cmd --reload
```

Create the agent configuration file at /opt/spire/conf/agent.conf. 

```bash
sudo vi /opt/spire/conf/agent.conf
```
Paste the following text into it:
```yaml
Server_address:192.168.122.199
    server_address = "192.168.122.199"

agent {
    data_dir = "/opt/spire/data/agent"
    log_level = "DEBUG"
    server_address = "192.168.122.1999"
    server_port = "9081"
    trust_domain = "poc.internal"
    # Add this line to explicitly declare the socket path 
    socket_path = "/opt/spire/data/agent/public/api.sock"
}

plugins {
    NodeAttestor "join_token" {}
    KeyManager "disk" {
        plugin_data {
            directory = "/opt/spire/data/agent"
        }
    }
    WorkloadAttestor "unix" {}
}
```

### Create the parent directories: 
Ensure the target folder paths exist and have correct permissions so SPIRE can generate the file:
```bash 
sudo mkdir -p /opt/spire/data/agent/public
```

Start the agent: Run start command again.
Verify the socket: Test that the agent is successfully hosting the Workload API on that path:

```bash
sudo /opt/spire/bin/spire-agent healthcheck -socketPath /opt/spire/data/agent/public/api.sock
```

### Launch the SPIRE Agent
Now start the agent in the foreground, passing it the configuration file and the exact token you copied from Step 1.

```bash
sudo /opt/spire/bin/spire-server bundle show > /tmp/root-bundle.crt

# Copy that /tmp/root-bundle.crt file over to your Agent machine (e.g., place it at /opt/spire/conf/root-bundle.crt).
sudo cp /tmp//root-bundle.crt /opt/spire/conf/root-bundle.crt
scp  /tmp//root-bundle.crt  


#Replace <YOUR_GENERATED_TOKEN> with the token from your output:

sudo /opt/spire/bin/spire-agent run \
  -config /opt/spire/conf/agent.conf \
  -joinToken $SPIFFE_ID \
  -trustBundle /opt/spire/conf/root-bundle.crt
```

### Restart without -joinToken
```bash
sudo /opt/spire/bin/spire-agent run \
  -config /opt/spire/conf/agent.conf \
  -trustBundle /opt/spire/conf/root-bundle.crt
```


### Verification Log 
Watch the logs scrolling in both terminals. 
It should show a successful cryptographic handshake take place:

In the Agent Terminal: 
 - Look for lines stating Agent identity is ***spiffe://poc.internal/spire/agent/rocky-node*** and ***SVID renewed successfully***. 
 - This confirms the agent has received its unique cryptographic machine identity.

In the Server Terminal: 
  - You will see logs indicating that the join_token was successfully verified, and that an X.509 SVID (certificate) was issued to the node.

The agent should be running cleanly without errors.

Next step is to register your Podman workload environment on the server. Configure SPIRE to recognise a Podman container based on its Unix process attributes, preparing us to issue automated certificates directly to a running application.

The SPIRE Agent is successfully paired with the Server on host. The server has an automated identity engine.

The next step is Workload Registration. 
To do this it needs to tell the SPIRE Server: 
  - "If a Podman container runs on this Rocky Linux node matching specific attributes, give it a specific service identity."

## Phase 1, Step 3: Registering and Verifying a Podman Workload

Create a registration entry on the server, launch a simple Podman container, and prove that the container can retrieve its short-lived X.509 certificate automatically from the SPIRE agent.

### Create the Registration Entry on the Server
Open a third terminal window.

Run this command to create an identity for your future Podman container. 
We will use the unix workload attestor, telling SPIRE to look for a process running under the default root container user (***uid:0*** inside the container namespace context or host context mapping depending on configuration, but for a simple local test, we can scope it by standard Unix parameters or a specific user id):


```bash
sudo /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://poc.internal/app/podman-service \
    -parentID spiffe://poc.internal/manual/downloader.gardenofrot.cc \
    -selector unix:uid:0

```

```text
Entry ID                : a7639fb3-bfac-473f-b36e-4cacfe735aa7
SPIFFE ID               : spiffe://poc.internal/app/podman-service
Parent ID               : spiffe://poc.internal/manual/downloader.gardenofrot.cc
Revision                : 0
X509-SVID TTL           : default
JWT-SVID TTL            : default
Selector                : unix:uid:0
```

### Note: 
This rule says: 
  - Any workload running on your specific Downloader host (-parentID) that executes with Unix User ID 0 (-selector unix:uid:0) is authorised to claim the podman-service identity.

### Start an Interactive Podman Container
Spin up a standard, lightweight Alpine Linux container using Podman. 

To let the container talk to the SPIRE Agent on the host, we must mount the agent's Unix Domain Socket directly into the container.

Let's verify and share it:
```bash
ps aux | grep spire-agent
ls -la /tmp/spire-agent/public/api.sock

/opt/spire/bin/spire-agent/
```

# Launch the Podman container, mounting the SPIRE agent socket directory

Run the container rootless.

```bash
$ # Set this in your active shell profile (~/.bashrc) to make it stick
export XDG_RUNTIME_DIR="/tmp/podman-run-admin-paul"
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# set ownership so admin-paul owns the agent state data.
sudo chown -R admin-paul:admin-paul /opt/spire/data/agent

#Lingering forces Linux to spawn a dedicated user service manager (systemd --user) for you at system boot.
sudo loginctl enable-linger admin-paul

# Add a valid subordinate range for your user if it doesn't exist
# sudo usermod --add-subuids 100000-165535 admin-paul
# sudo usermod --add-subgids 100000-165535 admin-paul
podman system migrate


# SELinux prevents containers from accessing arbitrary directories on your host file system. You need to tell Podman to automatically re-label the directory with a container-sharable security context.Change your volume mount flag from :ro to :ro,z (the lowercase z shares the directory label safely across multiple rootless containers):

# Make sure your user owns the final target directory
sudo chown -R admin-paul:admin-paul /opt/spire/data/agent

# Ensure the parent directories have read/execute permissions for users
sudo chmod 755 /opt/spire /opt/spire/data /opt/spire/data/agent /opt/spire/data/agent/public


# start the conatiner
podman run -it --rm \
  -v /opt/spire/data/agent/public:/run/spire/sockets:ro,z \
  alpine:latest /bin/sh

```

inside the container run:
```sh
ls -la /run/spire/sockets
```

### Notes for Podman Production:

Production Podman Compose Configuration (compose.yaml)
```yaml
services:
  my-secure-workload:
    image: company/production-app:latest
    environment:
      - SPIFFE_ENDPOINT_SOCKET=unix:///run/spire/sockets/api.sock
    volumes:
      # Mounts the socket securely as read-only with shared SELinux labeling
      - /opt/spire/data/agent/public:/run/spire/sockets:ro,z
    restart: always

```

Production SPIRE Agent Configuration Snippet (agent.conf)

```json
agent {
    data_dir = "/opt/spire/data/agent"
    log_level = "INFO" # Avoid DEBUG overhead in production
    server_address = "192.168.122.199"
    server_port = "9081"
    trust_domain = "poc.internal"
    socket_path = "/opt/spire/data/agent/public/api.sock"
}
```

### Fetch the Certificate from Inside the Container
A bit of setup first. 

Need to change permission for PROD. !!!!!!!!!!!!!!!!!!!

```bash
# Run this on your host machine terminal
sudo semanage fcontext -a -t container_file_t "/opt/spire/data/agent/public(/.*)?"
sudo restorecon -R -v /opt/spire/data/agent/public


sudo chown -R admin-paul:admin-paul /opt/spire/data/agent/public
sudo chmod 777 /opt/spire/data/agent/public/api.sock

# Clear the Agent Cache
sudo /opt/spire/bin/spire-agent healthcheck -socketPath /opt/spire/data/agent/public/api.sock


# start a basic container 
podman run -it --rm \
  -v /opt/spire/data/agent/public:/run/spire/sockets:rw,z \
  alpine:latest /bin/sh

```
On SPIRE Server:

Register with the userID
```bash
sudo /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://poc.internal/workload/my-container \
    -parentID spiffe://poc.internal/downloader-agent \
    -selector unix:uid:162400005

```

Now you are inside the Podman container terminal prompt (/ #).

Download the spire-agent binary inside the container purely to use its api fetch tool to test the connection.

Run these commands inside your Podman container:
```bash
# 1. Install curl to grab the test tool
apk add --no-cache curl

# 2. Download the SPIRE binaries inside the container just to use the CLI tool
cd /tmp
curl -L -O https://github.com/spiffe/spire/releases/download/v1.15.1/spire-1.15.1-linux-amd64-musl.tar.gz
tar -zxvf spire-1.15.1-linux-amd64-musl.tar.gz

# 3. Request the workload identity certificate from the mounted socket
./spire-1.15.1/bin/spire-agent api fetch x509 \
  -socketPath /run/spire/sockets/api.sock
```


🔍 Verification Check
If everything is working correctly, the output inside your Podman container will print out a structured block containing:
Received 1 svid(s)
SPIFFE ID: spiffe://poc.internal/app/podman-service
A raw dump of an X.509 Certificate and its corresponding private key.
This confirms that a completely isolated container successfully requested, proved its identity to the host, and received a valid Zero Trust certificate without needing any pre-shared API keys!
Run this test inside the container. Once you see the certificate output or if you run into a socket permission error (common with Podman/SELinux), let me know the result!
Did the container successfully fetch its first SPIFFE identity certificate?


# Start Again on the client - SPIRE Agent in Container (podman)

```bash
mkdir -p ~/spire/agent/conf ~/spire/agent/data ~/spire/agent/sockets
cp /opt/spire/conf/agent.conf ~/spire/agent/conf/agent.conf
cp /opt/spire/conf/root-bundle.crt ~/spire/agent/conf/root-bundle.crt

```
Update your ~/spire/agent/conf/agent.conf to use the standardized container socket path:

```bash
vim  ~/spire/agent/conf/agent.conf 
```
```json
agent {
    data_dir = "/opt/spire/data/agent"
    log_level = "DEBUG"
    server_address = "192.168.122.199"
    server_port = "9081"
    trust_domain = "poc.internal"
    
    # Updated path for inside the container
    socket_path = "/run/spire/sockets/api.sock"
}

```

### Update the SPIRE Server Registy

```bash
sudo /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://poc.internal/workload/containerized-app \
    -parentID spiffe://poc.internal/downloader-agent \
    -selector unix:uid:0

```

On Server
```bash
sudo /opt/spire/bin/spire-server token generate \
  -spiffeID spiffe://poc.internal/downloader-agent
```

On Podman Host:


```bash
sudo vim /var/tmp/spire/agent/conf/agent.conf
```       

```json
agent {
    data_dir = "/opt/spire/data/agent"
    log_level = "DEBUG"
    server_address = "192.168.122.199"
    server_port = "9081"
    trust_domain = "poc.internal"
    
    # Update this path to match your internal container layout
    socket_path = "/run/spire/sockets/api.sock"
    
    # Add this line to fix the boot crash error
    trust_bundle_path = "/opt/spire/conf/agent/root-bundle.crt"
}

plugins {
    NodeAttestor "join_token" {}
    KeyManager "disk" {
        plugin_data {
            directory = "/opt/spire/data/agent"
        }
    }
    WorkloadAttestor "unix" {}
}

```

```bash
# 1. Clear out the failed instance
podman rm -f spire-agent
```

```bash
podman run -d --name spire-agent \
  -v /var/tmp/spire/agent/conf:/opt/spire/conf/agent:ro,Z \
  -v /var/tmp/spire/agent/data:/opt/spire/data/agent:rw,Z \
  -v /var/tmp/spire/agent/sockets:/run/spire/sockets:rw,Z \
  ghcr.io/spiffe/spire-agent:1.15.1 \
  -joinToken "PASTE_YOUR_NEW_TOKEN_HERE"
```

## Step 1: Run the Alpine Workload Container
Launch the test Alpine container by mounting the shared socket directory from /var/tmp. 
No need for any special process flags or security bypasses because everything matches within the rootless container network layout.

```bash
podman run -it --rm \
  -v /var/tmp/spire/agent/sockets:/run/spire/sockets:rw,z \
  alpine:latest /bin/sh
```

In container:
```sh
# 1. Grab your package dependencies
apk add --no-cache curl

# 2. Download and extract the SPIRE binaries to use the CLI tool
cd /tmp
curl -L -O https://github.com
tar -zxvf spire-1.15.1-linux-amd64-musl.tar.gz

# 3. Request your workload identity certificate from the running socket
./spire-1.15.1/bin/spire-agent api fetch x509 -socketPath /run/spire/sockets/api.sock

```
--------

```bash
admin-paul@downloader:~$ # 1. Force export your exact user environment parameters
export UID=162400005
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

# 2. Verify the runtime path exists on disk
mkdir -p $XDG_RUNTIME_DIR
-bash: UID: readonly variable

admin-paul@downloader:~$ # Run this entirely WITHOUT sudo
systemctl --user enable --now podman.socket
Created symlink '/home/freeipa/admin-paul/.config/systemd/user/sockets.target.wants/podman.socket' → '/usr/lib/systemd/user/podman.socket'.

admin-paul@downloader:~$ ls -la /run/user/162400005/podman/podman.sock
# Output should show: srw-rw----. 1 admin-paul admin-paul 0 podman.sock
srw-rw----. 1 admin-paul admin-paul 0 Jun 20 19:42 /run/user/162400005/podman/podman.sock

```

-------------------

Compose.yaml

```yaml
services:
  spire-agent:
    image: ghcr.io/spiffe/spire-agent:1.15.1
    volumes:
      - /var/tmp/spire/agent/conf:/opt/spire/conf/agent:ro,Z
      - /var/tmp/spire/agent/data:/opt/spire/data/agent:rw,Z
      - /var/tmp/spire/agent/sockets:/run/spire/sockets:rw,Z
    # For subsequent restarts after initial token bootstrap, the agent 
    # automatically loads its keys from the persisted data folder.
    restart: always

  production-app:
    image: company/my-workload:1.0.0
    environment:
      - SPIFFE_ENDPOINT_SOCKET=unix:///run/spire/sockets/api.sock
    volumes:
      # Mounts the socket directory with a shared lowercase 'z' flag 
      # allowing multiple local containers to securely stream across it.
      - /var/tmp/spire/agent/sockets:/run/spire/sockets:rw,z
    depends_on:
      - spire-agent

```

```json
agent {
    data_dir = "/opt/spire/data/agent"
    log_level = "DEBUG"
    server_address = "192.168.122.199"
    server_port = "9081"
    trust_domain = "poc.internal"

    # Update this path to match your internal container layout
    socket_path = "/run/spire/sockets/api.sock"

    # Add this line to fix the boot crash error
    trust_bundle_path = "/opt/spire/conf/agent/root-bundle.crt"
}

plugins {
    NodeAttestor "join_token" {}
    KeyManager "disk" {
        plugin_data {
            directory = "/opt/spire/data/agent"
        }
    }
    
    # Replace the unix plugin with this container runtime tracker
    WorkloadAttestor "docker" {
        plugin_data {
            connection_path = "/run/podman/podman.sock"
        }
    }
}

```