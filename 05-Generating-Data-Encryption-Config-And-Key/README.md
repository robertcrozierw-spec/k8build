## Generating the Data Encryption Config and Key
encryption-config.yaml is the layout required by K8s for encrypting valuable information at rest.

### Create a random key 

Using the /dev/urandom file we can generate a random number
This allows us to use this random number as an encryption key

Next we convert to a base64 for ease of use and store in variable
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

We then use export this variable so it can be used in child process

### Substitute the newly created environment key and move to Master

Using the envsubst we can add add the ENCRYPTION_KEY to a yaml file 

envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml

Move to to master server:
-   scp encryption-config.yaml root@server:~/