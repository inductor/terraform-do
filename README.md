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
ssh root@206.189.151.66
ssh root@178.128.220.148
ssh root@188.166.254.170
ssh root@128.199.190.221

master internal IP: 10.130.0.3
```

Replace token in `bootstrap_master.sh`

```bash
sed "s/abc123abc123abc123/$DIGITALOCEAN_TOKEN/g" 
```
