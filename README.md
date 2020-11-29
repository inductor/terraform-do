# Create Kubernetes cluster with kubeadm on DigitalOcean and cloud-provider

## Prerequisites

- Terraform > 0.13
- Bash
- SSH

## How to setup

Create an API token on Digital Ocean

```bash
export DIGITALOCEAN_TOKEN=your_token
```

Create SSH private key and register it on your Digital Ocean environment. By default the key name is WSL2, but you can change it.

Create droplets

```bash
terraform apply
```

You will get the following output:

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

infra = SSH information:
ssh root@188.166.241.91 # master-0
ssh root@68.183.234.19 # worker-0
ssh root@68.183.236.163 # worker-1
ssh root@68.183.226.145 # worker-2

master internal IP: 10.130.0.3
```

Replace token in `bootstrap_master.sh`

```bash
sed -i -e "s/abc123abc123abc123/$DIGITALOCEAN_TOKEN/g" bootstrap_master.sh
```

Apply `bootstrap_master.sh` on master-0

Copy the following output and replace the global IP to the internal IP

```
kubeadm join 188.166.241.91:6443 --token tmh9sq.u973nvaof6q7mzjh \
    --discovery-token-ca-cert-hash sha256:f04b8f46ed52d2a129e761480a154741ee8f68c8397735e21d93e238952e675b
```

Apply `bootstrap_node.sh` on worker-0, worker-1 and worker-2

Run `kubeadm join` with internal IP

Enjoy! Now you can use LoadBalancer and PVC on your cluster :D
