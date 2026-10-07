#!/bin/bash
# Aprovisiona el control-node: Ansible, Terraform, Azure CLI, kubectl y Docker
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release git unzip jq software-properties-common

# 1. Ansible
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

# 2. Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

# 3. Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# 4. kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor --yes -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

# 5. Docker (construye y publica las imágenes en el ACR para AKS)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker vagrant

echo "=== control-node listo ==="
terraform version | head -n 1
ansible --version | head -n 1
az version --query '"azure-cli"' -o tsv
kubectl version --client | head -n 1
