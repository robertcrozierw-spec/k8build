# Dynamic Storage And Default StorageClasses

In a typical Kubernetes environment there is a requirement for dynamic provisioning of storage or PersistentVolumes (PV).

This requirement comes from the need to reduce administrative load of manually creating PVs each time an application developer requests one. This process is implemented via StorageClasses (SC).

This section will explain a little more on the workings of StorageClasses, how they are configured and building the requirements necessary to implement them on our Kubernetes The Hard Way Cluster.

## Storage Concepts And Types

In Kubernetes there are 3 main storage concepts worth explaining.

-   PersistentVolumes
-   PersistentVolumeClaims
-   StorageClasses

### PersistentVolumes

PVs are just standard volumes provisioned on the cluster. They exist outside a namespace so they can be used cluster-wide. We can have various types including:

-   Local Volumes on the Nodes
-   Remote Volumes on an NFS
-   Cloud Volumes stored on some kind of cloud provider

These PVs are created via a YAML manifest.

### PersistentVolumeClaims

When writing a manifest for a pod that requires storage, a PV is not referenced directly in its YAML.

Instead a PersistentVolumeClaim (PVC) is used. This PVC acts as a layer of abstraction between the PV and the pod.

The PVC is created via a YAML manifest. Within this manifest we can declare options such as accessModes, required storage and volumeName.

The PVC will be bound to a PV in a one-to-one relationship. This PV can be referenced in the PVC via the volumeName option, or we can allow Kubernetes to automatically select whichever PV is suitable.

### StorageClasses

So far everything we have explained has been static. For situations requiring dynamic storage provisioning I use StorageClass objects.

For this project I will break the StorageClass into 2 main components

-   Provisioner
-   Properties of the PVs

#### Provisioner
This is the component that does the actual provisioning of the storage. 

There are two main types: 
-   Internal: which are shipped with Kubernetes and allow dynamic provisioning of their corresponding service, for example:
    -   AzureFile = Allows provisioning of Azure file shares
    -   VsphereVolume = VMware storage volumes
-   External: These are plugins we can use that are not shipped with Kubernetes, they typically use something called CSI drivers.

For this example, as I will be using a StorageClass with an NFS provisioner, an external CSI driver will be required.
Specifically, I will be using the CSI plugin [nfs.csi.k8s.io](https://github.com/kubernetes-csi/csi-driver-nfs).

#### Properties of the PVs
Decides the settings pass to the PV, some examples include:
-   Reclaim policy = what happens after the PVC is deleted, is the PV deleted or retained?
-   Mount options
-   Volume Expansion

### Prerequisites

-   NFS storage
-   CSI plugin

#### NFS storage
As I will be using an NFS share to create the PVs an NFS server is required

Using the instructions off the debian website  https://wiki.debian.org/NFS/Server I installed the server on the lima-jumpbox vm:
```
apt install nfs-kernel-server
```
Next create a directory to use as a file share:
```
mkdir /nfs_shares/share1
```
Modify the actual /etc/exports file to add the share, we will allow all VMs on the 192.168.105.0/24 range ReadWrite access to the share:
```
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/nfs_shares/share1 192.168.105.0/24(rw)
```
Export and make the share available:
```
exportfs -a
```
As a quick test I will add a file to this newly created share and confirm I can see it on both Nodes:
```
echo "This is test content within the nfs share1" >> /nfs_shares/share1/nfsFile.txt
```

Next we move over to one of the Node-0.
I will create a new directory for us to mount the share:
```
mkdir /nfs_server_shares/
```
However, when trying to mount the share we get the following error:
```
mount 192.168.105.4:/nfs_shares/share1 /nfs_server_shares/
mount: /nfs_server_shares: bad option; for several filesystems (e.g. nfs, cifs) you might need a /sbin/mount.<type> helper program.
       dmesg(1) may have more information after failed mount system call.
```

For us to mount the share we first need to install an additional tool called "nfs-common":
```
apt install nfs-common
```
Once installed we try mount again using:
```
mount 192.168.105.4:/nfs_shares/share1 /nfs_server_shares/
```
Now it is successful and we can view the file within the newly mounted share:
```
cat /nfs_server_shares/nfsFile.txt
This is test content within the nfs share1
```
These steps are then repeated on Node-1.
#### Install CSI plugin

As already mentioned we will be using an external CSI driver, this can be found here: [nfs.csi.k8s.io](https://github.com/kubernetes-csi/csi-driver-nfs)

I moved back to the lima-jumpbox and before moving forward I will confirm the plugin is not installed:
```
kubectl get csidrivers
No resources found
```
So following the documentation I can install via this curl command:
```
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.13.4/deploy/install-driver.sh | bash -s v4.13.4 --
```
The output is the following:
```
Installing NFS CSI driver, version: v4.13.4 ...
serviceaccount/csi-nfs-controller-sa created
serviceaccount/csi-nfs-node-sa created
clusterrole.rbac.authorization.k8s.io/nfs-external-provisioner-role created
clusterrolebinding.rbac.authorization.k8s.io/nfs-csi-provisioner-binding created
clusterrole.rbac.authorization.k8s.io/nfs-external-resizer-role created
clusterrolebinding.rbac.authorization.k8s.io/nfs-csi-resizer-role created
csidriver.storage.k8s.io/nfs.csi.k8s.io created
deployment.apps/csi-nfs-controller created
daemonset.apps/csi-nfs-node created
NFS CSI driver installed successfully.
```
As you can see it has created a deployment and daemonset both, we can confirm this by checking the running pods in the kube-system namespace:
```
kubectl get pods -n kube-system
NAME                                  READY   STATUS    RESTARTS       AGE
coredns-77c6799757-nkqj4              1/1     Running   0              12d
coredns-77c6799757-rzlm8              1/1     Running   0              12d
csi-nfs-controller-5fb889b4c6-6v8k7   5/5     Running   2 (5m3s ago)   6m4s
csi-nfs-node-brl9l                    3/3     Running   0              6m4s
csi-nfs-node-rzxvj                    3/3     Running   0              6m4s
```
Confirm the CSI driver is present via kubectl:
```
root@lima-jumpbox:~# kubectl get csidrivers
NAME             ATTACHREQUIRED   PODINFOONMOUNT   STORAGECAPACITY   TOKENREQUESTS   REQUIRESREPUBLISH   MODES        AGE
nfs.csi.k8s.io   false            false            false             <unset>         false               Persistent   18m
```

#### Create Default StorageClass
Like before, first confirm that there is no configured StorageClass:
```
kubectl get storageclass
No resources found
```
Next using the YAML file [DefaultStorageClass.yaml](DefaultStorageClass.yaml) we can create a StorageClass, this file was taken from the same repo as the CSI driver in the example section https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/README.md with only the following change made:
```
metadata:
  name: nfs-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
parameters:
  server: 192.168.105.4
  share: /nfs_shares/share1
```
The server is the IP of our lima-jumpbox, the share is what we configured in the last section, the other important detail is the "storageclass.kubernetes.io/is-default-class: "true"", this is how the storageclass is configured as default.

Now when we rerun the command to check:
```
kubectl get storageclass
NAME                PROVISIONER      RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-csi (default)   nfs.csi.k8s.io   Delete          Immediate           true                   12s
```

### Create Dynamic storage

This will involve 2 steps:
-   Create a PersistentVolumeClaim
-   Testing with a pod using the PVC 

#### Create PersistentVolumeClaim

We will use the attached yaml file [defaultSC-PVC.yaml](defaultSC-PVC.yaml).
As we are testing the default storageclass, the storageclassname option has been removed. This should force the cluster to provision a PV via the default storage class(nfs-csi).

Once the [defaultSC-PVC.yaml](defaultSC-PVC.yaml) has been applied, the PVC now exists along with a PV on the nfs server:
```
kubectl get pvc
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
app-data                 Bound    pvc-3a311b02-7d9b-48f4-8a75-78c18b7b28a6   1Gi        RWO            nfs-csi        <unset>                 52s
```
```
kubectl get persistentvolumes
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-3a311b02-7d9b-48f4-8a75-78c18b7b28a6   1Gi        RWO            Delete           Bound    default/app-data   nfs-csi        
```
It is also possible to verify the volume exists on the actual share by checking on the nfs server:
```
ls /nfs_shares/share1/
pvc-3a311b02-7d9b-48f4-8a75-78c18b7b28a6
```
#### Testing with a pod using the PVC 

Using the attached YAML [netutils-defaultSC-PVC.yaml](netutils-defaultSC-PVC.yaml) a pod will be created with basic network tools.

Inside the YAML the PVC is defined here:
```
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data
```
Along with the location to mount the PV:
```
      volumeMounts:
        - mountPath: /data
          name: data
```
Once saved and the pod is created, there are various ways that it can tested, the first way was exec into the pod itself and check if the storage is mounted:
```
kubectl exec --stdin --tty netutilsdefaultscpvc -- /bin/bash
```
Running the df command it can be seen /data is pointing to a volume the nfs server(192.168.105.4):
```
netutilsdefaultscpvc:/# df
Filesystem                                                                1K-blocks    Used Available Use% Mounted on
overlay                                                                    20431752 6303112  13248564  33% /
tmpfs                                                                         65536       0     65536   0% /dev
192.168.105.4:/nfs_shares/share1/pvc-3a311b02-7d9b-48f4-8a75-78c18b7b28a6  10113472 2969536   6683328  31% /data
/dev/vda1                                                                  20431752 6303112  13248564  33% /etc/hosts
shm                                                                           65536       0     65536   0% /dev/shm
tmpfs                                                                        900812      12    900800   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                                             4       0         4   0% /proc/acpi
```
Testing readwrite via:
````
netutilsdefaultscpvc:/# mkdir /data/testdir
````
And moving back to the nfs server, it can be seen the directory has been created on the volume:
```
root@lima-jumpbox:/# ls /nfs_shares/share1/pvc-3a311b02-7d9b-48f4-8a75-78c18b7b28a6/
testdir
```
