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
-   They both negotiate and create a secure shared key using a protocol called Diffie-Helman key exchange
-   Once Key is created this is used for encrypting the data for transfer(AES is the type for encryption)
-   Key is temporary, a new one created each time a new sessions is started on website

### mTLS
Common method used in Kubernetes for components to securely communicate with each other
These additional steps are necessary as you dont want for example rogue components connecting to the  API server

- Where TLS requires only the server be authenticated to the clients. mTLS requires that the client also authenticates to the server.
- This means that an additional stage takes place during the negotiation
- The server requests and receives the client certificate
- The client will now hash and sign(Using its private key) the existing handshake data and sends this value to the server
- Server can then verify the signature using the clients public key, compares it to the hash of the same data

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
-       It will trust the certificate because it can verify it with the CA self signed certificate it already has

This wont work well if in public, because the public members would not have the Private CA's certificate already installed
- so have no way of verifying the authenticity of appserver


## Generating Kubernetes Configuration Files for Authentication

We will need to perform the following steps:

- Create Keypairs for CA certificate
- Generate Signed CA certificate
- Create Keypairs and Issue certificates for kubernetes components and user
- Transfer certs and keypairs to relevant VMs

5 identities will be created

    "admin"  = Actual user account
    "node-0" "node-1" = The worker nodes (kubelets)
    "kube-proxy" "kube-scheduler" = Services on worker
    "kube-controller-manager" = Service on Server
    "kube-api-server" = Service on Server
    "service-accounts" = Used as the pods identify

### Generate self signed CA 

First we need to generate a Self signed CA so that we can sign the additional certificate created

#### Keypair of CA
Create RSA Keypair called ca.key

-       openssl genrsa -out ca.key 4096

#### CA certificate
Next the Self signed CA certificate

-       openssl req -x509 -new -sha512 -noenc \
        -key ca.key -days 3653 \
        -config ca.conf \
        -out ca.crt

We Include the keypair (ca.key strictly speaking it would only need the private key)

The relevant parts of the ca.conf:
[req]
distinguished_name = req_distinguished_name
prompt             = no
x509_extensions    = ca_x509_extensions

[ca_x509_extensions]
basicConstraints = CA:TRUE
keyUsage         = cRLSign, keyCertSign

[req_distinguished_name]
C   = US
ST  = Washington
L   = Seattle
CN  = CA

The keyusage we can see has the "keycertSign" added this means it can be used to sign other certificates.
The [req_distinguished_name] will be the subject info on the cert

### Generate Keypairs and Signed Certificates for components

Uses loop to move though list of identities above

-   Generates Keypairs
-   Generates CSR(Certificate Signing Request) files 
-   CA issues cert via creating x509 certificate using above identity public key, and CSR. Then signs using CA private key

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

### Transfer issued certificates to relevant VMs

For transferring to node VMs:

for host in node-0 node-1; do
  ssh root@${host} mkdir /var/lib/kubelet/

  scp ca.crt root@${host}:/var/lib/kubelet/

  scp ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done

For transferring to master or server:

scp \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@server:~/

## Kubeconfigs
Kubeconfigs are File's containing information on the cluster
- Name of cluster
- Certificates to access
- API of cluster URL

They are used by kubectl, users and other services to connect to cluster

For the kubelet's or nodes Kubeconfig, we must reference the
-   CA cert
-   Client keypair
-   URL of API server 
-   Embed - certs just means the certs will be within the Kubeconfig output file and just a path to them


for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done

## Generating the Data Encryption Config and Key
encryption-config.yaml is the layout required by K8s for encrypting valuable information at rest.

### Create a random key 

Using the /dev/urandom file we can generate a random number
This allows us to use this random number as an encryption key

Next we convert to a base64 for ease of use and store in variable
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

We then use export this variable so it can be used in child process

### Substitute the newly created enviroment key and move to Master

Using the envsubst we can add add the ENCRYPTION_KEY to a yaml file 

envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml

Move to to master server:
-   scp encryption-config.yaml root@server:~/

## Bootstrapping the etcd Cluster
etcd is a key value database
Used to store information about the cluster

### Transfer binaries and systemd unit files

We need to transfer the etcd binaries and its command line tool for interacting with it etcdctl

We also need to move the systemd unit file etcd.service, this will be the configuration file for the etcd service

scp \
  downloads/controller/etcd \
  downloads/client/etcdctl \
  units/etcd.service \
  root@server:~/

### Install the binaries
Move them to the usr/local/bin/
{
  mv etcd etcdctl /usr/local/bin/
}

We will then create 2 new directories and grant full access to the owner of /var/lib/etcd (root)
Next step is to copy our CA cert (ca.crt), kube.api-server.key keypair and kube-api-server.crt into the /etc/etcd 
The private key is required for etcd to sign part of the mtls handshake

{
  mkdir -p /etc/etcd /var/lib/etcd
  chmod 700 /var/lib/etcd
  cp ca.crt kube-api-server.key kube-api-server.crt \
    /etc/etcd/
}

For the above keypairs and certs we used the api-server ones, however in production it would be better to generate unique ones for etcd

Next we move the service file into the systemd directory

-       mv etcd.service /etc/systemd/system/

Start service

-   systemctl daemon-reload
-   systemctl enable etcd
-   systemctl start etcd

Confirm values are in database
-   etcdctl member list

Output:
6702b0a34e2cfd39, started, controller, http://127.0.0.1:2380, http://127.0.0.1:2379, false

| Field | Value |
|---|---|
| Member ID | `6702b0a34e2cfd39` |
| Status | `started` |
| Name | `controller` |
| Peer URL | `http://127.0.0.1:2380` |
| Client URL | `http://127.0.0.1:2379` |
| Is Learner | `false` |

## Bootstrapping the Kubernetes Control Plane

Next step is to install the following module on our master server
-Kubernetes API Server 
-Scheduler
-Controller Manager

It is handled by this command
This includes our binaries(including kubectl), systemd units, scheduler and API kubeconfig created previously 

scp \
  downloads/controller/kube-apiserver \
  downloads/controller/kube-controller-manager \
  downloads/controller/kube-scheduler \
  downloads/client/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  root@server:~/

This includes our binaries(including kubectl), systemd units, scheduler and API kubeconfig created previously 

### Provision the Kubernetes Control Plane
On Server we need to Install the binaries(including kubectl)
kube-apiserver
kube-controller-manager
kube-scheduler
kubectl

{
  mv kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl \
    /usr/local/bin/
}

The below will be moved to a new directorty
The CA.key is inclulded as the kube-controller-manager will actually sign CSRs, however in this tutorial it may be unneeded as we amnaully issues all certs at the beinging and manually distributed them.
The serice account key is used kube-controller-manager to sign servie account tokens.
kube-api-server will need the encryption-config.yaml to encrypt and decrypt etcd data
{
  mkdir -p /var/lib/kubernetes/

  mv ca.crt ca.key \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    encryption-config.yaml \
    /var/lib/kubernetes/
}

Create systemd unit file kube-api-server

mv kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service

### Configure the Kubernetes Controller Manager

KubeConfig file we created previously
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

Create systemd unit
mv kube-controller-manager.service /etc/systemd/system/

### Configure the Kubernetes Scheduler

kubeconfig file we created prevouisly
mv kube-scheduler.kubeconfig /var/lib/kubernetes/

Config file taken from kubernetes the hardway github
mv kube-scheduler.yaml /etc/kubernetes/config/

Create systemd unit file
mv kube-scheduler.service /etc/systemd/system/

### Start the controller services

{
  systemctl daemon-reload

  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler
}
output:
Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service → /etc/systemd/system/kube-controller-manager.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service.

### Confirm running controller services
if we run the systemctl command we can see a list of all services on the VM
We can see our kube realted sercices are active and runnning
```
UNIT                              LOAD   ACTIVE SUB     DESCRIPTION
kube-apiserver.service            loaded active running Kubernetes API Server
kube-controller-manager.service   loaded active running Kubernetes Controller Manager
kube-scheduler.service            loaded active running Kubernetes Scheduler
```
### Confirm Cluster control services are running
kubectl cluster-info \
  --kubeconfig admin.kubeconfig
output:
Kubernetes control plane is running at https://127.0.0.1:6443

### Briefly on RBAC

Role based access control

Grouping specific permissions into roles and applying those roles to users, groups or services accounts

ClusterRoles are sets of permsisions that can be applied clusterwide or specific namespaces
Roles are sets of permissions that are applied to specific namespaces

Once we have declared our Roles or Cluster roles we then need to bind them to users, groups or services accounts
This is done via Rolebinding or ClusterRoleBinding

For Roles and Rolebindings the namespaces must be declared in each and be matching
For ClusterRoles and ClusterRolebindings there is no need to declare namespaces
We can also have ClusterRoles scoped to single namespaces by binding with Rolebinding

#### RBAC for Kubelet Authorization
We need to grant RBAC permissions to the API server to access the Kubelets

The folowing yaml file contains the clusterrole and clusterRolebinging
kube-apiserver-to-kubelet.yaml
We need to include the admin.kubconfig, as that is the "identity" used to perform the action of binding

kubectl apply -f kube-apiserver-to-kubelet.yaml \
  --kubeconfig admin.kubeconfig

output:
clusterrole.rbac.authorization.k8s.io/system:kube-apiserver-to-kubelet created
clusterrolebinding.rbac.authorization.k8s.io/system:kube-apiserver created

### Verify Control Plane is active 

root@lima-jumpbox:~/kubernetes-the-hard-way# curl --cacert ca.crt \
  https://server.kubernetes.local:6443/version
{
  "major": "1",
  "minor": "32",
  "gitVersion": "v1.32.3",
  "gitCommit": "32cc146f75aad04beaaa245a7157eb35063a9f99",
  "gitTreeState": "clean",
  "buildDate": "2025-03-11T19:52:21Z",
  "goVersion": "go1.23.6",
  "compiler": "gc",
  "platform": "linux/arm64"
}