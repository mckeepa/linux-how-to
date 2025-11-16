

Check Version

```bash
    podman --version
```

Create a dedicated network (optional but recommended): This isolates Vault's network traffic.

```bash

    podman network create vault-network
```

Run the Vault container: Use the podman run command to pull the hashicorp/vault image and start a container.

```bash

    podman run --restart unless-stopped \
      --name hashicorp_vault \
      --cap-add=IPC_LOCK \
      -e 'VAULT_DEV_ROOT_TOKEN_ID=myroottoken' \
      -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
      -p 8200:8200 \
      --network vault-network \
      hashicorp/vault
```

restart

```bash
 podman restart hashicorp_vault 

```

http://rocky10-wk01.gardenofrot.cc:8200/ui/vault/dashboard


## Add SSL/TLS


Create a service for the host
```bash
ipa service-add-host --hosts=rocky10-wk01.gardenofrot.cc HTTP/vault.gardenofrot.cc

  Principal name: http/vault.gardenofrot.cc@GARDENOFROT.CC
  Principal alias: http/vault.gardenofrot.cc@GARDENOFROT.CC
  Managed by: vault.gardenofrot.cc, rocky10-wk01.gardenofrot.cc
-------------------------
Number of members added 1
-------------------------

```

Request Cert

```bash
vi ~/certs/vault.gardenofrot.cc.cnf 
```

```ini
 OpenSSL configuration file for creating a CSR for a server certificate
# Adapt at least the FQDN and ORGNAME lines, and then run 
# openssl req -new -config myserver.cnf -keyout myserver.key -out myserver.csr
# on the command line.

# the fully qualified server (or service) name
FQDN = vault.gardenofrot.cc

# the name of your organization
# (see also https://www.switch.ch/pki/participants/)
ORGNAME = Garden Of Rot

# subjectAltName entries: to add DNS aliases to the CSR, delete
# the '#' character in the ALTNAMES line, and change the subsequent
# 'DNS:' entries accordingly. Please note: all DNS names must
# resolve to the same IP address as the FQDN.
ALTNAMES = DNS:$FQDN   # , DNS:bar.example.org , DNS:www.foo.example.org

# --- no modifications required below ---
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
encrypt_key = no
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = CH
O = $ORGNAME
CN = $FQDN

[ req_ext ]
subjectAltName = $ALTNAMES
```

```bash
# Generate the Certificate Signing Request (CSR), and the Private Key,  using the config file (.cnf) as the input.   
openssl req -new -config ~/certs/vault.gardenofrot.cc.cnf -keyout ~/certs/vault.gardenofrot.cc.key -out ~/certs/vault.gardenofrot.cc.csr

cat ~/certs/vault.gardenofrot.cc.csr

ipa cert-request --principal=host/vault.gardenofrot.cc ~/certs/vault.gardenofrot.cc.csr

# Certificate is now in FreeAPI and can be downloaded from the Web UI

$ cat ~/certs/vault.gardenofrot.cc.key

```


## vault.hcl
vault/vault_config/vault.hcl

```ini
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8300"
  cluster_address = "0.0.0.0:8201"
  tls_disable   = false
  tls_cert_file = "/vault/config/certs/vault.gardenofrot.cc.pem"
  tls_key_file  = "/vault/config/certs/vault.gardenofrot.cc.key"
}

disable_mlock = true
ui       = true
api_addr = "https://vault.gardenofrot.cc:8300"

```

```bash
# Start Vault in podman using Volumes
```bash
 podman run 
   --restart unless-stopped \
   --name vault \
   --cap-add=IPC_LOCK \
   -p 8300:8300 \
   --network vault-network \
   -v /home/freeipa/admin-paul/vault/certs:/vault/config/certs:z \  
   -v /home/freeipa/admin-paul/vault/vault_config:/vault/config:z \    
   -v /home/freeipa/admin-paul/vault/vault_data:/vault/data:z \
   --entrypoint vault \
     hashicorp/vault:latest server -config=/vault/config/vault.hcl

   
   # Dev Version
    podman run --restart unless-stopped \
      --name hashicorp_vault \
      --cap-add=IPC_LOCK \
      -e 'VAULT_DEV_ROOT_TOKEN_ID=myroottoken' \
      -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' \
      -p 8200:8200 \
      --network vault-network \
      hashicorp/vault
```

From inside container

```bash
# export VAULT_ADDR="https://127.0.0.1:8300"
vault login

Token (will be hidden): 

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
<REDATCED>
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

```


Get the Auth list
```bash
podman exec -it vault /bin/sh
export VAULT_ADDR="https://127.0.0.1:8300"
export VAULT_SKIP_VERIFY=true
vault login

vault auth list -detailed | grep kerberos

# Enable kerberos - inside the contaner
vault auth enable kerberos
```

from the Host machine for Podaman
```bash
 curl -s https://localhost:8300/v1/sys/health -k
 ```




## Generate Kerberos Keytab

 Generating the Keytab in FreeIPA:

  Create a Service Principal: First, a service principal needs to be created in FreeIPA for the Vault server. This principal represents the Vault service in the Kerberos realm. 

```bash
@freeipa:~$ ipa service-add vault/vault.gardenofrot.cc@GARDENOFROT.CC
---------------------------------------------------------
Added service "vault/vault.gardenofrot.cc@GARDENOFROT.CC"
---------------------------------------------------------
  Principal name: vault/vault.gardenofrot.cc@GARDENOFROT.CC
  Principal alias: vault/vault.gardenofrot.cc@GARDENOFROT.CC
  Managed by: vault.gardenofrot.cc

```
# Export the keytab 
```bash
ipa-getkeytab -s freeipa.gardenofrot.cc -p vault/vault.gardenofrot.cc@GARDENOFROT.CC -k ./vault.gardenofrot.cc.keytab

Keytab successfully retrieved and stored in: ./vault.gardenofrot.cc.keytab

```

Move the Keytab file
```bash
scp vault.gardenofrot.cc.keytab admin-paul@rocky10-wk01.gardenofrot.cc:/home/freeipa/admin-paul/vault/keytabs/

vault.gardenofrot.cc.keytab               
```


## Start wityh the keytab

# Start Vault in podman using Volumes
```bash




podman run --restart unless-stopped     --name vault     --cap-add=IPC_LOCK     -p 8300:8300     --network vault-network     -v /home/freeipa/admin-paul/vault/certs:/vault/config/certs:z     -v /home/freeipa/admin-paul/vault/vault_config:/vault/config:z     -v /home/freeipa/admin-paul/vault/vault_data:/vault/data:z  -v /home/freeipa/admin-paul/vault/keytabs:/vault/keytabs:z   --entrypoint vault     hashicorp/vault:latest server -config=/vault/config/vault.hcl

```

## Configure the Kerberos auth method in Vault

```bash
vault write auth/kerberos/config \
    service_account="vault/vault.gardenofrot.cc@GARDENOFROT.CC" \
    keytab="/vault/keytabs/vault.gardenofrot.cc.keytab" \
    realm="GARDENOFROT.CC" \
    krb5_config="/etc/krb5.conf"

vault write auth/kerberos/config \
    service_account="vault/vault.gardenofrot.cc@GARDENOFROT.CC" \
    keytab="$cat /vault/keytabs/vault.gardenofrot.cc.keytab.base64)" \
    realm="GARDENOFROT.CC" \
    krb5_config="/etc/krb5.conf"

```

## Testing the keytab
```bash
klist -kt vault.gardenofrot.cc.keytab

Keytab name: FILE:vault.gardenofrot.cc.keytab
KVNO Timestamp         Principal
---- ----------------- --------------------------------------------------------
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC


admin-paul@rocky10-wk01:~/vault/keytabs$ kinit -kt vault.gardenofrot.cc.keytab vault/vault.gardenofrot.cc@GARDENOFROT.CC


admin-paul@rocky10-wk01:~/vault/keytabs$ klist -kt vault.gardenofrot.cc.keytab
Keytab name: FILE:vault.gardenofrot.cc.keytab
KVNO Timestamp         Principal
---- ----------------- --------------------------------------------------------
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC
   1 30/08/25 21:51:57 vault/vault.gardenofrot.cc@GARDENOFROT.CC


admin-paul@rocky10-wk01:~/vault/keytabs$ klist
Ticket cache: KCM:162400005:50103
Default principal: vault/vault.gardenofrot.cc@GARDENOFROT.CC

Valid starting     Expires            Service principal
30/08/25 22:20:16  31/08/25 21:47:27  krbtgt/GARDENOFROT.CC@GARDENOFROT.CC

```


# Client setup Linux RHEL/Rocky

```bash
#    sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

#    sudo dnf -y install vault

https://releases.hashicorp.com/vault/1.20.3/vault_1.20.3_darwin_arm64.zip
# 1 - Download
# 2 - unzip
# 3 - Run vault 

vault login -method=kerberos \
  username="vault/vault.gardenofrot.cc@GARDENOFROT.CC" \
  service="vault/gardenofrot.cc@GARDENOFROT.CC" \
  realm="GARDENOFROT.CC" \
  keytab_path="~/vault/keytabs/vault.gardenofrot.cc.keytab"\
  krb5conf_path="/etc/krb5.conf"



./vault login -method=kerberos \
  username="vault/vault.gardenofrot.cc@GARDENOFROT.CC" \
  service="vault/gardenofrot.cc@GARDENOFROT.CC" \
  realm="GARDENOFROT.CC" \
  keytab_path="/home/freeipa/admin-paul/vault/keytabs/vault.gardenofrot.cc.keytab" \
  krb5conf_path="/etc/krb5.conf"



./vault login -method=kerberos \
  service="vault/gardenofrot.cc@GARDENOFROT.CC" \
  realm="GARDENOFROT.CC" \
  keytab_path="/home/freeipa/admin-paul/vault/keytabs/vault.gardenofrot.cc.keytab" \
  krb5conf_path="/etc/krb5.conf"

```
--------------------------------------------------
--------------------------------------------------
--------------------------------------------------

  Add a DNS record for **rocky10-wk01**


  For example:

```bash
  ipa service-add HTTP/rocky10-wk01.gardenofrot.cc

```
Result
```text
---------------------------------------------------------------
Added service "HTTP/rocky10-wk01.gardenofrot.cc@GARDENOFROT.CC"
---------------------------------------------------------------
  Principal name: HTTP/rocky10-wk01.gardenofrot.cc@GARDENOFROT.CC
  Principal alias: HTTP/rocky10-wk01.gardenofrot.cc@GARDENOFROT.CC
  Managed by: rocky10-wk01.gardenofrot.cc

```

  Generate the Keytab: Use the ipa-getkeytab command to generate the keytab file for the newly created service principal. Specify the principal name and the desired keytab file path:

Code
```bash
$ kinit
Password for admin@GARDENOFROT.CC: 

$ ipa-getkeytab -s freeipa.gardenofrot.cc -p HTTP/rocky10-wk01.gardenofrot.cc@GARDENOFROT.CC -k ./vault.keytab

Keytab successfully retrieved and stored in: ./vault.keytab
 
```

## Configuring HashiCorp Vault for Kerberos Authentication:

Enable Kerberos Auth Method: 

Enable the Kerberos authentication method in Vault:

```bash

podman exec -it hashicorp_vault /bin/sh

vault auth enable -passthrough-request-headers=Authorization -allowed-response-headers=www-authenticate kerberos
```

    Configure the Kerberos Auth Method: Configure the Kerberos auth method with the necessary parameters, including the path to the krb5.conf file, the keytab path, the service principal name, and the Kerberos realm:

Code

    vault write auth/kerberos/config \
    krb5conf_path="/etc/krb5.conf" \
    keytab_path="/path/to/vault.keytab" \
    service="HTTP/vault.example.com@YOUR_REALM" \
    realm="YOUR_REALM"

Ensure the krb5.conf and vault.keytab files are accessible by the Vault server and have appropriate permissions.
3. Performing Kerberos Authentication to Vault:

    Obtain a Kerberos Ticket: On the client machine, obtain a Kerberos Ticket-Granting Ticket (TGT) for a user principal using kinit: 

Code

    kinit username@YOUR_REALM

    Authenticate to Vault: Use the vault login command with the Kerberos auth method, which will leverage the obtained TGT for authentication:

Code

    vault login -method=kerberos

Vault will then use the Kerberos service principal configured with the keytab to validate the user's Kerberos ticket and grant access.


===================================================================

===================================================================

===================================================================

#Start Again

 podman run -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak:latest start-dev

 
