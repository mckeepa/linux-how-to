# WARNING !!!! 
# Open Claw setup

Rules:
 - Isolate the Environment: 
    - only Localhost can access it.
    - VLAN Segmentation
    - Private Tunneling, if remote access is needed, use Tailscale. 
 - Identity and Credential:
    - Dedicated Accounts(throwaway):  Google, GitHub, or Telegram accounts specifically for the agent.
    - Use scoped OAuth permissions (e.g., read-only access)
    - Spending Limits: hard credit limit on OpenAI or Anthropic API dashboards to prevent unexpected charges.


# Goal
Set up OpenClaw securely for tasks like code generation and network research.
Combining both: 
  - Rootless Podman container,
  - inside a QEMU/KVM Virtual Machine.

Running in a VM provides a hardware-level security boundary (Guest OS isolation).
Podman adds process-level sandboxing (SELinux and namespaces). 

A QEMU/KVM VM is more secure than a standalone container because it uses a separate kernel. 
If an agent executes malicious code that attempts a kernel exploit, it only compromises the VM's kernel, not the host's kernel. 
Podman is used for "defense in depth" as it runs without root privileges by default, meaning even if the container is breached, it is trapped as a non-privileged user.
    

# Step 1: Set up the VM (Rocky Linux or Fedora)
On the host machine, use virt-manager to create a dedicated VM for OpenClaw.

Create VM using Rock 10, 4 CPUs and 8GB RAM.
Use a NAT or Isolated network; do not bridge it directly to your home LAN.
    - I'll add a network to allows downloads and software updates, but disable network before starting OpenClaw




Create user
```bash
sudo useradd -m -s /bin/bash openclaw_sv

grep openclaw_sv /etc/subuid /etc/subgid
# If no output appears, manually assign a range (e.g., 100,000–165,535)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 openclaw_sv

```

Enable Session Lingering, By default, rootless containers stop when the user logs out. 
Enabling "linger" allows the openclaw_sv user's manager to stay active in the background, which is essential for an autonomous agent: 

```bash
sudo loginctl enable-linger openclaw_sv

# initialize Podman for the New User
# Switch to the new user and initialize the Podman environment:
sudo -u openclaw_sv -i
podman system migrate
exit
```

# Step 2: Set up OpenClaw in a Podman Container
Once inside your new VM, use the official Podman scripts for a hardened, rootless installation. 

## Install Podman and Git:
```bash
sudo dnf install -y podman git  
````
``` bash

# Switch to the service user
sudo -u openclaw_sv -i

# Clone the repository
git clone https://github.com/openclaw/openclaw.git

cd openclaw
./scripts/podman/setup.sh --quadlet

# Using the --quadlet flag integrates the container into systemd, allowing it to run as a user service that persists across reboots.

```
Access the dashboard at http://127.0.0.1:18789. Only access this from within the VM or via an SSH tunnel from your host
SELinux Enforcement: 



# Launch the Gateway & Onboarding

The Gateway is the core service that manages the AI agents. You must run the onboarding wizard once to configure your LLM providers (e.g., Anthropic, OpenAI) and set up security. 
bash

# Launch the container and the onboarding wizard
```bash
./scripts/run-openclaw-podman.sh launch setup
```

## Onboarding: 
Follow the prompts in your terminal. 

You will be asked to select a model (for code generation, choose a high-reasoning model like Claude 3.5 Sonnet or GPT-4o).

|  Recommended baseline:                                                                     │
│  - Pairing/allowlists + mention gating.                                                    │
│  - Multi-user/shared inbox: split trust boundaries (separate gateway/credentials, ideally  │
│    separate OS users/hosts).                                                               │
│  - Sandbox + least-privilege tools.                                                        │
│  - Shared inboxes: isolate DM sessions (`session.dmScope: per-channel-peer`) and keep      │
│    tool access minimal.                                                                    │
│  - Keep secrets out of the agent’s reachable filesystem.                                   │
│  - Use the strongest available model for any bot with tools or untrusted inboxes.          │
│                                                                                            │
│  Run regularly:                                                                            │
│  openclaw security audit --deep                                                            │
│  openclaw security audit --fix                                                             │
│                                                                                            │
│  Must read: https://docs.openclaw.ai/gateway/security  



## Access the UI: 
Once setup is complete, the dashboard will be available at http://127.0.0.1:18789. 