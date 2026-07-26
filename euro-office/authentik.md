# Authentil Identity Management (IdM)


```bash
podman ps -a
mkdir -p ~/authentik && cd ~/authentik
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 36)" > .env
echo "AUTHENTIK_PG_PASS=$(openssl rand -base64 18)" >> .env
nano docker-compose.yml
nano docker-compose.yaml
cat docker-compose.yaml
podman compose up -d
podman ps -a

```

```text
[root@authentik authentik]# podman ps -a
CONTAINER ID  IMAGE                                 COMMAND               CREATED            STATUS                      PORTS                                           NAMES
1af58c29e8e3  docker.io/library/postgres:16-alpine  postgres              About an hour ago  Up About an hour (healthy)  5432/tcp                                        authentik_postgresql_1
8468ed1934eb  docker.io/library/redis:7-alpine      --save 60 1 --log...  About an hour ago  Up About an hour (healthy)  6379/tcp                                        authentik_redis_1
9a9725c2bc4a  ghcr.io/goauthentik/server:2024.4.2   server                About an hour ago  Up About an hour            0.0.0.0:8000->8000/tcp, 0.0.0.0:9443->9443/tcp  authentik_server_1
3f270eafa601  ghcr.io/goauthentik/server:2024.4.2   worker                About an hour ago  Up About an hour                                                            authentik_worker_1
[root@authentik aut
```
# update the NGINX Reverse Proxy
While Authentik runs its database setup steps, setup the nginx-proxy VM (192.168.0.101) terminal to ensure the path is clear:

Open your configuration block:
```bash
sudo nano /etc/nginx/sites-available/authentik.conf
```

```ini
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
        # 1. Point to Authentik's verified open HTTPS port
        proxy_pass https://192.168.0.123:9443;

        # 2. Tell Nginx to ignore the internal self-signed certificate
        proxy_ssl_verify off;
        proxy_ssl_session_reuse on;
        proxy_ssl_server_name on;

        # 3. Standard reverse proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # 4. WebSocket support (Required for live Authentik Admin metrics)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}


```

Ensure Ngnix has the symbolic link in the correct directory
```bash 
sudo ln -s /etc/nginx/sites-available/authentik.conf /etc/nginx/sites-enabled/

```

## need Kerberos and LDAP

podman compose up -d --force-recreate

```bash
 cat docker-compose.yaml
```
```yaml
version: "3.4"

services:
  postgresql:
    image: docker.io/library/postgres:16-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      max_retries: 5
      timeout: 5s
    volumes:
      - database:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${AUTHENTIK_PG_PASS:?error}
      POSTGRES_USER: ${POSTGRES_USER:-authentik}
      POSTGRES_DB: ${POSTGRES_DB:-authentik}

  redis:
    image: docker.io/library/redis:7-alpine
    command: --save 60 1 --loglevel warning
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      start_period: 20s
      interval: 30s
      max_retries: 5
      timeout: 5s
    volumes:
      - redis:/data

  server:
    # image: ghcr.io/goauthentik/server:2024.4.2
    image: ghcr.io/goauthentik/server:${AUTHENTIK_TAG:-latest}
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${POSTGRES_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${POSTGRES_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${AUTHENTIK_PG_PASS:?error}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY:?error}
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
    image: ghcr.io/goauthentik/server:2024.4.2
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${POSTGRES_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${POSTGRES_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${AUTHENTIK_PG_PASS:?error}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY:?error}
    user: root
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./media:/media
      - ./custom-templates:/templates
    depends_on:
      - postgresql
      - redis

  authentik-ldap:
    image: ghcr.io/goauthentik/ldap:${AUTHENTIK_TAG:-latest}
    restart: unless-stopped
    ports:
      - "3389:3389"
      - "6636:6636"
    environment:
      AUTHENTIK_HOST: https://authentik.gardenofrot.cc
      AUTHENTIK_INSECURE: "false"
      # Paste your exact Master Admin portal token key path context here:
      AUTHENTIK_TOKEN: "2j9e9IHxRpWYcyM6lQBGqdPRetkHI6Q0BDwpkldwGk7IpRKtYFn9exQoNnXK"

volumes:
  database:
    driver: local
  redis:
    driver: local
```
