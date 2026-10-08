# Configure compute resources
Next steps will be configure root access via password and key.
I created the [`machines.txt`](../../K8build/machines.txt) file to allow bulk configuration of all VMs.

## Configure Root SSH access
As this is a lab environment I will configure root SSH access for convenience. This is major security vulnerability and should not be done in production.

The version of Debian I am  using requires enabling the Root account first so for each VM I will need to:
- Enable Root account
```
sudo passwd root
```
- Enable SSH via Root account
This is done by changing the 
``` 
/etc/ssh/sshd_config file
PermitRootLogin yes
PasswordAuthentication yes
```

## Configure SSH access via public/private key
On the jumpbox perform "su" to switch to the root user.

First I need to generate SSH key:
```
ssh-keygen
```
Next copy to all machines:
```
while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@${IP}
done < machines.txt
```
There will be prompt for the root password of each vm, this is expected.

I can validate that the public public key generated on jumpbox matches what's on the VM:
```
"cat ~/.ssh/id_rsa"
Confirm it matches the key on each VM:
"cat ~/.ssh/authorized_keys"
```
If matching you I can now ssh via:
```
ssh root@TheIPofTheVm
```

## Configure Hostfile and hostname of compute resources

For ease of admin lets configure hostnames so I do not need to remember IPs of each compute VM.

This wll be done in four sections:
-   Configure the Hostfile and own hostname.
-   Configure Hostfiles to include all other compute VMs.
-   Update Hostfile for jumpbox.
-   Update Hostfile of compute VMs.
### Configure the Hostfile and hostname

I will start with adding the VMs own hostname to it its Hostfile:
```
while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl set-hostname ${HOST}
    ssh -n root@${IP} systemctl restart systemd-hostnamed
done < machines.txt
```
Some notes:
Within  the /etc/hosts folder on each vm, find the line starting with 127....
Replace it with 127... then a tab(\t) then add the FQDN and hostname. 
This only changes the hostfile not the actual hostname, hostnamectl is needed
to actually update the hostname.
A slight alteration was made of the original documentation as the host Ip was "127.0.1.1", however this
did not match what I had "127.0.0.1", so it was modified as such.

Can be tested using the following:
```
while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt
```
This will run the Hostname command on each VM.

### Configure Hostfile to include IPs of other VMs

Now that we I have assigned a hostname to each compute VM, lets add all of these hostnames and IPs to a new Hostfile for appending to the existing Hostfiles.

Create the file to append to existing /etc/hosts:
```
echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts
```
Create entry for each vm:
```
while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt
```
I should now have the following on our jumpbox:
```
cat hosts
"# Kubernetes The Hard Way"
192.168.105.5 server.kubernetes.local server
192.168.105.6 node-0.kubernetes.local node-0
192.168.105.7 node-1.kubernetes.local node-1
```
## Update Hostfile for jumpbox

Running this will append my Hostfile to the existing one on the jumpbox:
```
cat hosts >> /etc/hosts
```
Now on the jumpbox it is possible ssh via hostname:
eg:
```
root@lima-jumpbox:~# ssh server
root@server:~# 
```
### Update Hostfile of compute VMs
Finally I need to append Hostfile on all compute resources:
```
while read IP FQDN HOST SUBNET; do
  scp hosts root@${HOST}:~/
  ssh -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt
```

Now I can communicate via hostname on all VMs from any VM:
```
root@lima-node-1:~# ping server
PING server.kubernetes.local (192.168.105.5) 56(84) bytes of data.
64 bytes from server.kubernetes.local (192.168.105.5): icmp_seq=1 ttl=64 time=0.507 ms
```