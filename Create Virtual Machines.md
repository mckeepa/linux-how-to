# Use kvm and Virt-Install in cli

Create a debian server in a virtual machine from a command line.

 - change to use local images
 - update to for linux install paramters so that no interaction is needed.

```bash
virt-install --virt-type kvm --name buster-amd64 \
--location http://deb.debian.org/debian/dists/buster/main/installer-amd64/ \
--os-variant debian10 \
--disk size=10 
--memory 1024 \
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0"
```

virt-install --name test01 --description 'Fedora 36 Server - Test01' --ram 4096 --vcpus 2 --disk path=/var/lib/libvirt/images/guest-test01.qcow2 --os-variant fedora36 --network bridge=br0 --graphics vnc,listen=127.0.0.1,port=5901 --cdrom /var/lib/libvirt/images/Fedora-Server-dvd-x86_64-36-1.5.iso --noautoconsole

virt-install --virt-type kvm --name test01 \
--cdrom /var/lib/libvirt/images/Fedora-Server-dvd-x86_64-36-1.5.iso \
--os-variant fedora \
--disk size=10 
--memory 1024 \
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0"


virt-install --name test01 --description 'Fedora 36 Server - Test01' --ram 4096 --vcpus 2 --disk path=/var/lib/libvirt/images/guest-test01.qcow2,size=10 --os-variant fedora36 --network bridge=br0 --graphics vnc,listen=127.0.0.1,port=5901 --cdrom /data/Fedora-Server-dvd-x86_64-36-1.5.iso --noautoconsole

Starting install...
Allocating 'guest-test01.qcow2'                                                                                                      |    0 B  00:00:00 ...
Creating domain...                                                                                                                   |    0 B  00:00:00

Domain is still running. Installation may be in progress.
You can reconnect to the console to complete the installation process.

 virsh console test01 --safe


## List all Images

```bash
virsh list --all

virsh net-define /usr/share/libvirt/networks/default.xml
# Network default defined from /usr/share/libvirt/networks/default.xml

# Network default marked as autostarted
virsh net-autostart default

# Network default started
virsh net-start default


```
## Starting Network  

https://linuxconfig.org/how-to-use-bridged-networking-with-libvirt-and-kvm

```bash
# List all virtyual Networks
virsh net-list --all
sudo virsh net-list --all
sudo virsh net-edit default

ip link show type bridge

```

## Ensure Graphic port is set to -1 and autoport is true


```bash
sudo virsh edit  k8-node-01.local
```

```xml
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
```

## Starting VM 

```bash
virsh start buster-amd64  --console
sudo virsh start k8-control-plane.local  --console
```
# Get IP Addresses

```bash
virsh net-dhcp-leases default
```

# Create Bridged network interface on Host

https://getlabsdone.com/how-to-create-a-bridge-interface-in-centos-redhat-linux/


The bidged network allows the VM's network (virbr0 - 192.168.122.xx) to talk to the lan (enp0s31fg - 192.168.1.xxx)
```bash
nmcli con show
nmcli connection add type bridge con-name br0 ifname br0
nmcli con show
```
At this point, the physical and bridge interfaces are two separate interfaces. We will have to connect both and make the br0 as primary. Enter the command below to connect the physical interface to the bridge.
```bash
nmcli con add type ethernet ifname enp0s31fg master br0
nmcli dev status

# Configure 
nmcli con mod br0 ipv4.addresses 192.168.1.134/24
nmcli con mod br0 ipv4.gateway 192.168.1.1
nmcli con mod br0 ipv4.dns 8.8.8.8
nmcli con mod br0 ipv4.method manual

# interface is still down
ip addr

15: br0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 6a:ac:24:54:06:5d brd ff:ff:ff:ff:ff:ff

```

## allow br0

```bash
sudo nano /etc/qemu/bridge.conf
```
allow virbr0
allow br0


# bring up the Bridge interface
```bash
# nmcli con up br0
Connection successfully activated (master waiting for slaves) (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/23)

```
If you check the IP address on the system, You can see both the physical and the bridge interface has the same IP address configured and the bridge interface state is still down.

```bash 

nmcli networking off
nmcli networking on
```
The bridge network configuration files are here  /etc/sysconfig/network-scripts 

![image](https://user-images.githubusercontent.com/271460/189523958-55b07967-a15e-41a2-ba0a-7fad8c9a596c.png)



# backup / Resore VM

```bash 
sudo virsh list --all   
 Id   Name                     State
-----------------------------------------
 9    k8-node-01.local         running
 10   k8-control-plane.local   running
 -    fedora-k8-vm             shut off


sudo virsh domblklist k8-control-plane.local
 Target   Source
------------------------------------------------------
 vda      /var/lib/libvirt/images/guest-harbor.qcow2
```

## Backup
```bash

sudo virsh  backup-begin k8-control-plane.local   

sudo virsh domjobinfo k8-control-plane.local
Job type:         Unbounded
Operation:        Backup
Time elapsed:     13770        ms
File processed:   9.321 GiB
File remaining:   10.679 GiB
File total:       20.000 GiB
```

list the files 
'guest-harbor.qcow2.1662986226' is the backup.

```bash
sudo ls -lash /var/lib/libvirt/images/
total 18G
   0 drwx--x--x. 1 root root  228 Sep 12 22:37 .
   0 drwxr-xr-x. 1 root root  104 Sep 11 13:33 ..
3.7G -rw-------. 1 qemu qemu  21G Sep 12 22:44 Fedora36.qcow2
964K -rw-------. 1 qemu qemu 5.1G Aug 25 22:41 fedora-k8-vm.qcow2
2.2G -rw-r--r--. 1 qemu qemu 2.2G Aug  6 19:11 Fedora-Server-dvd-x86_64-36-1.5.iso
5.8G -rw-r--r--. 1 qemu qemu 5.8G Sep 12 22:44 guest-harbor.qcow2
5.8G -rw-------. 1 root root 5.8G Sep 12 22:37 guest-harbor.qcow2.1662986226
```


# Backup and Restore
```bash
sudo virsh list --all            
export VM_NAME='kube-workernode-00.k8'
sudo virsh dumpxml $VM_NAME;

sudo mkdir -p /opt/backup/kvm/;  
sudo -i

export VM_NAME='kube-workernode-00.k8'
virsh dumpxml $VM_NAME > "/opt/backup/kvm/$VM_NAME.xml"; 
cp /var/lib/libvirt/images/kube-workernode-00.k8.qcow2 /opt/backup/kvm/;
```


## Restore your KVM virtual machine
Begin by erasing the virtual machine’s hard disk and undefining the VM so that it does not exist any longer. 
Using the domblklist command, identify the qcow2 files to be deleted. 
Make sure that the VM is stopped using the shutdown command, then delete the file(s) from the hard drive:

```bash
rm /var/lib/libvirt/images/nba.qcow2;
```

## Remove the VM definition:
Need to remove the existing definition before restoring a backup.
```bash
virsh undefine $VM_NAME;
```

### Restore the virtual machine (VM).
Bring back the virtual machine that was removed, first get back the hard drive:

```bash
cp /opt/backup/kvm/nba.qcow2 /var/lib/libvirt/images/;
```
Bring back the original definition of the domain.
```bash
virsh define --file "/opt/backup/kvm/$VM_NAME.xml";
```
If moving it to a different physical host, check to see if the information included within the XML file needs to be updated. 
Check to see if the new physical host has network interfaces, for instance...

Execute the following to check that the parameters of your virtual machine (VM) have been successfully defined:
```bash
virsh list --all;
```
Sart using the VM:
```bash 
virsh start $VM_NAME;
```

Once the virtual machine (VM) is up and running, use SSH to log into it and check that everything was correctly restored.


# File Sharing (virtiofs) - used in Persistant Volumes (PV)

## on Client

mount -t virtiofs host_shared /mnt/host-share/

sudo mkdir -p /mnt/data/
sudo mount -t virtiofs host_shared /mnt/data/
ls -la /mnt/data/

findmnt 
findmnt /mnt/host-share

## follow creating a pod with mount
https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/

```bash
# This again assumes that your Node uses "sudo" to run commands
# as the superuser
sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/index.html"

```
pv-volume.yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

```bash
kubectl apply -f https://k8s.io/examples/pods/storage/pv-volume.yaml
```
