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
cat /etc/resolv.conf

apt install freeipa-client
sudo nano /etc/resolv.conf 

nslookup ipa.gardenofrot.cc

ipa-client-install --mkhomedir
grep paul /etc/passwd
grep admin /etc/passwd
getent passwd admin
getent passwd paul
getent passwd user1
```

## How to join Ubuntu 18.04 with FreeIPA Identity management server

```bash
sudo nano /etc/resolv.conf
```
 
```conf
# nameserver 127.0.0.53
nameserver 192.168.1.200 
options edns0 trust-ad
search .
```







https://www.google.com/search?q=ubuntu+join+to+freeipa+domain&num=10&sca_esv=e10ce1b38eab34ab&sxsrf=ADLYWIIOk8QJM5wf4A4UhNlwVg_HQv_lqQ%3A1733022947572&ei=49RLZ__RItmOseMPgc2OuAU&ved=0ahUKEwi_z7XJzYWKAxVZR2wGHYGmA1cQ4dUDCA8&uact=5&oq=ubuntu+join+to+freeipa+domain&gs_lp=Egxnd3Mtd2l6LXNlcnAiHXVidW50dSBqb2luIHRvIGZyZWVpcGEgZG9tYWluMggQABiABBiiBDIIEAAYgAQYogQyCBAAGIAEGKIESKAPUPsJWPYNcAF4AZABAJgBjAKgAYwCqgEDMi0xuAEDyAEA-AEBmAICoAKUAsICChAAGLADGNYEGEeYAwCIBgGQBgeSBwUxLjAuMaAH9AI&sclient=gws-wiz-serp#fpstate=ive&vld=cid:cdf2f90c,vid:BhVygK0DNPA,st:0

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

# Start keycloak
```bash
# First bootstrape with a temporary admin account
bin/kc.sh bootstrap-admin user

#then start the service
bin/kc.sh start --https-certificate-file=/home/freeipa/admin-paul/certs/keycloak.gardenofrot.cc.pem --https-certificate-key-file=/home/freeipa/admin-paul/certs/keycloak.gardenofrot.cc.key --hostname keycloak.gardenofrot.cc 

#--bootstrap-admin-username tmpadm --bootstrap-admin-password pass


```