# Dokku Deployment Guide

Complete guide for deploying Curated.cx to a DigitalOcean VPS using Dokku.

---

## Overview

This guide covers:
1. **Infrastructure provisioning** with Terraform
2. **Dokku setup** and configuration
3. **Application deployment**
4. **SSL/TLS setup** with Let's Encrypt
5. **Recurring tasks** configuration

---

## Prerequisites

### Required Tools

- **Terraform** (>= 1.0) - Infrastructure provisioning
- **DigitalOcean CLI** (doctl) - Optional, for droplet management
- **SSH access** - To the DigitalOcean droplet
- **Git** - For deploying the application
- **DigitalOcean API Token** - For Terraform

### Required Information

- DigitalOcean API token
- SSH public key (for droplet access)
- Domain name (e.g., `curated.cx`)
- Admin email (for Let's Encrypt)

---

## Step 1: Provision Infrastructure

### 1.1 Get Your SSH Key ID

```bash
# List your SSH keys
doctl compute ssh-key list

# Note the ID or fingerprint of the key you want to use
```

### 1.2 Configure Terraform

```bash
cd terraform

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
```

**terraform.tfvars**:
```hcl
do_token      = "dop_v1_your_api_token_here"
ssh_key_id    = "12345678"  # Your SSH key ID or fingerprint
droplet_name  = "curated-prod"
droplet_size  = "s-2vcpu-4gb"  # Minimum recommended: 2GB RAM
droplet_region = "nyc1"
app_domain    = "curated.cx"
admin_email   = "admin@curated.cx"
```

### 1.3 Initialize and Apply Terraform

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (creates the droplet)
terraform apply
```

**Output**: Note the `droplet_ip` address from Terraform output.

### 1.4 Verify Droplet

```bash
# Get the IP from Terraform output
DROPLET_IP=$(terraform output -raw droplet_ip)

# Test SSH access
ssh root@$DROPLET_IP

# Exit once verified
exit
```

---

## Step 2: Bootstrap Dokku

### 2.1 Run Bootstrap Script

The bootstrap script automates:
- Dokku installation
- Firewall configuration
- PostgreSQL database creation
- Domain configuration
- SSL setup preparation
- Environment variables
- Storage volumes

```bash
# From project root
./script/bootstrap-dokku.sh <droplet-ip> <app-domain> <admin-email>

# Example
./script/bootstrap-dokku.sh 192.0.2.1 curated.cx admin@curated.cx
```

The script will prompt for:
- **RAILS_MASTER_KEY**: Get this from `config/master.key` or run `rails credentials:show`

### 2.2 Verify Dokku Installation

```bash
ssh root@$DROPLET_IP
dokku version
dokku apps:list
exit
```

---

## Step 3: Deploy Application

### 3.1 Add Git Remote

```bash
# Add Dokku as a git remote
git remote add dokku dokku@$DROPLET_IP:curated

# Verify remote
git remote -v
```

### 3.2 Deploy

```bash
# Deploy main branch (or your production branch)
git push dokku main

# Monitor deployment logs
ssh root@$DROPLET_IP 'dokku logs curated --tail'
```

### 3.3 Run Database Migrations

```bash
# Run migrations
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate'

# If using multi-database setup
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate:all'
```

---

## Step 4: Enable SSL/TLS

### 4.1 Enable Let's Encrypt

```bash
# Enable SSL for the app
ssh root@$DROPLET_IP 'dokku letsencrypt curated'

# Enable auto-renewal
ssh root@$DROPLET_IP 'dokku letsencrypt:auto-renew curated'
```

### 4.2 Verify SSL

```bash
# Check certificate status
ssh root@$DROPLET_IP 'dokku letsencrypt:list curated'

# Test HTTPS
curl -I https://curated.cx/up
```

---

## Step 5: Configure Recurring Tasks

### 5.1 Solid Queue Recurring Tasks

Solid Queue handles recurring tasks automatically via `config/recurring.yml`. No additional Dokku cron setup needed.

**Verify recurring tasks**:
```bash
# Check Solid Queue status
ssh root@$DROPLET_IP 'dokku run curated rails runner "puts SolidQueue::RecurringTask.all.map(&:name)"'
```

### 5.2 (Optional) Dokku Cron

If you need additional cron tasks outside Solid Queue:

```bash
# Install cron plugin
ssh root@$DROPLET_IP 'sudo dokku plugin:install https://github.com/dokku/dokku-cron.git'

# Add cron job
ssh root@$DROPLET_IP 'dokku cron:add curated "0 3 * * * dokku run curated rails runner \"SomeTask.perform\"'
```

---

## Step 6: Post-Deployment Configuration

### 6.1 Verify Application

```bash
# Health check
curl https://curated.cx/up

# Check logs
ssh root@$DROPLET_IP 'dokku logs curated --tail 50'
```

### 6.2 Set Additional Environment Variables

```bash
# Set any additional env vars
ssh root@$DROPLET_IP 'dokku config:set curated VARIABLE_NAME=value'

# View all config
ssh root@$DROPLET_IP 'dokku config curated'
```

### 6.3 Seed Database (Optional)

```bash
# Run seeds if needed
ssh root@$DROPLET_IP 'dokku run curated rails db:seed'
```

---

## Monitoring and Maintenance

### View Logs

```bash
# Real-time logs
ssh root@$DROPLET_IP 'dokku logs curated --tail'

# Recent logs
ssh root@$DROPLET_IP 'dokku logs curated --num 100'
```

### Check App Status

```bash
# App info
ssh root@$DROPLET_IP 'dokku apps:info curated'

# Resource usage
ssh root@$DROPLET_IP 'dokku resource:report curated'

# PostgreSQL info
ssh root@$DROPLET_IP 'dokku postgres:info curated-db'
```

### Run Rails Console

```bash
# Interactive console
ssh root@$DROPLET_IP 'dokku enter curated'

# Or one-liner
ssh root@$DROPLET_IP 'dokku run curated rails console'
```

---

## Rebuilding from Scratch

### Complete Rebuild Runbook

If you need to rebuild the entire server from scratch:

#### 1. Backup Current Data

```bash
# Backup PostgreSQL
ssh root@$DROPLET_IP 'dokku postgres:export curated-db > curated-db-backup.dump'

# Backup storage files (if any)
ssh root@$DROPLET_IP 'tar -czf storage-backup.tar.gz /var/lib/dokku/data/storage/curated-storage/'

# Download backups
scp root@$DROPLET_IP:~/curated-db-backup.dump ./
scp root@$DROPLET_IP:~/storage-backup.tar.gz ./
```

#### 2. Destroy Old Infrastructure

```bash
cd terraform

# Destroy droplet (WARNING: This deletes everything)
terraform destroy
```

#### 3. Provision New Infrastructure

```bash
# Re-provision
terraform apply

# Note the new IP
DROPLET_IP=$(terraform output -raw droplet_ip)
```

#### 4. Re-run Bootstrap

```bash
# Bootstrap new server
./script/bootstrap-dokku.sh $DROPLET_IP curated.cx admin@curated.cx
```

#### 5. Deploy Application

```bash
# Update git remote with new IP
git remote set-url dokku dokku@$DROPLET_IP:curated

# Deploy
git push dokku main

# Run migrations
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate'
```

#### 6. Restore Data

```bash
# Upload backups
scp curated-db-backup.dump root@$DROPLET_IP:~/
scp storage-backup.tar.gz root@$DROPLET_IP:~/

# Restore PostgreSQL
ssh root@$DROPLET_IP 'dokku postgres:import curated-db < curated-db-backup.dump'

# Restore storage
ssh root@$DROPLET_IP 'tar -xzf storage-backup.tar.gz -C /'
```

#### 7. Re-enable SSL

```bash
# Enable SSL
ssh root@$DROPLET_IP 'dokku letsencrypt curated'
ssh root@$DROPLET_IP 'dokku letsencrypt:auto-renew curated'
```

---

## Troubleshooting

### Common Issues

#### App Won't Start

```bash
# Check logs
ssh root@$DROPLET_IP 'dokku logs curated --tail 100'

# Check configuration
ssh root@$DROPLET_IP 'dokku config curated'

# Verify RAILS_MASTER_KEY is set
ssh root@$DROPLET_IP 'dokku config:get curated RAILS_MASTER_KEY'
```

#### Database Connection Issues

```bash
# Check database status
ssh root@$DROPLET_IP 'dokku postgres:info curated-db'

# Verify DATABASE_URL
ssh root@$DROPLET_IP 'dokku config:get curated DATABASE_URL'

# Test connection
ssh root@$DROPLET_IP 'dokku run curated rails db:version'
```

#### SSL Certificate Issues

```bash
# Check certificate status
ssh root@$DROPLET_IP 'dokku letsencrypt:list curated'

# Force certificate renewal
ssh root@$DROPLET_IP 'dokku letsencrypt:renew curated'

# Check domain DNS
dig curated.cx
dig www.curated.cx
```

#### Deployment Fails

```bash
# Check build logs
ssh root@$DROPLET_IP 'dokku logs curated --tail 200'

# Restart app
ssh root@$DROPLET_IP 'dokku ps:restart curated'

# Check resource limits
ssh root@$DROPLET_IP 'dokku resource:report curated'
```

### Debug Commands

```bash
# Enter app container
ssh root@$DROPLET_IP 'dokku enter curated'

# Run one-off commands
ssh root@$DROPLET_IP 'dokku run curated rails runner "puts Rails.env"'

# Check Dokku version
ssh root@$DROPLET_IP 'dokku version'

# List all apps
ssh root@$DROPLET_IP 'dokku apps:list'

# Check plugin status
ssh root@$DROPLET_IP 'dokku plugin:list'
```

---

## Architecture Details

### Infrastructure

- **Droplet**: Ubuntu 22.04 LTS
- **Size**: Minimum 2GB RAM recommended (s-2vcpu-4gb)
- **Firewall**: UFW with HTTP, HTTPS, SSH only

### Application Stack

- **Web Server**: Puma (via Thruster in Dockerfile)
- **Background Jobs**: Solid Queue (runs in Puma process)
- **Database**: PostgreSQL (via dokku-postgres plugin)
- **Storage**: Local filesystem volume mount
- **SSL**: Let's Encrypt via dokku-letsencrypt plugin

### Multi-Database Setup

The app uses Rails multi-database:
- **Primary**: `curated_production` (main app data)
- **Cache**: `curated_production_cache` (Solid Cache)
- **Queue**: `curated_production_queue` (Solid Queue)
- **Cable**: `curated_production_cable` (Action Cable)

All databases are created from the single PostgreSQL instance with `DATABASE_URL` pointing to the main database.

---

## Cost Estimation

**Minimum Setup** (s-2vcpu-4gb):
- Droplet: ~$24/month
- **Total**: ~$24/month

**Recommended Setup** (s-4vcpu-8gb):
- Droplet: ~$48/month
- **Total**: ~$48/month

**Scaling**:
- Add separate database droplet if needed
- Add dedicated job worker droplet for Solid Queue
- Use DigitalOcean Load Balancer for multiple app servers

---

## Security Best Practices

1. **Firewall**: Only HTTP, HTTPS, SSH open
2. **SSH Keys**: Use key-based authentication only
3. **Updates**: Keep Dokku and plugins updated
4. **Secrets**: Never commit secrets to git
5. **Backups**: Regular PostgreSQL backups
6. **Monitoring**: Set up monitoring/alerting

---

## Next Steps

1. **Monitoring**: Set up monitoring (e.g., Uptime Robot, Pingdom)
2. **Backups**: Configure automated PostgreSQL backups
3. **Scaling**: Consider separate database/job servers as traffic grows
4. **CDN**: Add CDN (Cloudflare) for static assets
5. **Log Aggregation**: Set up centralized logging

---

*Last Updated: 2025-01-20*
