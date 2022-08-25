#Use kvm and Virt-Install in cli

Create a debian server in a virtual machine from a command line.

```bash
virt-install --virt-type kvm --name buster-amd64 \
--location http://deb.debian.org/debian/dists/buster/main/installer-amd64/ \
--os-variant debian10 \
--disk size=10 --memory 1000 \
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0"
```
