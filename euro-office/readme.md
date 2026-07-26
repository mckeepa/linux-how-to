# Euro Cloud


## nextcloud:~# history

```bash
 mkdir -p /opt/nextcloud && cd /opt/nextcloud
 nano docker-compose.yml
 ps -a
 docker compose up -d
 systemctl enable --now docker
 # 1. Reset failed systemd records
 systemctl reset-failed docker
 # 2. Force start the engine
 systemctl start docker
 systemctl enable --now docker
 docker compose up -d
 # 1. Reset failed systemd records
 systemctl reset-failed docker

 # 2. Force start the engine
 systemctl start docker
 ip a
 docker logs nextcloud-aio-mastercontainer
 cd /opt/nextcloud
 docker compose down -v
 nano docker-compose.yml
 docker compose up -d
 docker logs -f nextcloud-aio-mastercontainer
 sudo docker logs nextcloud-aio-mastercontainer
 docker ps
 ```

## euro-office:~# history
```bash
apt update
apt upgrade

# Update the system
apt update && apt upgrade -y

# Install Docker dependencies
apt install -y curl gnupg lsb-release

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
docker-compose.yml
ip a
nano /etc/resolv.conf
ping -c 3 google.com
ip route add default via 192.168.1.1
reboot
docker compose up -d
cd /opt/eurooffice/
docker compose up -d
ls -l
curl localhost:8080
nano /opt/eurooffice/docker-compose.yml
docker compose down
docker compose up -d --force-recreate
curl -I http://192.168.0.123:8080
ufw allow 8080/tcp
ufw allow 8443/tcp
ufw enable
curl -I http://192.168.0.123:8080
curl http://localhost:8080
ip a

# start the sample
docker exec -it eurooffice-server sudo supervisorctl start ds:example
cat /opt/eurooffice/docker-compose.yml | grep JWT_SECRET
docker exec -it eurooffice-server sudo supervisorctl status
docker exec -it eurooffice-server sudo supervisorctl start example
docker exec -it eurooffice-server sudo sed -i 's,autostart=false,autostart=true,' /etc/supervisor/conf.d/ds-example.conf
sudo docker exec 780ab9577ee1 sudo supervisorctl start example
sudo docker exec 780ab9577ee1 sudo sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf
sudo docker exec 780ab9577ee1 sudo supervisorctl start adminpanel
sudo docker exec 780ab9577ee1 sudo sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-adminpanel.conf
docker exec -it eurooffice-server sudo supervisorctl start adminpanel
docker exec -it eurooffice-server tail -n 20 /var/log/eurooffice/adminpanel/out.log
docker logs eurooffice-server 2>&1 | grep -i -E "bootstrap|token|code"
docker logs --tail 100 eurooffice-server


# 1. Restart the admin panel service to trigger a new token event
docker exec -it eurooffice-server sudo supervisorctl restart adminpanel

# 2. Immediately read the newest log outputs to capture the token
docker logs --tail 30 eurooffice-server
docker exec -it eurooffice-server sudo /var/www/eurooffice/documentserver/npm/node_modules/unzip/bin/node /var/www/eurooffice/documentserver/server/AdminPanel/manage.js --password=$mynewpassword
docker exec -it eurooffice-server rm -f /var/www/eurooffice/documentserver/server/AdminPanel/config/bootstrap
docker exec -it eurooffice-server sudo supervisorctl restart adminpanel
docker exec -it eurooffice-server node /app/ds/server/AdminPanel/manage.js --password=$mynewpassword
docker exec -it eurooffice-server /var/www/eurooffice/documentserver/server/AdminPanel/node /var/www/eurooffice/documentserver/server/AdminPanel/manage.js --password=$mynewpassword

reboot
cd /opt/eurooffice/
docker compose up -d
docker exec -it eurooffice-server rm -rf /var/www/eurooffice/documentserver/server/AdminPanel/config/bootstrap /etc/eurooffice/documentserver/adminPanelTopology.json
docker exec -it eurooffice-server sudo supervisorctl restart adminpanel
docker exec -it eurooffice-server cat /var/www/eurooffice/documentserver/server/AdminPanel/config/bootstrap
docker exec -it eurooffice-server grep -rnw '/var/www/eurooffice/documentserver/server/AdminPanel/' -e "bootstrap" 2>/dev/null || docker exec -it eurooffice-server find /var/www/ -name "*bootstrap*"
docker inspect eurooffice-server | grep -i token
docker exec -it eurooffice-server /var/www/eurooffice/documentserver/server/AdminPanel/node /var/www/eurooffice/documentserver/server/AdminPanel/manage.js --token
docker exec -it eurooffice-server /var/www/onlyoffice/documentserver/server/AdminPanel/node /var/www/onlyoffice/documentserver/server/AdminPanel/manage.js --token
docker exec -it eurooffice-server bash -c "mkdir -p /var/www/onlyoffice/documentserver/server/AdminPanel/config/ && echo $mynewpassword > /var/www/onlyoffice/documentserver/server/AdminPanel/config/bootstrap"
docker exec -it eurooffice-server sudo supervisorctl restart adminpanel
docker exec -it eurooffice-server ps aux | grep -i adminpanel
docker compose up -d
docker exec -it eurooffice-server ps aux | grep -i adminpanel
docker exec -it eurooffice-server bash -c "rm -rf /var/www/*/documentserver/server/AdminPanel/config/* && rm -f /var/www/onlyoffice/Data/runtime.json /var/www/eurooffice/Data/runtime.json"
docker exec -it eurooffice-server bash -c "find /var/www/ -type d -name "AdminPanel" -exec mkdir -p {}/config/ \; -exec sh -c 'echo \"<mynewpassword>\" > {}/config/bootstrap' \;"
cd /opt/eurooffice
docker compose restart
docker compose up -d
docker exec -it eurooffice-server find / -name "bootstrap" -exec echo "Found path: {}" \; -exec cat {} \; 2>/dev/null
docker exec -it eurooffice-server cat /var/log/supervisor/supervisord.log
cd /opt/eurooffice && docker compose down
nano docker-compose.yml
docker compose up -d
cat /opt/eurooffice/docker-compose.yml | grep ADMIN_PANEL
cd /opt/eurooffice
docker compose up -d --force-recreate
docker exec -it eurooffice-server sudo supervisorctl start adminpanel
docker exec -it eurooffice-server sudo sed -i 's/autostart=false/autostart=true/g' /etc/supervisor/conf.d/ds-adminpanel.conf
docker logs eurooffice-server | tail -n 15
docker exec -it eurooffice-server supervisorctl status adminpanel
nano /opt/eurooffice/docker-compose.yml


# 1. Purge the active stack
cd /opt/eurooffice && docker compose down

# 2. Fire it up clean
docker compose up -d

docker exec -it eurooffice-server bash -c "mkdir -p /var/www/euro-office/documentserver/server/AdminPanel/config/ && echo $mynewpassword > /var/www/euro-office/documentserver/server/AdminPanel/config/bootstrap"

docker logs eurooffice-server | tail -n 15

docker exec -it eurooffice-server bash -c "mkdir -p /var/www/euro-office/documentserver/server/AdminPanel/config/ && echo $mynewpassword > /var/www/euro-office/documentserver/server/AdminPanel/config/bootstrap"

docker logs eurooffice-server | tail -n 15

docker exec -it eurooffice-server supervisorctl status adminpanel
docker exec -it eurooffice-server sudo supervisorctl start adminpanel
docker exec -it eurooffice-server supervisorctl status adminpanel

docker exec -it eurooffice-server bash -c "mkdir -p /var/www/euro-office/documentserver/server/AdminPanel/config/ && echo $mynewpassword > /var/www/euro-office/documentserver/server/AdminPanel/config/bootstrap"

docker exec -it eurooffice-server cat /var/www/euro-office/documentserver/server/AdminPanel/config/bootstrap

docker exec -it eurooffice-server supervisorctl restart adminpanel
docker exec -it eurooffice-server cat /var/www/euro-office/documentserver/server/AdminPanel/config/bootstrap
docker exec -it eurooffice-server supervisorctl restart adminpanel
docker exec -it eurooffice-server /var/www/euro-office/documentserver/server/AdminPanel/node /var/www/euro-office/documentserver/server/AdminPanel/manage.js --token
docker exec -it eurooffice-server bash
```

# setup Production site
To remove the example/test dashboard and turn Euro-Office into an actual production site, disable the built-in example app and connect the Euro-Office Document Server to a live storage host platform (like [Nextcloud Hub](https://nextcloud.com/blog/how-to-install-euro-office/)).

Because Euro-Office is structurally designed only as an editing engine, it does not have its own built-in file management or user login page. 

The "example page" you see is just a developer welcome script.  
Follow this step-by-step framework to transition to your actual production environment:

## 1. Disable the Example Welcome Page
If you deployed Euro-Office via Docker, the example script is running because of an internal setting. You need to turn it off. 

* verify what is running:
```bash 
euro-office:~# docker exec -it eurooffice-server sudo supervisorctl status
adminpanel                       RUNNING   pid 738, uptime 13 days, 13:22:51
converter                        RUNNING   pid 321, uptime 13 days, 13:29:43
docservice                       RUNNING   pid 322, uptime 13 days, 13:29:43
example                          STOPPED   Not started
metrics                          STOPPED   Not started 
```

* Via the terminal: Enter your container and run the built-in command to disable it:

```bash
docker exec -it eurooffice-server sudo supervisorctl stop example
docker exec -it eurooffice-server sudo supervisorctl remove example
```


* Via Docker Compose: If your docker-compose.yml file features an explicit welcome or example service block, delete or comment out that specific container definition. [5, 6] 

## 2. Set Up a Secure JWT Secret Key
To ensure your actual site edits are secure and private, you must generate a JWT token. This key prevents unauthorised servers from hijacking your document editing sessions. [3, 7] 

   1. Run this command in your server's terminal to generate a secure string:
   2. Open your Euro-Office configuration file (or your Docker environmental variables).
   3. Apply your generated string to the JWT parameters:

```bash

# 1. Navigate to your directory
cd /opt/eurooffice/

# 2. Generate the 32-byte hex string and store it in a variable
NEW_JWT_SECRET=$(openssl rand -hex 32)

# 3. Replace the placeholder token in your .env file with the new one
# sed -i "s/JWT_SECRET=YourSuperSecureSecretTokenHere/JWT_SECRET=$NEW_JWT_SECRET/" .env
sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_JWT_SECRET/" .env

# 4. (Optional) Verify it changed successfully
cat .env | grep JWT_SECRET

docker compose up -d --force-recreate

```   

   
   JWT_ENABLED=true
   JWT_SECRET=your_generated_secure_string_here
   


## 3A. Connect to a Storage Host Platform (The "Actual Site")
Since Euro-Office does not save files natively, you need to connect it to your actual file storage server. Most setups leverage Nextcloud. 

   1. Log in to your live Nextcloud administrator portal. [11] 
   2. Navigate to Apps > Office & text. [11] 
   3. Find the official Euro-Office integration app, then click Download and enable. [11] 
   4. Go to your Nextcloud Administration Settings > Euro-Office panel. [11] 
   5. In the fields provided, link the two services together:
   * Document Server Address: Enter the actual web domain or local IP where your Euro-Office container is running (e.g., https://yourcompany.com).
      * Secret Key: Paste the exact same JWT Secret Key you generated in Step 2. [3, 7, 12] 




## 3B. Connect Nextcloud via CLI (occ tool)

Instead of using the Nextcloud web portal, you can configure the Euro-Office integration directly from your Nextcloud server's command line using its built-in occ utility.Note: Run these commands on your Nextcloud server (or inside your Nextcloud container if it is containerised).bash# 1. Install the Euro-Office integration app
sudo -u www-data php occ app:install eurooffice

**Enable the app**

sudo -u www-data php occ app:enable eurooffice

# 3. Set your Euro-Office Document Server URL
sudo -u www-data php occ config:app:set eurooffice ServerUrl --value="http://<YOUR_SERVER_IP>:8080"

# 4. Set the matching JWT Secret Key (Use the string generated in Step 1)
sudo -u www-data php occ config:app:set eurooffice secret --value="PASTE_YOUR_GENERATED_SECRET_HERE"
Use code with caution.(If your Nextcloud runs in Docker, replace sudo -u www-data php occ with docker exec --user www-data nextcloud-container-name php occ)
   
## 4. Test Your Production Environment
Once saved, users can log into Nextcloud, click on any Word, Excel, or PowerPoint format file (DOCX, XLSX, PPTX), and the actual Euro-Office web workspace will launch seamlessly directly within their browser session. [13, 14] 
Are you hosting this on a local home server or a public cloud domain? Let me know your current hosting environment, and I can give you the exact network configuration blocks you need!

[1] [https://nextcloud.com](https://nextcloud.com/blog/how-to-install-euro-office/)
[2] [https://dbtechreviews.com](https://dbtechreviews.com/2026/04/08/euro-office-doesnt-need-nextcloud-and-that-changes-everything/)
[3] [https://www.it-connect.tech](https://www.it-connect.tech/euro-office-the-open-source-alternative-to-microsoft-office/)
[4] [https://www.youtube.com](https://www.youtube.com/watch?v=qG8nlJO9VqI)
[5] [https://euro-office.github.io](https://euro-office.github.io/documentation/development/setup/)
[6] [https://euro-office.github.io](https://euro-office.github.io/documentation/installation/example/)
[7] [https://www.youtube.com](https://www.youtube.com/watch?v=9sf9OnoIcc4)
[8] [https://www.it-connect.tech](https://www.it-connect.tech/euro-office-the-open-source-alternative-to-microsoft-office/)
[9] [https://euro-office.github.io](https://euro-office.github.io/documentation/integration/nextcloud/)
[10] [https://euro-office.github.io](https://euro-office.github.io/documentation/)
[11] [https://www.it-connect.tech](https://www.it-connect.tech/euro-office-the-open-source-alternative-to-microsoft-office/)
[12] [https://github.com](https://github.com/Euro-Office/eurooffice-nextcloud)
[13] [https://www.youtube.com](https://www.youtube.com/watch?v=Yv3zVjWLI94)
[14] [https://www.itpro.com](https://www.itpro.com/software/business-apps/everything-you-need-to-know-about-euro-office-europes-open-source-alternative-to-microsoft-office-and-google-docs-including-features-launch-dates-and-how-to-access-it)
