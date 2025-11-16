#!/bin/bash

# Giving Podman access to ports below 1024
# On Linux, unprivileged users cannot open ports below port number 1024. This limitation also applies to Podman, so by default, rootless containers cannot expose ports below port number 1024. You can remove this limitation temporarily using the following command:
sysctl net.ipv4.ip_unprivileged_port_start=0

# To remove the limitation permanently, run 
sysctl -w net.ipv4.ip_unprivileged_port_start=0.
# Note that this allows all unprivileged applications to bind to ports below 1024.



#stop all running containers
sudo podman stop $(sudo podman ps -q)
sudo podman rm $(sudo podman ps -aq)

#sudo podman ps -all
#sudo podman rm ec47032d334c
cd ./rpm-repo-mirror
sudo podman build -t rpm-repo-mirror .
sudo podman run -v /mnt/packages:/mnt/packages:Z -it -p 8081:80 --name rpm-repo-mirror rpm-repo-mirror
cd ..


cd ./webserver
sudo podman build -t file-browser .
sudo podman run -d -p 8080:80 -v /mnt/packages:/mnt/packages:Z file-browser
cd ..