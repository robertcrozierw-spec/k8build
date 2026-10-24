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
The CA.key is included as the kube-controller-manager will actually sign CSRs, however in this tutorial it may be unneeded as we manually issues all certs at the beinging and manually distributed them.
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

kubeconfig file we created previously
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
If we run the systemctl command we can see a list of all services on the VM
We can see our kube related services are active and runnning
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

Grouping specific permissions into roles and applying those roles to users, groups or service accounts

ClusterRoles are sets of permissions that can be applied clusterwide or specific namespaces
Roles are sets of permissions that are applied to specific namespaces

Once we have declared our Roles or ClusterRoles we then need to bind them to users, groups or services accounts
This is done via Rolebinding or ClusterRoleBinding

For Roles and Rolebindings the namespaces must be declared in each and be matching
For ClusterRoles and ClusterRolebindings there is no need to declare namespaces
We can also have ClusterRoles scoped to single namespaces by binding with a Rolebinding

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
