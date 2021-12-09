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

## Install containerd
sudo apt-get update && sudo apt-get install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml

if grep -q "SystemdCgroup = true" "/etc/containerd/config.toml"; then
  echo "Config found, skip rewriting..."
else
  sed -i -e "s/SystemdCgroup \= false/SystemdCgroup \= true/g" /etc/containerd/config.toml
fi

sudo systemctl restart containerd

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.overcommit_memory = 1
vm.panic_on_oom = 0
kernel.panic = 10
kernel.panic_on_oops = 1
kernel.keys.root_maxkeys = 1000000
kernel.keys.root_maxbytes = 25000000
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
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: "systemd"
protectKernelDefaults: true
providerId: "digitalocean://`curl --silent http://169.254.169.254/metadata/v1/id`"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  criSocket: "/var/run/containerd/containerd.sock"
  kubeletExtraArgs:
    node-ip: "`curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address`"
discovery:
  bootstrapToken:
    apiServerEndpoint: "10.130.0.5:6443"
    token: "9a08jv.c0izixklcxtmnze7"
    unsafeSkipCAVerification: true
EOF

kubeadm join 10.130.0.5:6443 --config init_kubelet.yaml
