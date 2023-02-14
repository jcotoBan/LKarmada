MultiCluster MultiRegion with LKE and Karmada.
======================

# Overview and High level explanation

The main idea of this setup is to provide an easy to manage multiregion kubernetes cluster setup on Akamai Cloud (Linode), with the Linode Kubernetes Engine (LKE).


Requirements:

A laptop or workstation or vm with terraform installed.
Linode account with a valid api token with access to Linodes and LKE.


The steps to be performed are:

1) From a local workstation or laptop, trigger a terraform tenplate that will create the following:  

--A simple Linode instance from which we will manage the clusters. It does some hardening as disabling ssh root login and creating a custom user name k8s_admin with sudo access. Some generic ssh keys are included, however it is strongly recommended to setup your own.  

--LKE cluster manager that will manage 3 cluster on 3 diferent regions, this one will be on us-west.  

--3 LKE agent clusters that will be the ones in which we will directly setup our workloads, each on a different region:  
    *us-west  
    *eu-west  
    *ap-south  

--Some preparation for the Karmada setup.  

2) Setup everything related to karmada to start managing the clusters.


3) 


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

```
 sed -i "s|https://karmada-apiserver.karmada-system.svc.cluster.local:5443|https://$(cat kcip.txt):32443|g" karmada_config
```

```
kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' | base64 -d > caCrt.pem
kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..user.client-certificate-data}' | base64 -d > crt.pem
kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..user.client-key-data}' | base64 -d > key.pem
```

```
echo "agent:" >> values.yaml && \
echo "  kubeconfig:" >> values.yaml && \
echo "    caCrt: |" >> values.yaml && \
cat caCrt.pem | sed 's/^/      /' >> values.yaml && \
echo "    crt: |" >> values.yaml && \
cat crt.pem | sed 's/^/      /' >> values.yaml && \
echo "    key: |" >> values.yaml && \
cat key.pem | sed 's/^/      /' >> values.yaml
```

```
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_us.yaml \
--create-namespace --namespace karmada-system \
--version=1.2.0 \
--set installMode=agent \
--set agent.clusterName=us \
--set agent.kubeconfig.server="https://$(cat kcip.txt):32443" \
--values values.yaml
```

```
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_ap.yaml \
--create-namespace --namespace karmada-system \
--version=1.2.0 \
--set installMode=agent \
--set agent.clusterName=ap \
--set agent.kubeconfig.server="https://$(cat kcip.txt):32443" \
--values values.yaml
```

```
kubectl apply -f clusterstf/deploymentManifests/protoapp.yaml --kubeconfig=karmada_config
kubectl apply -f clusterstf/karmadaManifests/policy.yaml --kubeconfig=karmada_config
```

