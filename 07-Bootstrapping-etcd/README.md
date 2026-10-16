# Bootstrapping the etcd Cluster
In this section I will be implementing the etcd
etcd is a key value database, as mentioned in the previous section it is used to store cluster state, secrets, configurations etc.
Typically all requests to the etcd would need to go through the kube-API component, however it is possible to query it directly for testing purposes.

## Transfer binaries and systemd unit files

To start with I transferred the etcd binaries, the command line tool for interacting with it "etcdctl" and also the systemd unit file to the controller server:
```
scp \
  downloads/controller/etcd \
  downloads/client/etcdctl \
  units/etcd.service \
  root@server:~/
```

## Install the binaries

Next, to install the binaries move them into the usr/local/bin/ directory:
```
  mv etcd etcdctl /usr/local/bin/
```

In the original tutorial the CA cert (ca.crt), kube.api-server.key keypair and kube-api-server.crt are copied into the /etc/etcd. The private key is required for etcd to sign its part of the mTLS handshake.
However I should point out that the systemd unit file does not actually point to any certificate. So it's unlikely any mTLS is taking place between the api-server and etcd. 
As this is a project for education, this lack of mTLS is acceptable. However in production It should be implemented especially if the etcd database is configured on a separate node. I would also likely not use the same keypair and certificate as the api-server instead generating unique ones for each component.

```
Create 2 directories and grant full access to the owner of /var/lib/etcd (root):
{
  mkdir -p /etc/etcd /var/lib/etcd
  chmod 700 /var/lib/etcd
  cp ca.crt kube-api-server.key kube-api-server.crt \
    /etc/etcd/
}
```
Regarding the creation of the /var/lib/etcd directory, we can see this is were the [etcd.service](etcd.service) unit file is configured to store the data.

## Move, start and test the service

First I move the service file into the systemd directory:
```
mv etcd.service /etc/systemd/system/
````

Next start the service:
Start service
```
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
```

Finally, confirm values are in database:
```
etcdctl member list
```
Output:
```
6702b0a34e2cfd39, started, controller, http://127.0.0.1:2380, http://127.0.0.1:2379, false

| Field | Value |
|---|---|
| Member ID | `6702b0a34e2cfd39` |
| Status | `started` |
| Name | `controller` |
| Peer URL | `http://127.0.0.1:2380` |
| Client URL | `http://127.0.0.1:2379` |
| Is Learner | `false` |
```