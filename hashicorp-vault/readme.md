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