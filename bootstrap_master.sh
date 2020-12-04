#!/bin/bash

set -ex

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# (Install Docker CE)
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

# Add Docker's official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key --keyring /etc/apt/trusted.gpg.d/docker.gpg add -

# Add the Docker apt repository:
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

## Install containerd
sudo apt-get update && sudo apt-get install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml

sed -e "/^          privileged_without_host_devices = false$/a\          \[plugins\.\"io\.containerd\.grpc\.v1\.cri\"\.containerd\.runtimes\.runc\.options\]\n            SystemdCgroup \= true" /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

cat > ~/init_kubelet.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:
- token: "9a08jv.c0izixklcxtmnze7"
  description: "kubeadm bootstrap token"
  ttl: "24h"
nodeRegistration:
  criSocket: "/var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    provider-id: "digitalocean://`curl --silent http://169.254.169.254/metadata/v1/id`"
    node-ip: "`curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address`"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controlPlaneEndpoint: "`curl --silent http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address`:6443"
apiServer:
  certSANs:
  - "`curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address`"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
CgroupDriver: "systemd"
EOF

kubeadm init --config init_kubelet.yaml --skip-phases=addon/kube-proxy

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.9.0 \
    --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=`curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address` \
    --set k8sServicePort=6443

cat > ~/secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "abc123abc123abc123" #FIXME
EOF

kubectl apply -f secret.yaml

kubectl apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/v0.1.30.yml

kubectl apply -fhttps://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v2.1.1/{crds.yaml,driver.yaml,snapshot-controller.yaml}
