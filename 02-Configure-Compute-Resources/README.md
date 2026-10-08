## Configure compute resources
Next steps will be configure root access via password and key
Configure machines.txt file to allow us to configure in bulk all computer VMs

### Configure Root SSH access
As this is a lab environment we will configure Root SSH access for convenience.
The version of Debian we are using requires us to enable the Root account

For each VM we will need to 
- Enable Root account
"sudo passwd root"
- Enable SSH via Root account
This is done changing the /etc/ssh/sshd_config file
PermitRootLogin yes
PasswordAuthentication yes

### Configure SSH access via public/private key
On jumpbox perform "su" to switch to the root user.
generate SSH key
"ssh-keygen"

Copy to all machines:

while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@${IP}
done < machines.txt

You will be prompted for the root password of each vm

For troubleshooting you can view the public key generated on jumpbox:
"cat ~/.ssh/id_rsa"
Confirm it matches the key on each VM:
"cat ~/.ssh/authorized_keys"

If matching you should now be able to ssh via ssh root@TheIPofTheVm

### Configure Hostfile and hostname of compute resources
For ease of admin lets configure hostname so we do not need to remember ips of ssh

while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl set-hostname ${HOST}
    ssh -n root@${IP} systemctl restart systemd-hostnamed
done < machines.txt

Some notes:
Within the the /etc/hosts folder on each compute vm, we find the line start with 127....
Replace it with 127... then a tab(\t) then we add the FQDN and hostname. 
The above only changes the hostfile not the actual hostname, we need the hostnamectl
to actually update the hostname.
We made a slight alteration the original documentation as the host Ip as "127.0.1.1", however this
did not match what I had "127.0.0.1" modified it as such

We can test using the following
while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt

This will run the Hostname command on each compute vm

### Configure Hostfile and hostname of compute resources

Now we will add each IP and hostname to the hostfile on each vm

Create the file to append to existing /etc/hosts

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

Create entry for each vm

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt

We should now have the following on our jumpbox

root@lima-jumpbox:~/kubernetes-the-hard-way# cat hosts

"# Kubernetes The Hard Way"
192.168.105.5 server.kubernetes.local server
192.168.105.6 node-0.kubernetes.local node-0
192.168.105.7 node-1.kubernetes.local node-1

### Append to jumpbox hosts file

cat hosts >> /etc/hosts

Now on the jumpbox you should be able ssh via hostname 
eg ssh server

### Final step! Append host files to each VM
Append to hostfile on all compute resources

while read IP FQDN HOST SUBNET; do
  scp hosts root@${HOST}:~/
  ssh -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt

Now we can communicate via hostname on all vms

root@lima-node-1:~# ping server
PING server.kubernetes.local (192.168.105.5) 56(84) bytes of data.
64 bytes from server.kubernetes.local (192.168.105.5): icmp_seq=1 ttl=64 time=0.507 ms