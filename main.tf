# Configure the DigitalOcean Provider
provider "digitalocean" {
}

data "digitalocean_ssh_key" "wsl2" {
  name = "WSL2"
}

data "digitalocean_spaces_bucket_object" "bootstrap_worker" {
  bucket = "inductor"
  region = "fra1"
  key    = "bootstrap_node.sh"
}

resource "digitalocean_droplet" "master-0" {
  image     = "ubuntu-20-04-x64"
  name      = "master-0"
  region    = "sgp1"
  size      = "s-2vcpu-4gb"
  ssh_keys  = [data.digitalocean_ssh_key.wsl2.id]
  user_data = data.digitalocean_spaces_bucket_object.bootstrap_worker.body
}

resource "digitalocean_droplet" "worker-0" {
  image     = "ubuntu-20-04-x64"
  name      = "worker-0"
  region    = "sgp1"
  size      = "s-4vcpu-8gb"
  ssh_keys  = [data.digitalocean_ssh_key.wsl2.id]
  user_data = data.digitalocean_spaces_bucket_object.bootstrap_worker.body
}

resource "digitalocean_droplet" "worker-1" {
  image     = "ubuntu-20-04-x64"
  name      = "worker-1"
  region    = "sgp1"
  size      = "s-4vcpu-8gb"
  ssh_keys  = [data.digitalocean_ssh_key.wsl2.id]
  user_data = data.digitalocean_spaces_bucket_object.bootstrap_worker.body
}

resource "digitalocean_droplet" "worker-2" {
  image     = "ubuntu-20-04-x64"
  name      = "worker-2"
  region    = "sgp1"
  size      = "s-4vcpu-8gb"
  ssh_keys  = [data.digitalocean_ssh_key.wsl2.id]
  user_data = data.digitalocean_spaces_bucket_object.bootstrap_worker.body
}

locals {
  infra_info = <<INFRA
SSH information:
ssh root@${digitalocean_droplet.master-0.ipv4_address} # master-0
ssh root@${digitalocean_droplet.worker-0.ipv4_address} # worker-0
ssh root@${digitalocean_droplet.worker-1.ipv4_address} # worker-1
ssh root@${digitalocean_droplet.worker-2.ipv4_address} # worker-2

master internal IP: ${digitalocean_droplet.master-0.ipv4_address_private} # use it on worker nodes to join the cluster
INFRA
}

output "infra" {
  value = local.infra_info
}
