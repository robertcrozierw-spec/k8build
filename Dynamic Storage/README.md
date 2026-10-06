# Dynamic Storage And Default StorageClasses

In a typical Kubernetes environment there is a requirement for dynamic provisioning of storage or PersistentVolumes (PV).

This requirement comes from the need to reduce administrative load of manually creating PVs each time an application developer requests one. This process is implemented via StorageClasses (SC).

This section will explain a little more on the workings of StorageClasses, how they are configured and building the requirements necessary to implement them on our Kubernetes The Hard Way Cluster.

## Storage Concepts And Types

In Kubernetes their are 3 main storage concepts worth explaining.

-   PersistentVolumes
-   PersistentVolumeClaims
-   StorageClasses

### PersistentVolumes

PVs are just standard volumes provisioned on the cluster. They exist outside a namespace so they can be used cluster-wide. We can have various types including:

-   Local Volumes on the Nodes
-   Remote Volumes on an NFS
-   Cloud Volumes stored on some kind of cloud provider.

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
Decides what criteria to create or pass to the PV, some examples include:
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
Modify the actual /etc/exports file to add the share, we will allow all VMs on the 192.168.15.0/24 range ReadWrite access to the share:
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
Run the exportfs -a command to export and make the share available
As a quick test i will add a file to this newly created share and confirm I can see it on both Nodes:
```
echo "This is test content within the nfs share1" >> /nfs_shares/share1/nfsFile.txt
```

Next we move over to one of the Nodes.
I will cerate a new directory for us to mount the share:
```
mkdir /nfs_server_shares/
```
However When trying to mount the share we get the following error:
```
mount 192.168.105.4:/nfs_shares/share1 /nfs_server_shares/
mount: /nfs_server_shares: bad option; for several filesystems (e.g. nfs, cifs) you might need a /sbin/mount.<type> helper program.
       dmesg(1) may have more information after failed mount system call.
```

For us to mount the share we first need to install an additional tool called "nfs-common":
```
apt install nfs-common
````

Once installed we try mount again using the 
```
mount 192.168.105.4:/nfs_shares/share1 /nfs_server_shares/
```
Now it is successful and we can view the file within the newly mounted share:
```
cat /nfs_server_shares/nfsFile.txt
This is test content within the nfs share1
```
