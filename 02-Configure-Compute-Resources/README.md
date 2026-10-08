# Configure compute resources
Next steps will be configure root access via password and key.
I created the machines.txt [`machines.txt`](../../K8build/machines.txt)file to allow us to configure in bulk all VMs.

## Configure Root SSH access
As this is a lab environment we will configure Root SSH access for convenience. This is major security vulnerability and should not be done in production.

The version of Debian we are using requires us to enable the Root account first so for each VM we will need to:
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

First we need to generate SSH key:
```
ssh-keygen
```
Next copy to all machines:
```
while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@${IP}
done < machines.txt
```
You will be prompted for the root password of each vm, this is expected.

You can validate can that public public key generated on jumpbox matches whats on the VM:
```
"cat ~/.ssh/id_rsa"
Confirm it matches the key on each VM:
"cat ~/.ssh/authorized_keys"
```
If matching you should now be able to ssh via:
```
ssh root@TheIPofTheVm
```

## Configure Hostfile and hostname of compute resources

For ease of admin lets configure hostname so we do not need to remember ips of each compute VM.

This wll be done in two sections:
-   Configure the Hostfile and own hostname.
-   Configure Hostfiles to include all other compute VMs.
-   Update Hostfile for jumpbox.
-   Update Hostfile of compute VMs.
### Configure the Hostfile and hostname

We will start with creating the actual Hostfile and adding the VMs own hostname to it:
```
while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl set-hostname ${HOST}
    ssh -n root@${IP} systemctl restart systemd-hostnamed
done < machines.txt
```
Some notes:
Within the the /etc/hosts folder on each vm, we find the line starting with 127....
Replace it with 127... then a tab(\t) then add the FQDN and hostname. 
The above only changes the hostfile not the actual hostname, we need the hostnamectl
to actually update the hostname.
We made a slight alteration the original documentation as the host Ip as "127.0.1.1", however this
did not match what I had "127.0.0.1" modified it as such

We can test using the following:
```
while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt
```
This will run the Hostname command on each VM.

### Configure Hostfile to include IPs of other VMs

Now that we have created an assigned a hostname to each compute VM, lets add all of these hostnames and IPs to each Hostfile:

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
We should now have the following on our jumpbox:
```
cat hosts
"# Kubernetes The Hard Way"
192.168.105.5 server.kubernetes.local server
192.168.105.6 node-0.kubernetes.local node-0
192.168.105.7 node-1.kubernetes.local node-1
```
## Update Hostfile for jumpbox

Running command to append our Hostfile to the existing on on the jumpbox:
```
cat hosts >> /etc/hosts
```
Now on the jumpbox you should be able ssh via hostname 
eg:
```
root@lima-jumpbox:~# ssh server
root@server:~# 
```
### Update Hostfile of compute VMs.
Finally I need to append to the Hostfile on all compute resources:
```
while read IP FQDN HOST SUBNET; do
  scp hosts root@${HOST}:~/
  ssh -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt
```

Now we can communicate via hostname on all vms
```
root@lima-node-1:~# ping server
PING server.kubernetes.local (192.168.105.5) 56(84) bytes of data.
64 bytes from server.kubernetes.local (192.168.105.5): icmp_seq=1 ttl=64 time=0.507 ms
```