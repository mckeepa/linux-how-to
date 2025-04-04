# Setup FreeIPA

Following this: https://www.freeipa.org/page/Quick_Start_Guide

## Set Hostname

The IPA installer is picky about the DNS configuration. 
The following checks are done by installer:
 - The hostname cannot be localhost or localhost6.
 - The hostname must be fully-qualified (server.ipa.test)
 - The hostname must be resolvable.
 - The reverse of address that it resolves to must match the hostname.

Set the Hostname 
```bash
sudo cat /etc/hostname
sudo hostnamectl set-hostname --pretty "ipa.gardenofrot.cc"
sudo hostnamectl set-hostname --static "ipa.gardenofrot.cc"
```

## Update System
```bash
sudo dnf update
dnf upgrade
sudo reboot now
```

## Open Firewall

"**freeipa-ldaps**" is deprecated. \
Can use jus "**freeipa-4**"
``` bash
sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps --permanent
sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps

sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-4 --permanent
sudo firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-4
```

##  Install using DNF

```bash
sudo dnf install freeipa-server
kinit admin
man ipa
ipa user-add
kinit paul
ipa passwd paul
``` 

# Client

```bash
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl status ssh

cat /etc/lsb-release 
hostname -f
sudo hostnamectl set-hostname newhostname
cat /etc/resolv.conf

apt install freeipa-client
sudo nano /etc/resolv.conf 

nslookup freeipa.gardenofrot.cc


# Firewall
for i in 80 443 389 636 88 464; do sudo ufw allow proto tcp from any to any port $i; done
for i in 88 464 123; do sudo ufw allow proto udp from any to any port $i; done
sudo ufw reload


ipa-client-install --mkhomedir
grep paul /etc/passwd
grep admin /etc/passwd
getent passwd admin
getent passwd paul
getent passwd user1
```

## How to join Ubuntu 18.04 with FreeIPA Identity management server

```bash
sudo ipa-client-install
```

```text
This program will set up IPA client.
Version 4.12.2

DNS discovery failed to determine your DNS domain
Provide the domain name of your IPA server (ex: example.com): gardenofrot.cc
Provide your IPA server name (ex: ipa.example.com): freeipa.gardenofrot.cc
The failure to use DNS to find your IPA server indicates that your resolv.conf file is not properly configured.
Autodiscovery of servers for failover cannot work with this configuration.
If you proceed with the installation, services will be configured to always access the discovered server for all operations and will not fail over to other servers in case of failure.
Proceed with fixed values and no DNS discovery? [no]: yes
Do you want to configure chrony with NTP server or pool address? [no]: yes
Enter NTP source server addresses separated by comma, or press Enter to skip: freeipa.gardenofrot.cc
Enter a NTP source pool address, or press Enter to skip: 
Client hostname: downloader.gardenofrot.cc
Realm: GARDENOFROT.CC
DNS Domain: gardenofrot.cc
IPA Server: freeipa.gardenofrot.cc
BaseDN: dc=gardenofrot,dc=cc
NTP server: freeipa.gardenofrot.cc

Continue to configure the system with these values? [no]: yes
Synchronizing time
Configuration of chrony was changed by installer.
Attempting to sync time with chronyc.
Process chronyc waitsync failed to sync time!
Unable to sync time with chrony server, assuming the time is in sync. Please check that 123 UDP port is opened, and any time server is on network.
User authorized to enroll computers: root
Password for root@GARDENOFROT.CC: 
Successfully retrieved CA cert
    Subject:     CN=Certificate Authority,O=GARDENOFROT.CC
    Issuer:      CN=Certificate Authority,O=GARDENOFROT.CC
    Valid From:  2024-12-30 12:10:14+00:00
    Valid Until: 2044-12-30 12:10:14+00:00

Enrolled in IPA realm GARDENOFROT.CC
Created /etc/ipa/default.conf
Configured /etc/sssd/sssd.conf
Systemwide CA database updated.
Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub
Adding SSH public key from /etc/ssh/ssh_host_ed25519_key.pub
Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub
Could not update DNS SSHFP records.
SSSD enabled
Configured /etc/openldap/ldap.conf
Unable to find 'root' user with 'getent passwd root@gardenofrot.cc'!
Unable to reliably detect configuration. Check NSS setup manually.
Configured /etc/ssh/ssh_config
Configured /etc/ssh/sshd_config.d/04-ipa.conf
Configuring gardenofrot.cc as NIS domain.
Configured /etc/krb5.conf for IPA realm GARDENOFROT.CC
Client configuration complete.
The ipa-client-install command was successful
```conf
# nameserver 127.0.0.53
nameserver 192.168.1.200 
options edns0 trust-ad
search .
```

## Enable Make Home Directory
```bash
sudo authselect enable-feature with-mkhomedir
```

https://www.linuxtechi.com/configure-freeipa-client-on-ubuntu/


## How to join Fedora 41  with FreeIPA Identity management server
https://www.freeipa.org/page/ConfiguringFedoraClients


This should install all the dependencies as well.

1. Instal the client
```bash
sudo yum install ipa-client
```
2. If your IPA server was set up for DNS, and is in the same domain as the client, add the server’s IP address to the client’s /etc/resolv.conf file.

So add a line that looks something like (depending on the IP address of your IPA server).

nameserver 192.168.100.1




# Create SSL Certificate for Web Service

Create Certificate Signing Request (CSR) configuration

```
vi ~/certs/keycloak.gardenofrot.cc.cnf 
```

```bash

# OpenSSL configuration file for creating a CSR for a server certificate
# Adapt at least the FQDN and ORGNAME lines, and then run 
# openssl req -new -config myserver.cnf -keyout myserver.key -out myserver.csr
# on the command line.

# the fully qualified server (or service) name
FQDN = keycloak.gardenofrot.cc

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


Create the CSR
```bash
openssl req -new -config ~/certs/keycloak.gardenofrot.cc.cnf -keyout ~/certs/keycloak.gardenofrot.cc.key -out ~/certs/keycloak.gardenofrot.cc.csr

```

Copy the CRS contents
```bash 
cat ~/certs/keycloak.gardenofrot.cc.csr
```

## On the FreeIPA server cli

```bash
ipa cert-request --principal=host/keycloak.gardenofrot.cc keycloak.gardenofrot.cc.csr
```

Copy Certificate '/home/freeipa/admin-paul/certs/keycloak.gardenofrot.cc.pem' to server
Restrict access to only the owner 
```bash 
chmod go-rwx keycloak.gardenofrot.cc.pem
```


# Start keycloak
```bash
# First bootstrape with a temporary admin account
bin/kc.sh bootstrap-admin user

#then start the service
bin/kc.sh start --https-certificate-file=/home/freeipa/admin-paul/certs/keycloak.gardenofrot.cc.pem --https-certificate-key-file=/home/freeipa/admin-paul/certs/keycloak.gardenofrot.cc.key --hostname keycloak.gardenofrot.cc 

#--bootstrap-admin-username tmpadm --bootstrap-admin-password pass


```