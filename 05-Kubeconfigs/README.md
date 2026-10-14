## Kubeconfigs
Kubeconfigs are file's containing information on the cluster
- Name of cluster
- Certificates to access
- API of cluster URL

They are used by kubectl, users and other services to connect to cluster

For the kubelet's or nodes Kubeconfig, we must reference the
-   CA cert
-   Client keypair
-   URL of API server 
-   Embed - certs just means the certs will be within the Kubeconfig output file and just a path to them


for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done
