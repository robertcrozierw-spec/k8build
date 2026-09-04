# K8build

Personal project to build Kubernetes cluster from scratch.
Main learning goal is to gain bottom up understanding of clusters.
I will be following steps in the Kubernetes the hard way found here:
https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md


## Prerequisites 
First we need to configure 4 VMs, as I am using a Macbook and plan on building everything locally I will use "Lima"
Lima was chosen for its ease of use and flexible network configuration options.

4 yaml files are specified in the VMs diecroty. For now the command will need to ran manually to create each one:
limactl create --name=nameofVM ./locationofyaml

As we require all vms and the host the ability to communicate with each other over SSH and other tools we went with the 
"socket_vmnet (shared)" option. This is configured via option
networks:
- lima: shared

This shared mode uses a virtual network configured by lima and handles dhcp internally.
In future projects bridged mode may be implemented instead, this would allow external devices to connect, however connection may break from host <-> VMs when laptop is moved to another network, as the IP address and range would be coming from another DHCP server.

## Configure jumpbox
We need to configure a terminal for access the other VMs, this could be a local machine, but instead we use the jumpbox VM.

### First we clone the git repo to our jumpbox:
sudo git clone --depth 1   https://github.com/kelseyhightower/kubernetes-the-hard-way.git

### Next download the required binaries and extract them
We use the txt file within the previously cloned Git repo to get the list of required binaries
As I am on a Macbook with ARM this textfile is the "downloads-arm64.txt"

Next we needed to take ownership of the directory as it was set to root
"sudo chown -R bob:bob downloads"

Create a folder and subfolders to store the extracted binaries.
" mkdir -p downloads/{client,cni-plugins,controller,worker}"

These subfolders will later be copied to the relevant VMs:

| Directory | Destination | Contents |
|---|---|---|
| `client/` | jumpbox (local only) | `kubectl`, `etcdctl` |
| `controller/` | `server` | `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` |
| `worker/` | `node-0`, `node-1` | `kubelet`, `kube-proxy`, `containerd`, `runc`, `crictl` |
| `cni-plugins/` | `node-0`, `node-1` (`/opt/cni/bin`) | CNI networking plugins |

extract example:
tar -xvf downloads/crictl-v1.32.0-linux-arm64.tar.gz \
    -C downloads/worker/

Cleanup:
sudo rm -rf downloads/*gz

Finally set permissions so that all binaries are executable
{
  chmod +x downloads/{client,cni-plugins,controller,worker}/*
}

### Install Kubectl

Kubectl is the standard commandline tool for interacting with K8s

We just copy the binary into the relevant directory:
cp downloads/client/kubectl /usr/local/bin/

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

We can test using the followin
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

### Final step! Append host files to each 
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

## Provisioning a CA and Generating TLS Certificates 
I took this an opportunity to further my understanding of PKI, I have broken this up into different sections and
built up my understanding as such

### Key pair
Keypairs are used in an encryption practice call Asymmetric cryptograph
-   One should always be kept secret(private key) the other can be shared(public key)
-   Either key can encrypt however the opposite will always be needed to decrypt
-   Commonly used Keypairs are RSA and ECDSA


### Hashing
Hashing is a mathematical function that takes a message or file and outputs a number, if the file
in anyway changes and the hash function ran again, the output will be different

### Certificates and Certificate Authorities

#### Authenticity
-   Authenticity refers to making sure the data is coming from who you think its coming from.
-       yourbank.com is sending you data, how do we know its actually yourbank.com and not some fake website created?
-       Answer, because a Certificate Authority says so.

##### Certificate Authority(CA)
CAs can be public enterprises (digicert) or internal, for our example we are using a public one, private we can discuss later

-   yourbank.com generates a keypair, we will use RSA for this.
-   yourbank.com provides information to a CA. Example, name of organization, URL, address of business, also their public key
-   CA verifies information is correct
-   Puts all the information together eg Public key, URL etc it also adds the name of the CA(issuer). This can be considered the certificate
-       It then performs a hash of this certificate
-       Next it encrypts this hash using its own(the CA's) private key
-       Attaches this encrypted hash to the certificate
-       We now have a "signed certificate"
-       This process is also referred to "Issuing a certificate"
-       Signed certificate given to yourbank.com to install on their server

Now when we try and access yourbank.com we can see it is trusted by a CA
-   We trust this CA, because we have the popular CAs public Key installed by default in our browser.
-       Using the public key of the CA we can decrypt the signature, to get the hash
-       We then independently hash the same information the CA did in the previous step eg Public Key, URL, name etc
-       We then compare these 2 hashes, the one we generated and the one we decrypted from the CA
-       If they match we are good, if not something has been tampered with and we cannot trust yourbank.com

### TLS
Common method for secure data transfer
Unlike the  above  Asymmetric cryptography, which is slow we want to use Symmetric as a single shared key is much quicker to encrypt and decrypt data with

-   Our example is clientA trying to access yourbank.com
-   Client A sees your yourbank.com has a valid certificate
-   They both negotiate and create a secure shared key using a protocol called Diffie-Helman key exhange
-   Once Key is created this is used for encrypting the data for transfer(AES is the type fo encryption)
-   Key is temporary, a new one created each time a new sessions is started on website

### Other notes

#### Self signed certificates - public
In the Certificate Authority(CA) section, we see the our example Digicert signed our certificate.
-   However, who Digicert must have there own certificate too? How signs that?
-   Answer - Digicert, this is called a self signed certificate. If we inspect the Digicert certificate we would 
see its issues by Digicert.
-   But as mentioned before this is ok, as our browser and device is pre built to trust Digicert signed certificates.

#### Self signed certificates - private
We can also have private self signed certificates.
-   Within an organization or system, we might have an internal CA, this CA can just be a self signed certificate with a private key
-   The CA signed certificate can be shared with all of the relevant applications or systems eg filserver and appserver
-   We use the CA to issue a certificate to the filserver and appserver
-       When appserver tries to connect to the fileserver, its sees its filecerver certificate is signed by the CA
-       It will trust the certificate because it can verify CA self signed certificate it already has

This wont work well if in public, because the public members would not have the Private CA's certificate already installed
- so have not way of veryfying the authenticity of appserver


