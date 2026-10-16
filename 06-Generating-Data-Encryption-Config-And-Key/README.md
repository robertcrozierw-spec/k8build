# Generating the Data Encryption Config and Key
I will be covering etcd in more detail in the next section, briefly this is database that stores secrets, the cluster state and application information. As it contains sensitive data it is important that it is encrypted.
The type of encryption method is "at rest" basically meaning that the data is encrypted as it is stored and decrypted as it is read.
The [Encryption config file](./encryption-config.yaml) has already been mostly created It just requires that I add an encryption key. This will be configured in 2 parts:
- 1 The creation of a random key needed for encryption.
- 2 The injecting of this random Key into the configuration file.

When completed I will transfer the competed encryption config file to the controller server.
## Create A Random Key 

Using the "/dev/urandom" file we can generate a random number.
I will also need to convert this random to base64 and store it in and environment variable to be later injected into the encryption config file.
This can be done as follows:
```
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```
The export is so the "ENCRYPTION_KEY variable so can be used in child process.

### Injecting environment key and move to Master

Using the envsubst we can add add the ENCRYPTION_KEY to a yaml file:
```
envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml
```

Finally this file can be moved to the controller server:
```
scp encryption-config.yaml root@server:~/
```