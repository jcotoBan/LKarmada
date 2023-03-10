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
git init && git pull https://github.com/jcotoBan/LKarmada.git

#Install terraform

apt-get update &&  apt-get install -y gnupg software-properties-common
apt-get install wget -y
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor |  tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/hashicorp.list
apt update && apt-get install terraform

#Install kubectl 

apt-get update && apt-get install -y ca-certificates curl && curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list
apt-get update && apt-get install -y kubectl

#install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -y
apt-get install helm -y

#Terraform Setup

echo 'export LINODE_TOKEN="<Linode API token>"' >> .bashrc #Inserting your linode token as an env variable on remote host.
source .bashrc

terraform -chdir=clusterstf init

terraform -chdir=clusterstf plan \
 -var-file="clusters.tfvars"


 terraform -chdir=clusterstf apply -auto-approve \
 -var-file="clusters.tfvars"

 
#Kubernetes clusters setup

echo 'export KUBE_VAR="$(terraform output -state=./clusterstf/terraform.tfstate kubeconfig_cluster_manager)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_cluster_manager.yaml
echo 'export KUBE_VAR="$(terraform output -state=./clusterstf/terraform.tfstate kubeconfig_us)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_us.yaml
echo 'export KUBE_VAR="$(terraform output -state=./clusterstf/terraform.tfstate kubeconfig_eu)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_eu.yaml
echo 'export KUBE_VAR="$(terraform output -state=./clusterstf/terraform.tfstate kubeconfig_ap)"' >> .bashrc && source .bashrc && echo $KUBE_VAR | base64 -di > kubeconfig_ap.yaml
echo 'alias k=kubectl' >> .bashrc
source .bashrc


#Karmada setup

helm repo add karmada-charts https://raw.githubusercontent.com/karmada-io/karmada/master/charts 

kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type==\"ExternalIP\")].address}" --kubeconfig=kubeconfig_cluster_manager.yaml > kcip.txt
