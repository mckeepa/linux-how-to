# Use kvm and Virt-Install in cli

Create a debian server in a virtual machine from a command line.

 - change to use local images
 - update to for linux install paramters so that no interaction is needed.

```bash
virt-install --virt-type kvm --name buster-amd64 \
--location http://deb.debian.org/debian/dists/buster/main/installer-amd64/ \
--os-variant debian10 \
--disk size=10 --memory 1000 \
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0"
```

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



