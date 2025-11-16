# Using Azure Artifacts Universal Repository from linux

Publish to a Universal Packages in Azure DevOps using a Linux (RHEL/Rocky) client machine, authentication is via a Personal Access Token (PAT).  
This process will authenticate your Linux machine with Azure DevOps using the PAT and publish your Universal Package to the specified Azure Artifacts feed.

1. Create a Personal Access Token (PAT) in Azure Devops.
2. Install the Client tools
3. Login to Azure using the Command Line Interface (cli)
4. Publish File from a directory, if artifacet repo is empty a Download with reyrun an error.
5. Downlaod Files from artifacet repo 


## Generate a Personal Access Token (PAT):
 - Log in to your Azure DevOps organization.
 - Navigate to User settings (top right corner) > Personal access tokens.
 - Click New Token.
 - Provide a name for the token, select the organization, and set an expiration date.
 - For Scopes, ensure you select **Packaging** > **Read & write**.  
 This grants the necessary permissions to publish packages.
- Click Create and copy the generated PAT immediately, as it will not be shown again.  **Store it securely**.


## Intall the Azure Command Line Interface tool

Install the Azure CLI on your RHEL/Rocky machine. 

```bash
# add the Microsoft Public key
sudo rpm --import https://packages.microsoft.com/keys/microsoft-2025.asc
# Install package and install the cli
sudo dnf install -y https://packages.microsoft.com/config/rhel/10/packages-microsoft-prod.rpm
sudo dnf install azure-cli -y

# Upgrade may be needed
az extension add --name azure-devops
az upgrade
```



## Logon to Azure DevOps
```bash
#   az devops login --organization https://dev.azure.com/<your-organization-name>
   az devops login --organization https://dev.azure.com/PaulMcKee0888/ 
```

When prompted, paste your copied PAT as the password.  
Prepare your Universal Package:
- Ensure your Universal Package is structured correctly and ready for publishing. 
- Universal Packages require a name and a version number.

## Publish to the Universal Package:
Use the '*az artifacts universal publish*' command to publish your package:
```bash 

az artifacts universal publish \
    --organization https://dev.azure.com/<your-organization-name> \
    --feed <your-feed-name> \
    --name <package-name> \
    --version <package-version> \
    --path <path-to-your-package-directory>
```
Replace placeholders like with your actual values.

Example:
```bash
az artifacts universal publish \
    --organization https://dev.azure.com/PaulMcKee0888/ \
    --feed MyArtifacts \
    --name my-first-package \
    --version 0.0.1 \
    --description "Welcome to Universal Packages" \
    --path .

```

## Download from the Universal Package
```bash
az artifacts universal download \
    --organization https://dev.azure.com/PaulMcKee0888/ \
    --feed MyArtifacts \
    --name my-first-package \
    --version 0.0.1 \
    --path .
```


## Troubleshooting

```bash 
## If Proxy is blocking connection
# No auth
export HTTP_PROXY=http://[proxy]:[port]
export HTTPS_PROXY=https://[proxy]:[port]

# Basic auth
export HTTP_PROXY=http://[username]:[password]@[proxy]:[port]
export HTTPS_PROXY=https://[username]:[password]@[proxy]:[port]

```
