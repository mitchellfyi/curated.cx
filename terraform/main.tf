terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_id" {
  description = "SSH key ID or fingerprint to add to the droplet"
  type        = string
}

variable "droplet_name" {
  description = "Name for the DigitalOcean droplet"
  type        = string
  default     = "curated-prod"
}

variable "droplet_size" {
  description = "Droplet size slug (e.g., s-2vcpu-4gb)"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "droplet_region" {
  description = "DigitalOcean region slug (e.g., nyc1)"
  type        = string
  default     = "nyc1"
}

variable "app_domain" {
  description = "Primary domain for the application"
  type        = string
}

variable "admin_email" {
  description = "Email address for Let's Encrypt certificates"
  type        = string
}

provider "digitalocean" {
  token = var.do_token
}

# Create droplet
resource "digitalocean_droplet" "curated" {
  image    = "ubuntu-22-04-x64"
  name     = var.droplet_name
  region   = var.droplet_region
  size     = var.droplet_size
  ssh_keys = [var.ssh_key_id]

  tags = ["curated", "production", "dokku"]

  user_data = <<-EOF
    #!/bin/bash
    # Basic server hardening
    export DEBIAN_FRONTEND=noninteractive

    # Update system
    apt-get update -y
    apt-get upgrade -y

    # Install basic utilities
    apt-get install -y curl wget git ufw

    # Configure firewall (will be fully configured by bootstrap script)
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh

    # Create dokku user (will be set up by bootstrap script)
    useradd -m -s /bin/bash dokku || true
  EOF
}

# Output droplet IP address
output "droplet_ip" {
  description = "IP address of the droplet"
  value       = digitalocean_droplet.curated.ipv4_address
}

output "droplet_id" {
  description = "ID of the droplet"
  value       = digitalocean_droplet.curated.id
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh root@${digitalocean_droplet.curated.ipv4_address}"
}
