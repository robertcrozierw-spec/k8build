# Configure jumpbox
We need to configure a terminal for accessing the other VMs, this could be the local machine, we will the jumpbox VM.

## First we clone the git repo to our jumpbox:
```
sudo git clone --depth 1   https://github.com/kelseyhightower/kubernetes-the-hard-way.git
```
## Download required binaries and extract
We use the txt file within the previously cloned Git repo to get the list of required binaries.
As I am on a Macbook with ARM this textfile is the "downloads-arm64.txt"

Next we needed to take ownership of the directory as it was set to root:
```
sudo chown -R bob:bob downloads
```
Create a folder and subfolders to store the extracted binaries:
```
mkdir -p downloads/{client,cni-plugins,controller,worker}
```
These subfolders will later be copied to the relevant VMs:

| Directory | Destination | Contents |
|---|---|---|
| `client/` | jumpbox (local only) | `kubectl`, `etcdctl` |
| `controller/` | `server` | `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` |
| `worker/` | `node-0`, `node-1` | `kubelet`, `kube-proxy`, `containerd`, `runc`, `crictl` |
| `cni-plugins/` | `node-0`, `node-1` (`/opt/cni/bin`) | CNI networking plugins |

I then run the extract:
```
tar -xvf downloads/crictl-v1.32.0-linux-arm64.tar.gz \
    -C downloads/worker/
```

Run a cleanup to keep things tidy in the directory:
```
sudo rm -rf downloads/*gz
```
Finally set permissions so that all binaries are executable:
```
chmod +x downloads/{client,cni-plugins,controller,worker}/*
```