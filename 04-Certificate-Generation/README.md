## Generating the Kubernetes CA, Keys and Certificates
We will need to perform the following steps:

- Create keypairs for CA certificate
- Generate Signed CA certificate
- Create keypairs and Issue certificates for kubernetes components and user
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
Create RSA keypair called ca.key

-    openssl genrsa -out ca.key 4096

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

### Generate keypairs and Signed Certificates for components

Uses loop to move though list of identities above

-   Generates keypairs
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
