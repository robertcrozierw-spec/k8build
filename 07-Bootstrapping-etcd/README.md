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

       mv etcd.service /etc/systemd/system/

Start service
```
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
```

Confirm values are in database
        etcdctl member list

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
