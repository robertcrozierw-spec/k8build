# K8build

Personal project to build Kubernetes cluster from scratch.
Main learning goal is to gain bottom up understanding of clusters.

## Prerequisites 
First we need to configure 4 VMs, as I am using a Macbook and plan on building everything locally I will use "Lima"
Lima was chosen for its ease of use and flexible network configuration options.

4 yaml files are specified in the VMs diecroty. For now the command will need to ran manually to create each one:
limactl create --name=nameofVM ./locationofyaml

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

## Install Kubectl

Kubectl is the standard commandline tool for interacting with K8s

We just copy the binary into the relevant directory:
cp downloads/client/kubectl /usr/local/bin/