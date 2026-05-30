@ setup next clud and Only Office

Create the Namespace
```bash
kubectl create namespace garden-office
```
2. Storage & Database (MariaDB)This manifest creates the namespace-scoped storage and the database required for Nextcloud.
```yaml
# database.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-db-pvc
  namespace: garden-office
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 5Gi } }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud-db
  namespace: garden-office
spec:
  selector: { matchLabels: { app: nextcloud-db } }
  template:
    metadata: { labels: { app: nextcloud-db } }
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.6
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "secret-root-pass"
        - name: MYSQL_DATABASE
          value: "nextcloud"
        - name: MYSQL_USER
          value: "nextcloud"
        - name: MYSQL_PASSWORD
          value: "nextcloud-db-pass"
        volumeMounts:
        - name: db-data
          mountPath: /var/lib/mysql
      volumes:
      - name: db-data
        persistentVolumeClaim: { claimName: nextcloud-db-pvc }
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-db
  namespace: garden-office
spec:
  ports: [{ port: 3306 }]
  selector: { app: nextcloud-db }
```

3. Nextcloud & ONLYOFFICE ApplicationNextcloud handles the files, and ONLYOFFICE Docs (Document Server) handles the editing.

```yaml
# applications.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-data-pvc
  namespace: garden-office
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 20Gi } }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  namespace: garden-office
spec:
  selector: { matchLabels: { app: nextcloud } }
  template:
    metadata: { labels: { app: nextcloud } }
    spec:
      containers:
      - name: nextcloud
        image: nextcloud:latest
        env:
        - name: MYSQL_HOST
          value: "nextcloud-db"
        - name: MYSQL_DATABASE
          value: "nextcloud"
        - name: MYSQL_USER
          value: "nextcloud"
        - name: MYSQL_PASSWORD
          value: "nextcloud-db-pass"
        - name: NEXTCLOUD_TRUSTED_DOMAINS
          value: "cloud.gardenofrot.cc"
        volumeMounts:
        - name: nc-data
          mountPath: /var/www/html
      volumes:
      - name: nc-data
        persistentVolumeClaim: { claimName: nextcloud-data-pvc }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: onlyoffice
  namespace: garden-office
spec:
  selector: { matchLabels: { app: onlyoffice } }
  template:
    metadata: { labels: { app: onlyoffice } }
    spec:
      containers:
      - name: onlyoffice
        image: onlyoffice/documentserver:latest
        env:
        - name: JWT_ENABLED
          value: "true"
        - name: JWT_SECRET
          value: "garden-secret-key"
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: garden-office
spec:
  ports: [{ port: 80, targetPort: 80 }]
  selector: { app: nextcloud }
---
apiVersion: v1
kind: Service
metadata:
  name: onlyoffice
  namespace: garden-office
spec:
  ports: [{ port: 80, targetPort: 80 }]
  selector: { app: onlyoffice }
Use code with caution.4. Cilium Gateway API (Networking)The Gateway is placed in the garden-office namespace. It will listen for traffic and route it to the specific services based on the hostname.yaml# networking.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: garden-gateway
  namespace: garden-office
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces: { from: Same }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nextcloud-route
  namespace: garden-office
spec:
  parentRefs: [{ name: garden-gateway }]
  hostnames: ["cloud.gardenofrot.cc"]
  rules:
  - backendRefs: [{ name: nextcloud, port: 80 }]
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: onlyoffice-route
  namespace: garden-office
spec:
  parentRefs: [{ name: garden-gateway }]
  hostnames: ["office.gardenofrot.cc"]
  rules:
  - backendRefs: [{ name: onlyoffice, port: 80 }]
  ```