# Vault setup

## local install
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf -y install vault
```

## Start the server in DEV mode
```bash
vault server -help
vault server -dev
```
Output
```
You may need to set the following environment variables:

   $ export VAULT_ADDR='http://127.0.0.1:8200'

The unseal key and root token are displayed below in case you want to
seal/unseal the Vault or re-authenticate.


Unseal Key: <REDACTED>
Root Token: <REDACTED>

```
Note: Root Token starts with "hvs.""
```bash
export VAULT_ADDR='http://192.168.122.124:8200'
export VAULT_DEV_ROOT_TOKEN_ID="hvs.<REDACTED>"
```

# Create a new Root Token
```bash
vault token create
```

output

``` 
Key                  Value
---                  -----
token                <REDACTED>
token_accessor       <REDACTED>
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

# Auth - Github
```bash
vault auth enable github
vault write auth/github/config organization=mind-glow   
vault write auth/github/map/teams/development value=default,applications
 
vault auth list                                                                                                                                                 in bash at 17:49:01
```

```
Path       Type      Accessor                Description                Version
----       ----      --------                -----------                -------
github/    github    auth_github_a1d0518f    n/a                        n/a
token/     token     auth_token_2aa323a5     token based credentials    n/a
```

Help
```bash
vault auth help github

```


ODIC 

vault auth enable jwt
vault write auth/jwt/config \
  bound_issuer="https://token.actions.githubusercontent.com" \
  oidc_discovery_url="https://token.actions.githubusercontent.com"

```bash
vault policy write myproject-production - <<EOF
# Read-only permission on 'secret/data/production/*' path

path "secret/data/production/*" {
  capabilities = [ "read" ]
}
EOF

```


```bash
vault write auth/jwt/role/myproject-production -<<EOF
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_claims": {
    "repository": "mind-glow/repositories"
  },
  "policies": ["myproject-production"],
  "ttl": "10m"
}
EOF

```

# Vault Kerberos
On Vault Server

https://developer.hashicorp.com/vault/docs/auth/kerberos


```bash
[paul@rhel9-vault ~]$ sudo ktutil 
[sudo] password for paul: 
ktutil:  addent -password -p svc_keycloak@gardenofrot.cc -e aes256-cts -k 1
Password for svc_keycloak@gardenofrot.cc: 
ktutil:  list -e
slot KVNO Principal
---- ---- ---------------------------------------------------------------------
   1    1              svc_keycloak@gardenofrot.cc (aes256-cts-hmac-sha1-96) 
ktutil:  wkt vault.keytab
ktutil:  exit
 vault.keytab.base64




```
vault login -tls-skip-verify -address=https://127.0.0.1:8202 hvs.<<RETACTED>>


vault auth enable -tls-skip-verify \
    -passthrough-request-headers=Authorization \
    -allowed-response-headers=www-authenticate \
    kerberos


vault write -tls-skip-verify \
    auth/kerberos/config \
    keytab=@vault.keytab.base64 \
    service_account="vault_svc" 


export VAULT_SVC_USERNAME="svc_keycloak@gardenofrot.cc"    
export VAULT_SVC_PASSWORD="xxxxxxxxxxxxxxxxxxx"

vault write -tls-skip-verify \
    auth/kerberos/config/ldap \
    binddn=$VAULT_SVC_USERNAME  \
    bindpass=$VAULT_SVC_PASSWORD \
    groupattr=sAMAccountName \
    groupdn="DC=GARDENOFROT,DC=CC" \
    groupfilter="(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))" \
    userdn="CN=Users,DC=GARDENOFROT,DC=CC" \
    userattr=sAMAccountName \
    upndomain=GARDENOFROT.CC \
    url=ldaps://freeipa.gardenofrot.cc
