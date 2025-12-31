#cka #course #k8s #kubernetes #cncf

#publish


## Authorization

Kubectl -> Authentication -> Authorization -> Create pod

## Admission Controllers

Kubectl -> Authentication -> Authorization -> Admission Controllers -> Create pod

Admission Controllers:
- AlwaysPullImages
- DefaultStorageClass
- EventRateLimit
- NamespaceAutoProvision
    - Not enabled by default
- NamespaceExists
    - Authenticated -> Authorized
        - If no namepsace, then it won't run
- Many more..

Linux Commands:
```bash
kube-apiserver -h | grep enable-admission-plugins
```

kubeadm based setup
```bash
kubectl exec kube-apiserver-controlplane -n kube-system -- kube-apiserver -h |
grep enable-admission-plugins
```
## Enabling Admission Controllers

For example update the ExecStart command in the systemd service file:

```/etc/systemd/system.service
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --enable-swagger-ui=true \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --event-ttl=1h \\
  --runtime-config=api/all \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --v=2 \\
  --enable-admission-plugins=NodeRestriction,NamespaceAutoProvision
```

For kubeadm-based setups:
```/etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --authorization-mode=Node,RBAC
    - --advertise-address=172.17.0.107
    - --allow-privileged=true
    - --enable-bootstrap-token-auth=true
    - --enable-admission-plugins=NodeRestriction,NamespaceAutoProvision
    image: k8s.gcr.io/kube-apiserver-amd64:v1.11.3
    name: kube-apiserver
```

To disable specific admission controller plugins, use the 
--disable-admission-plugins flag similarly.

This demonstrates how admission controllers not only reject invalid requests butcan also perform backend operations like automatically creating a namespace.

```bash
ps -ef | grep kube-apiserver | grep admission-plugins
```

---


202504011252
