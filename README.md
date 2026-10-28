# K8build

Personal project to build Kubernetes cluster from scratch.
Main learning goal is to gain a bottom up understanding of Kubernetes clusters and some of the additional components that are typically included.
I will be initially following steps in the Kubernetes the hard way found here:
https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md

However, once completed I will be adding additional components such as coreDNS, MetalLB and Dynamic storage. Finally for testing I deploy this [aks-store-demo application](https://github.com/Azure-Samples/aks-store-demo). 
Some of this content was initially done in another repo: [K8build-part-2](../K8build-part-2/) however, I have decided it is better suited here and am in the process of migrating it as such.

## Contents

- [Prerequisites: Lima and the VMs](./00-Prerequisites/)
- [1. Configure Jumpbox](./01-Configure-Jumpbox/)
- [2. Configure Compute Resources](./02-Configure-Compute-Resources/)
- [3. PKI Theory](./03-PKI-Theory/)
- [4. Certificate Generation](./04-Certificate-Generation/)
- [5. Kubeconfigs](./05-Kubeconfigs/)
- [6. Generating Data Encryption Config and Key](./06-Generating-Data-Encryption-Config-And-Key/)
- [7. Bootstrapping etcd Cluster](./07-Bootstrapping-etcd/)
- [8. Bootstrapping Kubernetes Control Plane](./08-Bootstrapping-Kubernetes-Control-Plane/)
- [9. Bootstrapping Kubernetes Worker Nodes]()



## Bootstrapping the Kubernetes Worker Nodes

Activates the netfilter module and adds it start up
       {
         modprobe br-netfilter
         echo "br-netfilter" >> /etc/modules-load.d/modules.conf
       }
       
       root@lima-jumpbox:~/kubernetes-the-hard-way# ssh root@server \
         "kubectl get nodes \
         --kubeconfig admin.kubeconfig"
NAME     STATUS   ROLES    AGE   VERSION
node-0   Ready    <none>   37s   v1.32.3
node-1   Ready    <none>   40s   v1.32.3

We can then transfer across the files needed:


## Configuring kubectl for Remote Access

## Provisioning Pod Network Routes

We need to configure routes between the Nodes as right now pods created on each will not have access to other

Using our machines.txt we will seperate the IPs of VM and also the IP subnet each node will use to assign to pods

       {
         SERVER_IP=$(grep server machines.txt | cut -d " " -f 1)
         NODE_0_IP=$(grep node-0 machines.txt | cut -d " " -f 1)
         NODE_0_SUBNET=$(grep node-0 machines.txt | cut -d " " -f 4)
         NODE_1_IP=$(grep node-1 machines.txt | cut -d " " -f 1)
         NODE_1_SUBNET=$(grep node-1 machines.txt | cut -d " " -f 4)
       }
       
Lets print out the values to confirm what we have:
       {
       echo SERVER_IP $SERVER_IP
       echo NODE_0_IP $NODE_0_IP
       echo NODE_0_SUBNET $NODE_0_SUBNET
       echo NODE_1_IP $NODE_1_IP
       echo NODE_1_SUBNET $NODE_1_SUBNET
       }

output:
```
SERVER_IP 192.168.105.5
NODE_0_IP 192.168.105.6
NODE_0_SUBNET 10.200.0.0/24
NODE_1_IP 192.168.105.7
NODE_1_SUBNET 10.200.1.0/24
```

### Add the routes
A network route is a manual entry that creates a pathway to reach another network when access is not already configured

We will make it that the node_$_IP is the gateway for its corresponding SUBNET
We will need to do this for all 3 of our server
We will use the " ip route add "destination" via "gateway" "

        ssh root@server <<EOF
          ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
          ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
        EOF

We can run the ip table show command on the SERVER VM after and see the routes have been added
10.200.0.0/24 via 192.168.105.6 dev lima0 
10.200.1.0/24 via 192.168.105.7 dev lima0 

For the node-0 VM
        ssh root@node-0 <<EOF
          ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
        EOF

output:
10.200.1.0/24 via 192.168.105.7 dev lima0 

For the node-1 VM
        ssh root@node-1 <<EOF
          ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
        EOF

output:
10.200.0.0/24 via 192.168.105.6 dev lima0 

### My own testing and Validation

To start with I was getting more than one error when trying to apply the suggested deployment:
```
 Warning  FailedCreatePodSandBox Failed to create pod sandbox: rpc error: code = Unknown desc = failed to create containerd task: failed to start shim: start failed: failed to create TTRPC connection: 
 dial unixYunix:///run/containerd/s/a7670ebd2cabff060174b155b92810c4570750934737724ec7f497fd808624dattrpc:
```
and

        kubelet does not have ClusterDNS IP configured and cannot create Pod using "ClusterFirst" policy. Falling back to "Default" policy

As the first error is related to containerd and shim the resolution was to install the latest version of containerd and runc on each Node

Once reoslved the next issue was accessing the master node

Regarding the 2nd DNS error that will be discussed in a later section on DNS

#### Test Pod deployment
Using the yaml files in the TestPods section

Moving the files first onto the Jumpbox by manually creating them and copying in the contents(we can impove this later)

I depolyed an nginx server and a supporting nodeport service so we can access pod.
```
kubectl apply nginx.yaml
kubectl apply -f nodeportnginx.yaml
```

Next we confirmed the neginx working and also which Node it was deployed to
        kubectl get pods -o wide

Once determined we can use the curl command to confirm working and accessible via the nodeport
        curl -I http://node-0:30080

HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 16 Sep 2026 10:55:09 GMT
Content-Type: text/html
Content-Length: 896
Last-Modified: Tue, 15 Sep 2026 12:54:15 GMT
Connection: keep-alive
ETag: "6aa93ff7-380"
Accept-Ranges: bytes


We can also test this through the webbrowser on my local machine as the IP is accessible.

        http://192.168.105.6:30080/

And confirmed nginx sucessfully up!

#### Test communication across pods via IP
After creating my-nginx we exec into the pod, I will try to ping and curl the ip of my-nginx1

```
exec --stdin --tty my-nginx -- /bin/bash
root@my-nginx:/# ping 10.200.1.58
PING 10.200.1.58 (10.200.1.58) 56(84) bytes of data.
```
        curl 10.200.1.58:80

However I receive no response from either

I can see 2 possible reasons here:
1. The my-nginx1 is not exposed via a cluster-ip service
2. The my-nginx1 IP is not routable as it is on another node

#### 1. 
This is false, as we are trying to connect directly via the IP, as long as the port is exposed in the initial yaml we should be ok.

I can confirm this via a curl command from a pod running on the same node
```
root@my-nginx:/# curl 10.200.0.80:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>
```

#### 2. 

This is the more likely as checking we are unable to ping any pods running on opposite clusters
```
root@node-1:~# ping 10.200.0.78 
PING 10.200.0.78 (10.200.0.78) 56(84) bytes of data.

```
Lets add a route using this command and try again
```
ip route add 10.200.0.0/24 via 192.168.105.6
```
This commands will redirect anything for the 10.200.0.0 range(subnet used by node-0) via the 192.168.105.6(node-1)

Running the ping again
```
root@node-1:~# ping 10.200.0.78 
PING 10.200.0.78 (10.200.0.78) 56(84) bytes of data.
64 bytes from 10.200.0.78: icmp_seq=1 ttl=63 time=0.985 ms
64 bytes from 10.200.0.78: icmp_seq=2 ttl=63 time=0.912 ms
```

Add route to other node as well
```
ip route add 10.200.1.0/24 via 192.168.105.7
```

Also lets add both of these routes to the Controller
```
root@server:~# ip route add 10.200.0.0/24 via 192.168.105.6
root@server:~# ip route add 10.200.1.0/24 via 192.168.105.7
```

Now finally when we exec into our nginx pod we can successfully curl our nginx pod running on node-1
```
root@my-nginx:/# curl 10.200.1.59:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

```

However this should have already been resolved in the "Add the routes" section, the problem is the "ip route add" command
is not persistent after reboot. This could be resolved by a start-script of somekind, or potentially a systemd service.




