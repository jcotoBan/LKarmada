Multicluster MultiRegion with LKE and Karmada.
======================

#Overview and High level explanation

The main idea of this setup is to provide an easy to manage multiregion kubernetes cluster setup on Akamai Cloud (Linode), with the Linode Kubernetes Engine (LKE).

The steps to be performed are:

1-From a local workstation or laptop, trigger a terraform tenplate that will create the following:
 --> LKE cluster manager that will manage 3 cluster on 3 diferent regions, this one will be on Freemont.
 --> 3 LKE agent clusters that will be 


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
