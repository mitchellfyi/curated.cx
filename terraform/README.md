# Terraform Configuration for DigitalOcean

This directory contains Terraform configuration for provisioning a DigitalOcean droplet for Curated.cx.

## Quick Start

1. **Copy example variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - `do_token`: Your DigitalOcean API token
   - `ssh_key_id`: Your SSH key ID or fingerprint
   - `app_domain`: Your domain name
   - `admin_email`: Email for Let's Encrypt

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

5. **Get the droplet IP**:
   ```bash
   terraform output droplet_ip
   ```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `do_token` | DigitalOcean API token | *required* |
| `ssh_key_id` | SSH key ID or fingerprint | *required* |
| `droplet_name` | Droplet name | `curated-prod` |
| `droplet_size` | Droplet size slug | `s-2vcpu-4gb` |
| `droplet_region` | DigitalOcean region | `nyc1` |
| `app_domain` | Application domain | *required* |
| `admin_email` | Admin email for SSL | *required* |

## Outputs

- `droplet_ip`: IP address of the created droplet
- `droplet_id`: DigitalOcean ID of the droplet
- `ssh_command`: SSH command to connect to the droplet

## Getting Your SSH Key ID

```bash
# List your SSH keys
doctl compute ssh-key list

# Use either the ID or fingerprint in terraform.tfvars
```

## Getting Your DigitalOcean API Token

1. Go to https://cloud.digitalocean.com/account/api/tokens
2. Generate a new token
3. Copy the token to `terraform.tfvars`

## Destroying Infrastructure

```bash
# Destroy all resources
terraform destroy
```

**Warning**: This will delete the droplet and all data on it. Make sure you have backups!
