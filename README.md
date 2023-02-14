# LKarmada
LKE multiregion cluster base setup with karmada


```
#Karmada master
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_cluster_manager.yaml \
--create-namespace --namespace karmada-system \
--version=1.2.0 \
--set apiServer.hostNetwork=false \
--set apiServer.serviceType=NodePort \
--set apiServer.nodePort=32443 \
--set certs.auto.hosts[0]="kubernetes.default.svc" \
--set certs.auto.hosts[1]="*.etcd.karmada-system.svc.cluster.local" \
--set certs.auto.hosts[2]="*.karmada-system.svc.cluster.local" \
--set certs.auto.hosts[3]="*.karmada-system.svc" \
--set certs.auto.hosts[4]="localhost" \
--set certs.auto.hosts[5]="127.0.0.1" \
--set certs.auto.hosts[6]=$(cat kcip.txt)
```

```
kubectl get secret karmada-kubeconfig \
 --kubeconfig=kubeconfig_cluster_manager.yaml \
 -n karmada-system \
 -o jsonpath={.data.kubeconfig} | base64 -d > karmada_config
```
