# Create a Mirror 

## Check what repos are on the Server

```bash
dnf repo list

repo id                      repo name                                                                                                         
fedora                       Fedora 41 - x86_64                                                                                                
fedora-cisco-openh264        Fedora 41 openh264 (From Cisco) - x86_64                                                                          
updates                      Fedora 41 - x86_64 - Updates  
zfs                          ZFS on Linux for EL41 - dkms           

```

### Remove the Repo
```bash
sudo rm /etc/yum.repos.d/zfs.repo
```

## Add VC Code Repo
```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null


dnf check-update
dnf repo list

```


## Test with code on RHEL9 add the GPG for the RPM Repo

```bash
# or use a RMP file
sudo dnf install https://zfsonlinux.org/epel/zfs-release-2-3.el9.noarch.rpm


#sudo dnf config-manager --set-disabled fedora 
sudo dnf config-manager --set-disabled fedora-cisco-openh264
sudo dnf config-manager --set-disabled updates
```


## sync only the fedora and zf  repo.  shold run these on a chrom job
```bash 
sudo dnf reposync --delete -p /mnt/packages/ --repoid=fedora --newest-only --download-metadata
sudo dnf reposync --delete -p /mnt/packages/ --repoid=code --newest-only --download-metadata

``` 

## Use of synced Repos 
```bash
$ cd /etc/yum.repos.d/
$ ls -la

total 28
drwxr-xr-x.   2 root root  121 Mar 29 12:55 .
drwxr-xr-x. 113 root root 8192 Mar 29 13:52 ..
-rw-r--r--.   1 root root 1102 Oct 18 11:00 fedora-cisco-openh264.repo
-rw-r--r--.   1 root root 1239 Oct 18 11:00 fedora.repo
-rw-r--r--.   1 root root 1286 Oct 18 11:00 fedora-updates.repo
-rw-r--r--.   1 root root 1344 Oct 18 11:00 fedora-updates-testing.repo
```

```bash
vi zfs-local..repo
```


# start the HTTP server
```bash
sudo dnf install httpd -y
sudo systemctl status httpd.service
sudo systemctl enable httpd.service

sudo systemctl start httpd.service
sudo systemctl status httpd.service

```
## Generate cert 

```config
# the fully qualified server (or service) name
FQDN = downloader.gardenofrot.cc

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
openssl req /
  -new /
  -config ~/certs/downloader.gardenofrot.cc.cnf /
  -keyout ~/certs/downloader.gardenofrot.cc.key /
  -out ~/certs/downloader.gardenofrot.cc.csr
```

### generated Certificate from IPA

On FreeIPA server
```bash
ipa cert-request --principal=host/downloader.gardenofrot.cc downloader.gardenofrot.cc.csr
```
Download the PEM file
```bash
ls -l
total 16
-rw-r--r--. 1 admin-paul admin-paul  987 Mar 29 17:18 downloader.gardenofrot.cc.cnf
-rw-r--r--. 1 admin-paul admin-paul 1037 Mar 29 17:18 downloader.gardenofrot.cc.csr
-rw-------. 1 admin-paul admin-paul 1704 Mar 29 17:18 downloader.gardenofrot.cc.key
-rw-------. 1 admin-paul admin-paul 1720 Mar 29 17:24 downloader.gardenofrot.cc.pem
```
## Add HTTPS to HTTPD
```bash
sudo dnf install mod_ssl -y
sudo cp ~/certs/downloader.gardenofrot.cc.key /etc/pki/tls/private/downloader.gardenofrot.cc.key
# .pem and .crt are the same
sudo mv ~/certs/downloader.gardenofrot.cc.pem /etc/pki/tls/certs/downloader.gardenofrot.cc.crt

sudo mv ~/certs/downloader.gardenofrot.cc.key /etc/pki/tls/private/downloader.gardenofrot.cc.key

sudo mv ~/certs/downloader.gardenofrot.cc.pem /etc/pki/tls/certs/downloader.gardenofrot.cc.crt

restorecon /etc/pki/tls/private/downloader.gardenofrot.cc.key
restorecon /etc/pki/tls/certs/downloader.gardenofrot.cc.crt
sudo chown root:root /etc/pki/tls/private/downloader.gardenofrot.cc.key 
sudo chown root:root /etc/pki/tls/certs/downloader.gardenofrot.cc.crt

sudo chmod 0600 /etc/pki/tls/private/downloader.gardenofrot.cc.key     
sudo chmod 0600 /etc/pki/tls/certs/downloader.gardenofrot.cc.crt
```

The default TLS/SSL configuration is contained in the file /etc/httpd/conf.d/ssl.conf. In the ssl.conf file, following are the directives that specify where the TLS/SSL certificate and key are located:
```bash

cat /etc/httpd/conf.d/ssl.conf
sudo vi /etc/httpd/conf.d/ssl.conf

sudo vi /etc/httpd/conf.d/ssl.conf

sudo vi /etc/httpd/conf.d/zvhost-fedora-webserver.gardenofrot.cc.conf 

```

```conf
        # ===============================================================
        # Directory Locations
        # ===============================================================
        DirectoryIndex  index.html
        DocumentRoot    /srv/fedora-webserver.gardenofrot.cc/htdocs
        # Specific to default 2.4 configuration:
        # Enable access to server-specific base file location
        <Directory "/srv/fedora-webserver.gardenofrot.cc">
                AllowOverride None
                # Allow open access:
                Require all granted
        </Directory>
        # Further relax access to the default document root
        <Directory "/srv/fedora-webserver.gardenofrot.cc/htdocs">
                #
                # Possible values for the Options directive are "None", "All",
                # or any combination of:
                #   Indexes Includes FollowSymLinks SymLinksifOwnerMatch ExecCGI MultiViews
                #
                # Note that "MultiViews" must be named *explicitly* --- "Options All"
                # doesn't give it to you.
                #
                # The Options directive is both complicated and important.  Please see
                # http://httpd.apache.org/docs/2.4/mod/core.html#options
                # for more information.
                #
                Options Indexes FollowSymLinks

                #
                # AllowOverride controls what directives may be placed in .htaccess files.
                # It can be "All", "None", or any combination of the keywords:
                #   Options FileInfo AuthConfig Limit
                #
                AllowOverride None

                #
                # Controls who can get stuff from this server:
                # Allow open access:
                Require all granted

        </Directory>

```
## Resart httpd service
```bash
sudo systemctl restart httpd.service
sudo systemctl status httpd.service

```



File this in the file and update it.

```conf
SSLCertificateFile /etc/pki/tls/certs/downloader.gardenofrot.cc.crt
SSLCertificateKeyFile /etc/pki/tls/private/downloader.gardenofrot.cc.key
```
```bash
sudo firewall-cmd --add-service https
sudo firewall-cmd --permanent --zone=public --add-service=https 
sudo firewall-cmd --reload
```

/home/paul/vm-images/shared/packages/code

```bash
# Edit the HTTPD file
sudo vi /etc/httpd/conf.d/zvhost-fedora-webserver.gardenofrot.cc.conf 
sudo systemctl restart httpd.service
```

```xml
# Ensure that Apache listens on port 80
Listen 80
<VirtualHost *:80>
    DocumentRoot "/home/paul/vm-images/shared/packages/code"
    ServerName downloader.gardenofrot.cc

    # Other directives here
</VirtualHost>

<VirtualHost *:443>
    DocumentRoot "/home/paul/vm-images/shared/packages/code"
    ServerName downloader.gardenofrot.cc

    # Other directives here
</VirtualHost>
```

# Virt-Manager - qeum/kvn


## In Virtual Manager
Add Hardware:  filesystem

```xml
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <binary path="/usr/lib/qemu/virtiofsd"/>
  <source dir="/home/paul/vm-images/shared/packages"/>
  <target dir="packages_tag"/>
  <alias name="fs0"/>
  <address type="pci" domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
</filesystem>


```

## On Guest
```bash


sudo mkdir /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages
sudo mount -t virtiofs packages /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages
#sudo mount -t virtiofs  -o v3,fscontext=unconfined_u:object_r:httpd_sys_content_t:s0 packages /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages
sudo mount -t virtiofs  -o fscontext=unconfined_u:object_r:httpd_sys_content_t:s0 packages /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages


ls -la /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages


sudo mkdir /mnt/packages
sudo mount -t virtiofs packages_tag /mnt/packages

sudo chmod o+x /root /root/site /root/site/about
sudo chmod o+x /mnt /mnt/packages

sudo chmod o+x /srv/fedora-webserver.gardenofrot.cc/htdocs/other/packages
sudo chmod o+x /srv/fedora-webserver.gardenofrot.cc/htdocs/other
sudo chmod o+x /srv/fedora-webserver.gardenofrot.cc
sudo chmod o+x /srv




sh-5.2$ ls -la /mnt/packages/
total 12
drwxrwxrwx. 4 paul       paul       4096 Mar 29 22:59 .
drwxr-xr-x. 1 root       root         16 Apr  5 22:08 ..
-rw-r--r--. 1 admin-paul admin-paul    0 Mar 29 14:21 aaa.txt
drwxr-xr-x. 4 root       root       4096 Mar 29 16:24 code
drwxr-xr-x. 4 root       root       4096 Mar 29 15:53 fedora
sh-5.2$ 
```


# Create Docker image rto Sync the Repos

GitHub Copilot
Here is an example of what the mirror-repo.sh file could contain. This script will sync the specified RPM repository and serve it using an HTTP server:

Explanation:
Variables:

REPO_DIR: Directory where the mirrored repository will be stored.
REPO_ID: The repository ID to sync (e.g., fedora, updates, etc.).
LOG_FILE: Log file to capture the output of the sync process.
Repository Sync:

Uses dnf reposync to download the repository packages and metadata.
Metadata Creation:

Uses createrepo to generate repository metadata for the mirrored repository.
HTTP Server:

Starts the Apache HTTP server in the foreground to serve the mirrored repository.
Notes:
Replace fedora in REPO_ID with the repository you want to mirror.
Ensure the container has the necessary permissions to write to /var/www/html/repo.
Logs are written to /var/log/repo-sync.log for debugging purposes.
mckeepa
what are the commands to build the image and run the container

GitHub Copilot
Here are the commands to build the Docker image and run the container:

1. Build the Docker Image
Navigate to the directory containing the Dockerfile and run the following command:

2. Run the Container
Run the container, mapping the HTTP server's port to the host:

3. Verify the HTTP Server
After the container starts, you can verify the repository is being served by accessing it in your browser or using curl:

Notes:
Replace 8080 with a different port if needed.
The -d flag runs the container in detached mode.
The --name flag assigns a name to the container for easier management.