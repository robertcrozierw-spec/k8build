# Generating the Data Encryption Config and Key
I will be covering etcd in more detail in the next section, briefly, this is a database that stores secrets, the cluster state and application information. As it contains sensitive data it is important that it is encrypted.
The encryption is "at rest" basically meaning that the data is encrypted as it is stored and decrypted as it is read.
The [Encryption config file](./encryption-config.yaml) has already been mostly created. It just requires that I add an encryption key.
This will be configured in 2 parts:
- The creation of a random key needed for encryption.
- The injecting of this random Key into the configuration file.

When completed I will transfer the completed encryption config file to the controller server.
## Create A Random Key

The /dev/urandom file can be used to generate a random key.
Other requirements are:
- Converting to base64.
- Storing in Environment Variable.
- Exporting variable so it can be used in child processes.
This can be done as follows:
```
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

### Injecting environment key and moving to Controller

Using envsubst, the ENCRYPTION_KEY can be added to the encryption-config.yaml:
```
envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml
```

Finally this file can be moved to the controller server:
```
scp encryption-config.yaml root@server:~/
```