## Provisioning a CA and Generating TLS Certificates 
I took this an opportunity to further my understanding of PKI, I have broken this up into different sections and
built up my understanding as such.

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
These additional steps are necessary as you don't want for example rogue components connecting to the  API server

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
-   The CA signed certificate can be shared with all of the relevant applications or systems eg fileserver and appserver
-   We use the CA to issue a certificate to the fileserver and appserver
-       When appserver tries to connect to the fileserver, its sees its fileserver certificate is signed by the CA
-       It will trust the certificate because it can verify it with the CA self signed certificate it already has

This wont work well if in public, because the public members would not have the Private CA's certificate already installed
- so have no way of verifying the authenticity of appserver
