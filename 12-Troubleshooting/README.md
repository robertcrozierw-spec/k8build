# My own testing and Validation

To start with I was getting more than one error when trying to apply the yaml files in the TestPods section:
```
 Warning  FailedCreatePodSandBox Failed to create pod sandbox: rpc error: code = Unknown desc = failed to create containerd task: failed to start shim: start failed: failed to create TTRPC connection: 
 dial unixYunix:///run/containerd/s/a7670ebd2cabff060174b155b92810c4570750934737724ec7f497fd808624dattrpc:
```
and
```
kubelet does not have ClusterDNS IP configured and cannot create Pod using "ClusterFirstpolicy. Falling back to "Default" policy
```

As the first error is related to containerd and shim the resolution was to install the latest version of containerd and runc on each Node.

Regarding the 2nd DNS error that will be discussed in a later section on DNS.

## Test Pod deployment
Using the yaml files in the TestPods section.

I deployed an nginx server and a supporting nodeport service so we can access pod.
```
kubectl apply nginx.yaml
kubectl apply -f nodeportnginx.yaml
```

Next we confirmed that nginx was up and which Node it was deployed to:
```
kubectl get pods -o wide
```

Once determined we can use the curl command to confirm working and accessible via the nodeport:
```
curl -I http://node-0:30080

HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Wed, 16 Sep 2026 10:55:09 GMT
```

We can also test this through the web browser on my local machine as the IP is accessible:
```
http://192.168.105.6:30080/
```

And confirmed nginx sucessfully up!

## Test communication across pods via IP
After creating the "my-nginx" pod we exec into the pod, I will try to ping and curl the ip of my other pod "my-nginx1"

```
exec --stdin --tty my-nginx -- /bin/bash
root@my-nginx:/# ping 10.200.1.58
PING 10.200.1.58 (10.200.1.58) 56(84) bytes of data.

curl 10.200.1.58:80
```

However I receive no response from either

I can see 2 possible reasons here:
-   The my-nginx1 is not exposed via a cluster-ip service
-   The my-nginx1 IP is not routable as it is on another node

### IP incorrectly exposed  
This is false, as we are trying to connect directly via the IP, as long as the port is exposed in the initial yaml we should be ok.

I can confirm this via a curl command from a pod running on the same node:
```
root@my-nginx:/# curl 10.200.0.80:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

### IP not routable

This is the more likely as checking we are unable to ping any pods running on opposite clusters:
```
root@node-1:~# ping 10.200.0.78 
PING 10.200.0.78 (10.200.0.78) 56(84) bytes of data.

```
Lets add a route using this command and try again:
```
ip route add 10.200.0.0/24 via 192.168.105.6
```
This commands will redirect anything for the 10.200.0.0 range(subnet used by node-0) via the 192.168.105.6(node-1)

Running the ping again:
```
root@node-1:~# ping 10.200.0.78 
PING 10.200.0.78 (10.200.0.78) 56(84) bytes of data.
64 bytes from 10.200.0.78: icmp_seq=1 ttl=63 time=0.985 ms
64 bytes from 10.200.0.78: icmp_seq=2 ttl=63 time=0.912 ms
```

Add route to other node as well:
```
ip route add 10.200.1.0/24 via 192.168.105.7
```

Also lets add both of these routes to the Controller:
```
root@server:~# ip route add 10.200.0.0/24 via 192.168.105.6
root@server:~# ip route add 10.200.1.0/24 via 192.168.105.7
```

Now finally when we exec into our nginx pod we can successfully curl our nginx pod running on node-1:
```
root@my-nginx:/# curl 10.200.1.59:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

However this should have already been resolved in the "Add the routes" section, the problem is the "ip route add" command is not persistent after reboot. This could be resolved by a start-up script of some kind, or potentially a systemd service.

