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
