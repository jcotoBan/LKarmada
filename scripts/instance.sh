#!/bin/bash
#General setup for the  user (ssh hardening)
useradd -m k8s_admin -s /bin/bash
echo -e "H57yUL8h\nH57yUL8h" | passwd k8s_admin #random password for k8s_admin wont be required since login will be through key and user will be able to sudo without password
mkdir /home/k8s_admin/.ssh
cp /root/.ssh/authorized_keys /home/k8s_admin/.ssh/authorized_keys
chmod 600 /home/k8s_admin/.ssh/authorized_keys
chmod 700 /home/k8s_admin/.ssh
chown -R k8s_admin:k8s_admin /home/k8s_admin/.ssh
echo $'#k8s_admin entry\nk8s_admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
sed -i '/^PermitRootLogin\s\w+/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config
systemctl restart sshd

#Git Install
apt-get update
apt-get install git -y
git init && git pull <place repo>
chmod +x clean.sh

#install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -y
apt-get install helm -y

#Install terraform

apt-get update &&  apt-get install -y gnupg software-properties-common
apt-get install wget -y
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor |  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/hashicorp.list
apt update &&  apt-get install terraform

#Install kubectl 

apt-get update && apt-get install -y ca-certificates curl && curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list
apt-get update && apt-get install -y kubectl

#Terraform Setup

echo 'export TF_VAR_token="<replace with your Linode token>"' >> .bashrc #Inserting your linode token as an env variable on remote host.
source .bashrc

terraform -chdir=clusterstf init

terraform -chdir=clusterstf plan \
 -var-file="clusters.tfvars"


 terraform apply -chdir=clusterstf -auto-approve \
 -var-file="clusters.tfvars"

 
#Kubernetes clusters setup

echo 'export KUBE_VAR="$(terraform output kubeconfig_cluster_manager)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_cluster_manager.yaml
echo 'export KUBE_VAR="$(terraform output kubeconfig_us)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_us.yaml
echo 'export KUBE_VAR="$(terraform output kubeconfig_eu)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_eu.yaml
echo 'export KUBE_VAR="$(terraform output kubeconfig_ap)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_ap.yaml
echo 'alias k=kubectl' >> .bashrc
source .bashrc




#Karmada setup
echo 'export KCIP=$(kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='ExternalIP')].address}" --kubeconfig=kubeconfig_cluster_manager.yaml)' \
>> .bashrc && source .bashrc

#Karmada master
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig-cluster-manager \
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
--set certs.auto.hosts[6]=$KCIP #Using ip of the cluster manager node

kubectl get secret karmada-kubeconfig \
 --kubeconfig=kubeconfig_cluster_manager.yaml \
 -n karmada-system \
 -o jsonpath={.data.kubeconfig} | base64 -d > karmada_config

 sed -i "s|https://karmada-apiserver.karmada-system.svc.cluster.local:5443|https://$KCIP:32443|g" karmada_config

kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..cluster.certificate-authority-data}' | base64 -d > caCrt.pem
kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..user.client-certificate-data}' | base64 -d crt.pem
kubectl config view --kubeconfig=karmada_config --minify --raw --output 'jsonpath={..user.client-key-data}' | base64 -d key.pem

#Installing the agent on each regional cluster

#To pass the master certificates to the agent helm installation it is required to pass them on values file 
echo "agent:" >> values.yaml
echo "  kubeconfig:" >> values.yaml
echo "    caCrt: |" >> values.yaml
cat caCrt.pem | sed 's/^/      /' >> values.yaml
echo "    crt: |" >> values.yaml
cat crt.pem | sed 's/^/      /' >> values.yaml
echo "    key: |" >> values.yaml
cat key.pem | sed 's/^/      /' >> values.yaml

#us agent cluster install
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_us.yaml \  
--create-namespace --namespace karmada-system \  
--version=1.2.0 \ 
--set installMode=agent \
--set agent.clusterName=us \ 
--set agent.kubeconfig.server=https://$KCIP:32443 \ 
--values values.yaml

#eu agent cluster install
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_eu.yaml \  
--create-namespace --namespace karmada-system \  
--version=1.2.0 \ 
--set installMode=agent \
--set agent.clusterName=eu \ 
--set agent.kubeconfig.server=https://$KCIP:32443 \ 
--values values.yaml

#ap agent cluster install
helm install karmada karmada-charts/karmada \
--kubeconfig=kubeconfig_ap.yaml \  
--create-namespace --namespace karmada-system \  
--version=1.2.0 \ 
--set installMode=agent \
--set agent.clusterName=ap \ 
--set agent.kubeconfig.server=https://$KCIP:32443 \ 
--values values.yaml

sleep 6

kubectl apply -f clusterstf/deploymentManifests/protoapp.yaml --kubeconfig=kubeconfig_cluster_manager.yaml
kubectl apply -f clusterstf/karmadaManifests/policy.yaml --kubeconfig=kubeconfig_cluster_manager.yaml
