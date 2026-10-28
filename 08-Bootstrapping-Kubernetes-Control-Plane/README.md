# Bootstrapping the Kubernetes Control Plane

In this section I will install the following components on the control plane server:
-   Kubernetes API Server 
-   Scheduler
-   Controller Manager

## Components to install
I will briefly explain what each component I am installing does.

### Kubernetes API Server

Reading the [documentation](https://kubernetes.io/docs/concepts/overview/kubernetes-api/) the Kubernetes API Server or Kube-api can be seen as the core of the control plane. It handles communication between the users, cluster components and pods. Although it is an HTTP API and can be interacted with as such, for this project I will be excusably using the kubectl command line tool instead.

### Scheduler

The Scheduler or kube-scheduler is the component responsible for deciding which Node to place an unassigned Pod. Once it decides which Node the Kubelet of that Nodes takes over and actually handles the provisioning.

### Controller Manager

Controller Manager or kube-controller-manager, from my understanding this is actually a collection of control modules. Typically it will contain at least the following sub-components however please note this is not a complete list it contains many more modules:
-   NODE controller - Responsible for monitoring Nodes and handling situation were communication breaks.
-   REPLICATION controller - Handles Replica sets making sure correct number of Pods are running.
-   Namespace Controller - Handles creation og namespaces for separation of resources on the cluster.


## Transfer and configuration of components

In this section I will discuss the transfer and configuration of the components and there support files.

### Transfer components
I transferred the required binaries (including kubectl), systemd unit files and configuration files the the control plane server here:
```
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
```

### Provision the Kubernetes Control Plane

On the control plane server we will move the below components into the  `/user/local/bin`, this directory is typically used for user installed software instead of the `/bin/`, which is typically reserved for pre-installed binaries:

-   kube-apiserver
-   kube-controller-manager
-   kube-scheduler
-   kubectl
```
{
  mv kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl \
    /usr/local/bin/
}
```

### Transfer certificates and encryption config

I will now transfer the *.crt files, and encryption-config to a new directory `/var/lib/kubernetes/`.

The CA.key is included as the kube-controller-manager will actually sign CSRs, however in this tutorial it may be unneeded as we manually issued and distributed all certs at the beginning.

The service-account.key is used by thee kube-controller-manager to sign service account tokens.

kube-api-server will need the encryption-config.yaml to encrypt and decrypt etcd data.
```
{
  mkdir -p /var/lib/kubernetes/
  mv ca.crt ca.key \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    encryption-config.yaml \
    /var/lib/kubernetes/
}
```
### Configure systemd unit file for kube-api-server

As the kube-api-server does not contain a Kubeconfig, I just need to create the systemd service:
```
mv kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service
```

### Configure the Kubernetes Controller Manager

Using ube-controller-manager.kubeconfig file I created previously, move it to `/var/lib/kubernetes/`:
```
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
```
Next, create systemd service:
```
mv kube-controller-manager.service /etc/systemd/system/
```

### Configure the Kubernetes Scheduler

Move the Kubeconfig "kube-scheduler.kubeconfig" file to `/var/lib/kubernetes/`:
```
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
```
Create systemd service:
```
mv kube-scheduler.service /etc/systemd/system/
```
I also need to add the configuration file referenced by the systemd kube-scheduler.service: 
```
mv kube-scheduler.yaml /etc/kubernetes/config/
```

## Starting and testing the controller services

Here we will start the services and confirm they are working as expected.

### Start services
Finally, I started the controller services:
```
{
  systemctl daemon-reload

  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler
}
```
Output:
```
Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service → /etc/systemd/system/kube-controller-manager.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service.
```

If I run the systemctl command `systemctl list-units --type=service "kube*"` we can see a list of all Kube services on the control plane server are active and running:
```
  UNIT                            LOAD   ACTIVE SUB     DESCRIPTION                  
  kube-apiserver.service          loaded active running Kubernetes API Server
  kube-controller-manager.service loaded active running Kubernetes Controller Manager
  kube-scheduler.service          loaded active running Kubernetes Scheduler
```
### Confirm Cluster control services are running

Using the Kubectl I can now confirm the roles are active and working, note the addition of the Kubeconfig files for authentication to the cluster:
```
kubectl cluster-info \
  --kubeconfig admin.kubeconfig
output:
Kubernetes control plane is running at https://127.0.0.1:6443
```

## Briefly on RBAC

I will now speak a little about RBAC and its use in Kubernetes.

RBAC or Role based access control is for grouping specific permissions into roles and applying those roles to users, groups or service accounts.

Some of the key terminology:

-   Roles -  are sets of permissions that are applied to specific namespaces.
-   ClusterRoles - are sets of permissions that are applied clusterwide, can then be limited to namespaces as will be discussed.

Once we have declared our Roles or ClusterRoles we then need to bind them to users, groups or service accounts.

This is done via Rolebinding or ClusterRoleBinding.
The difference can be looked at in terms of scope:
-   Rolebinding - Local scope specific to a namespace.
-   ClusterRoleBinding - Global, applies across all namespaces and the cluster itself.

When binding Roles via Rolebindings the namespaces must be declared in both and be matching.

For ClusterRoles and ClusterRolebindings there is no need to declare namespaces, as these are clusterwide.

Finally, there are ClusterRoles limited to single namespaces by binding them with a Rolebinding.

For example:
Lets say I want to grant the users in namespace A and B admin access to their respective namespaces.
Well one way is to create 2 Roles, one with namespace-admin roles to namespace-A lets call this Role-A-definition and another with namespace-admin roles to namespace-B, lets call this Role-B-definition.
Next, bind these role definitions to their respective namespaces. A Rolebinding with Role-A-definition bound to namespace-A, lets call this RB-namespace-A and a Rolebinding with Role-B-definition bound to namespace B(RB-namespace-b).

So this required a total of 4 separate files, it will work but it's an inflexible solution as every time I want to grant the users of a namespace A admin access to their own namespace I would need to create two new files(the Role definition and the Rolebinding).

A better solution is to implement it with ClusterRoles.
In this example, declare a ClusterRole with the namespace-admin roles, lets call it ClusterRole-definition. Next use a Rolebinding to only apply ClusterRole-definition to namespace-A and namespace-B. Now the users of namespace-A and B will have admin access to their respective namespaces but this time with only 3 files and in future I only need to create a new Rolebinding not a new ClusterRole.

### RBAC for Kubelet Authorization
RBAC permissions need to be granted to the API server to access the Kubelets.

The following yaml file contains the ClusterRole and ClusterRoleBinding:

kube-apiserver-to-kubelet.yaml

We need to include the admin.kubconfig, as that is the "identity" used to perform the action of binding
```
kubectl apply -f kube-apiserver-to-kubelet.yaml \
 --kubeconfig admin.kubeconfig
```
Output:
```
clusterrole.rbac.authorization.k8s.io/system:kube-apiserver-to-kubelet created
clusterrolebinding.rbac.authorization.k8s.io/system:kube-apiserver created
```

## Verify Control Plane is active 

Finally, we can verify the control plane is active by performing a curl request to it from the jumpbox server:
```
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
```
