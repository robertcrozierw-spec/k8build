# Kubeconfigs

Kubeconfigs are files containing information on the cluster(s), the client identity(ies), and the pairing of these. Typically they can be split into three components:

- **Cluster**: Contains the name of the cluster, the URL of the API server, and either a link to, or, an embedded CA certificate.
- **User**: The local name to be used along with the actual identity of the client (provided by its certificate). Also required is the client's private key, as it's needed for mTLS communication with the API server.
- **Context**: As there might be multiple clusters and clients defined in the same kubeconfig, a context allows you to bind certain users with certain clusters. A context can also be used to define the default namespace for this binding. As you can define multiple contexts, the default context is set via `current-context`.

In total six files will be created:
-   node-0.kubeconfig
-   node-1.kubeconfig
-   kube-proxy.kubeconfig
-   kube-controller-manager.kubeconfig
-   kube-scheduler.kubeconfig
-   admin.kubeconfig

In Kubernetes the Hard Way, I do not define the kubeconfigs yaml files directly instead the kubectl tool is leveraged to do that for me. Using kubectl for this has multiple benefits, including handling the YAML formatting along with easier inclusion of the embedded certificates without needing to manually encode them.

Starting with the node-0 and node-1 kublets.

```
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
```
Regarding the `set-credentials system:node:${host}` section, this is the specialized format required for the identity of the nodes, as described per the [Node Authorizer documentation](https://kubernetes.io/docs/reference/access-authn-authz/node/).