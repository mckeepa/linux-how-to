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
