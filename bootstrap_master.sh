#!/bin/bash

set -ex

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

# Install Docker CE
apt-get update && apt-get install -y \
  docker-ce

# Set up the Docker daemon
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Create /etc/systemd/system/docker.service.d
mkdir -p /etc/systemd/system/docker.service.d

# Restart Docker
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

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

mkdir -p /var/lib/kubelet

echo "--cloud-provider=external --provider-id=digitalocean://`curl --silent http://169.254.169.254/metadata/v1/id` --cgroup-driver=\"systemd\" --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname" > /var/lib/kubelet/kubeadm-flags.env

cat > ~/init_kubelet.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
# nodeRegistration:
#   kubeletExtraArgs:
#     logging-format: "json"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controlPlaneEndpoint: "`curl --silent http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address`:6443"
apiServer:
  certSANs:
  - "`curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address`"
#   extraArgs:
#     logging-format: "json"
# controllerManager:
#   extraArgs:
#     logging-format: "json"
# scheduler:
#   extraArgs:
#     logging-format: "json"
# ---
# apiVersion: kubelet.config.k8s.io/v1beta1
# kind: KubeletConfiguration
# cgroupDriver: "systemd"
EOF

kubeadm init --config init_kubelet.yaml

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

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
