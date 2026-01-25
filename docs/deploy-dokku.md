# Dokku Deployment Guide

Complete guide for deploying Curated.cx to a DigitalOcean VPS using Dokku.

**This guide is written for beginners** - if you're new to Terraform, DigitalOcean, or Dokku, this will walk you through everything step-by-step.

---


## 🚀 Quick Start (One Command Setup)

**If you want maximum automation**, run this single command:

```bash
./script/deploy-full-setup.sh
```

This does EVERYTHING automatically:
1. Creates your DigitalOcean server with Terraform
2. Installs and configures Dokku
3. Sets up PostgreSQL, SSL, backups
4. Configures GitHub Actions for auto-deploy
5. Deploys your app

After running it, just push to `main` to deploy:
```bash
git push origin main
```

**Prerequisites for quick start**:
- `terraform` installed (`brew install terraform`)
- `gh` CLI installed and authenticated (`brew install gh && gh auth login`)
- `terraform/terraform.tfvars` configured with your DigitalOcean token

---


## What Gets Automated

| Feature | Status |
|---------|--------|
| Server provisioning | ✅ Terraform |
| Dokku installation | ✅ Bootstrap script |
| PostgreSQL setup | ✅ Auto-configured |
| SSL certificates | ✅ Let's Encrypt (auto-renewal) |
| Daily database backups | ✅ Cron job |
| Zero-downtime deploys | ✅ Dokku checks |
| Health checks | ✅ Before/after deploy |
| Automatic rollback | ✅ On deploy failure |
| Push-to-deploy | ✅ GitHub Actions |
| GitHub secrets setup | ✅ Automated script |

---


## What You'll Learn

This guide will teach you:
- **Terraform**: Infrastructure as Code tool that creates servers automatically
- **DigitalOcean**: Cloud provider that hosts your server (like AWS, but simpler)
- **Dokku**: A platform that makes deploying Rails apps as easy as pushing to Git

---


## Overview

This guide covers:
1. **Infrastructure provisioning** with Terraform (creating the server)
2. **Dokku setup** and configuration (installing the deployment platform)
3. **Application deployment** (pushing your code)
4. **SSL/TLS setup** with Let's Encrypt (free HTTPS certificates)
5. **Recurring tasks** configuration (background jobs)
6. **Automatic deployments** with GitHub Actions (deploy on every push)

---


## Understanding the Tools

### What is Terraform?

**Terraform** is a tool that lets you describe your infrastructure (servers, databases, etc.) in code. Instead of clicking buttons in a web interface, you write configuration files and Terraform creates everything automatically.

**Why use it?**
- **Reproducible**: You can recreate your server exactly the same way anytime
- **Version controlled**: Your infrastructure is in Git, just like your code
- **Fast**: Creates servers in minutes instead of hours of manual setup

**How it works:**
1. You write a `.tf` file describing what you want (a server with 4GB RAM, Ubuntu, etc.)
2. You run `terraform apply`
3. Terraform talks to DigitalOcean's API and creates the server
4. You get a server ready to use

### What is DigitalOcean?

**DigitalOcean** is a cloud hosting provider. They rent you virtual servers (called "droplets") that run in their data centers.

**Key concepts:**
- **Droplet**: A virtual server (like a computer in the cloud)
- **Region**: The physical location of the data center (e.g., New York, San Francisco)
- **Size**: How powerful the server is (CPU, RAM, disk space)
- **SSH Key**: A secure way to log into your server without passwords

**Why DigitalOcean?**
- Simple and affordable (starts at $6/month)
- Great documentation
- Fast setup
- Good for small to medium applications

### What is Dokku?

**Dokku** is a self-hosted platform that makes deploying apps as easy as Heroku, but on your own server.

**How it works:**
- You push your code to Git
- Dokku automatically builds and runs your app
- It handles databases, SSL certificates, and more
- It's like having your own mini-Heroku

**Why use Dokku?**
- **Simple**: Deploy with `git push`
- **Free**: No per-app fees (just pay for the server)
- **Flexible**: Full control over your server
- **Familiar**: Works like Heroku if you've used it

---


## Prerequisites

### Required Tools

You'll need to install these on your local computer:

#### 1. Terraform

**What it is**: Tool for creating infrastructure automatically

**Installation**:

**macOS** (using Homebrew):
```bash
brew install terraform
```

**Linux**:
```bash
# Download from https://www.terraform.io/downloads
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Windows**:
- Download from https://www.terraform.io/downloads
- Extract and add to PATH

**Verify installation**:
```bash
terraform version
# Should show: Terraform v1.x.x
```

#### 2. DigitalOcean CLI (doctl) - Optional but Recommended

**What it is**: Command-line tool for managing DigitalOcean resources

**Installation**:

**macOS**:
```bash
brew install doctl
```

**Linux**:
```bash
cd ~
wget https://github.com/digitalocean/doctl/releases/download/v1.94.0/doctl-1.94.0-linux-amd64.tar.gz
tar xf doctl-1.94.0-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin
```

**Windows**:
- Download from https://github.com/digitalocean/doctl/releases
- Extract and add to PATH

**Verify installation**:
```bash
doctl version
```

#### 3. SSH (Usually Pre-installed)

**What it is**: Secure way to connect to your server

**Check if installed**:
```bash
ssh -V
# Should show: OpenSSH_8.x or similar
```

**If not installed**:
- **macOS/Linux**: Usually pre-installed
- **Windows**: Install Git Bash or use WSL

#### 4. Git (Usually Pre-installed)

**What it is**: Version control system (you're already using it!)

**Check if installed**:
```bash
git --version
```

### Required Information

Before you start, gather these:

1. **DigitalOcean Account**
   - Sign up at https://www.digitalocean.com
   - Add a payment method (you'll need it to create servers)

2. **DigitalOcean API Token**
   - Go to https://cloud.digitalocean.com/account/api/tokens
   - Click "Generate New Token"
   - Name it "Terraform" or "Curated Deployment"
   - Select "Write" scope (full access)
   - Click "Generate Token"
   - **Copy the token immediately** - you won't see it again!
   - Save it somewhere safe (password manager recommended)

3. **SSH Key**
   - You need an SSH key to securely access your server
   - If you don't have one, we'll create it in the next section

4. **Domain Name**
   - Your domain (e.g., `curated.cx`)
   - You'll need to point DNS to your server later

5. **Email Address**
   - Used for Let's Encrypt SSL certificates
   - Can be any email you control

---


## Step 1: Set Up SSH Keys

### 1.1 Check if You Have an SSH Key

**What is an SSH key?** It's a secure way to log into your server without typing a password. It's like a digital key that unlocks your server.

**Check if you already have one**:
```bash
ls -la ~/.ssh/id_rsa.pub
# or
ls -la ~/.ssh/id_ed25519.pub
```

If you see a file, you already have a key! Skip to section 1.2.

### 1.2 Create an SSH Key (If Needed)

**Create a new SSH key**:
```bash
# This creates a new SSH key pair
ssh-keygen -t ed25519 -C "your_email@example.com"

# When prompted:
# - Press Enter to save to default location (~/.ssh/id_ed25519)
# - Press Enter for no passphrase (or set one if you prefer)
```

**What just happened?**
- Created two files:
  - `~/.ssh/id_ed25519` (private key - keep this secret!)
  - `~/.ssh/id_ed25519.pub` (public key - this is safe to share)

### 1.3 Add SSH Key to DigitalOcean

**Option A: Using DigitalOcean Web Interface** (Easier for beginners)

1. Go to https://cloud.digitalocean.com/account/security
2. Click "Add SSH Key"
3. Give it a name (e.g., "My Laptop")
4. Copy your public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # or if you have id_rsa:
   cat ~/.ssh/id_rsa.pub
   ```
5. Paste the entire output into the "SSH Key Content" field
6. Click "Add SSH Key"
7. **Note the fingerprint** shown (looks like: `aa:bb:cc:dd:...`)

**Option B: Using doctl CLI**

```bash
# First, authenticate doctl
doctl auth init
# Enter your API token when prompted

# Add your SSH key
doctl compute ssh-key import "My Laptop" --public-key-file ~/.ssh/id_ed25519.pub

# List your keys to get the ID
doctl compute ssh-key list
```

**What you need**: Either the **fingerprint** (from web interface) or the **ID** (from CLI). You'll use this in the next step.

---


## Step 2: Provision Infrastructure with Terraform

### 2.1 Understanding Terraform Files

**What are we doing?** We're going to tell Terraform to create a server on DigitalOcean.

**The files we'll use**:
- `terraform/main.tf` - Describes what server to create (already written)
- `terraform/terraform.tfvars` - Your specific values (you'll create this)

### 2.2 Configure Terraform Variables

```bash
cd terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars
```

**Now edit `terraform.tfvars`** with your values:

```hcl
# Your DigitalOcean API token (from Step 1)
do_token = "dop_v1_abc123xyz..."  # Paste your token here

# Your SSH key fingerprint or ID (from Step 1.3)
# Use the fingerprint from the web interface (e.g., "aa:bb:cc:dd:...")
# OR use the ID from doctl (e.g., "12345678")
ssh_key_id = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"

# Name for your server (can be anything)
droplet_name = "curated-prod"

# Server size - how powerful your server is
# Options:
#   s-1vcpu-1gb    = 1 CPU, 1GB RAM ($6/month) - Too small for Rails
#   s-2vcpu-2gb    = 2 CPU, 2GB RAM ($12/month) - Minimum for Rails
#   s-2vcpu-4gb    = 2 CPU, 4GB RAM ($24/month) - Recommended minimum
#   s-4vcpu-8gb    = 4 CPU, 8GB RAM ($48/month) - Better performance
droplet_size = "s-2vcpu-4gb"

# Region - where your server is located
# Choose closest to your users:
#   nyc1, nyc2, nyc3  = New York
#   sfo1, sfo2, sfo3  = San Francisco
#   ams1, ams2, ams3  = Amsterdam
#   sgp1              = Singapore
#   tor1              = Toronto
#   blr1              = Bangalore
#   fra1              = Frankfurt
droplet_region = "nyc1"

# Your domain name
app_domain = "curated.cx"

# Your email (for SSL certificate notifications)
admin_email = "admin@curated.cx"
```

**Understanding the variables**:

- **`do_token`**: This is like a password that lets Terraform create servers on your behalf
- **`ssh_key_id`**: This tells DigitalOcean which key to install on the server so you can log in
- **`droplet_size`**: Bigger = more expensive but faster. For Rails, you need at least 2GB RAM
- **`droplet_region`**: Choose the region closest to your users for faster response times

### 2.3 Initialize Terraform

**What this does**: Downloads the DigitalOcean plugin so Terraform can talk to DigitalOcean.

```bash
cd terraform
terraform init
```

**What you should see**:
```
Initializing the backend...
Initializing provider plugins...
- Finding digitalocean/digitalocean versions matching "~> 2.0"...
- Installing digitalocean/digitalocean v2.x.x...
Terraform has been successfully initialized!
```

**If you see errors**:
- **"No such file or directory"**: Make sure you're in the `terraform` directory
- **"Provider not found"**: Check your internet connection, Terraform needs to download plugins

### 2.4 Review What Terraform Will Create

**What this does**: Shows you exactly what Terraform will create WITHOUT actually creating it. This is a "dry run".

```bash
terraform plan
```

**What you should see**:
```
Plan: 1 to add, 0 to change, 0 to destroy.

  # digitalocean_droplet.curated will be created
  + resource "digitalocean_droplet" "curated" {
      + name   = "curated-prod"
      + region = "nyc1"
      + size   = "s-2vcpu-4gb"
      ...
    }

Plan: 1 to add.
```

**Understanding the output**:
- **"Plan: 1 to add"**: Terraform will create 1 new resource (your server)
- The `+` signs show what will be created
- Review this carefully to make sure everything looks correct

**Common issues**:
- **"Missing required argument"**: Check your `terraform.tfvars` file has all required variables
- **"Invalid token"**: Your `do_token` is wrong - get a new one from DigitalOcean
- **"SSH key not found"**: Your `ssh_key_id` is wrong - check it in DigitalOcean dashboard

### 2.5 Create the Server

**What this does**: Actually creates the server on DigitalOcean. This takes 1-2 minutes.

```bash
terraform apply
```

**What will happen**:
1. Terraform shows you the plan again
2. Asks: `Do you want to perform these actions?`
3. Type `yes` and press Enter
4. Terraform creates the server
5. Shows you the server's IP address

**What you should see**:
```
digitalocean_droplet.curated: Creating...
digitalocean_droplet.curated: Still creating... [10s elapsed]
digitalocean_droplet.curated: Still creating... [20s elapsed]
digitalocean_droplet.curated: Creation complete after 30s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

droplet_ip = "192.0.2.1"
droplet_id = "123456789"
ssh_command = "ssh root@192.0.2.1"
```

**Important**: **Copy the `droplet_ip`** - you'll need it for the next steps!

**What just happened?**
- DigitalOcean created a new virtual server (droplet)
- Installed Ubuntu 22.04 on it
- Set up basic firewall rules
- Installed your SSH key so you can log in
- The server is now running and waiting for you!

**Cost**: You're now being charged for this server (about $0.03/hour or $24/month for the recommended size)

### 2.6 Verify You Can Access Your Server

**What this does**: Tests that you can log into your new server using SSH.

```bash
# Get the IP address (if you didn't save it)
cd terraform
DROPLET_IP=$(terraform output -raw droplet_ip)
echo "Server IP: $DROPLET_IP"

# Try to connect
ssh root@$DROPLET_IP
```

**What should happen**:
1. First time connecting, you'll see:
   ```
   The authenticity of host '192.0.2.1' can't be established.
   Are you sure you want to continue connecting (yes/no)?
   ```
   Type `yes` and press Enter

2. You should see a login prompt:
   ```
   Welcome to Ubuntu 22.04 LTS
   root@curated-prod:~#
   ```

3. **You're in!** This means your server is working and you can access it.

4. Type `exit` to disconnect:
   ```bash
   exit
   ```

**If it doesn't work**:
- **"Permission denied"**: Your SSH key isn't set up correctly - check Step 1.3
- **"Connection timed out"**: The server might still be starting (wait 1-2 minutes)
- **"Host key verification failed"**: Delete `~/.ssh/known_hosts` and try again

**What you just did**: You logged into your server for the first time! This is how you'll manage your server going forward.

---


## Step 3: Install and Configure Dokku

### 3.1 What is the Bootstrap Script?

**What it does**: The bootstrap script automatically installs and configures Dokku on your server. Instead of running 20+ commands manually, it does everything in one go.

**What it installs**:
- **Dokku**: The deployment platform itself
- **PostgreSQL**: Database for your Rails app
- **Let's Encrypt plugin**: For free SSL certificates
- **Firewall rules**: Security configuration
- **App setup**: Creates your "curated" app
- **Environment variables**: Sets up Rails configuration

### 3.2 Get Your Rails Master Key

**What is this?** Rails uses encrypted credentials to store secrets. The master key decrypts them.

**Get it**:
```bash
# Option 1: Read from file (if it exists)
cat config/master.key

# Option 2: Show from Rails (if master.key doesn't exist, this creates it)
bundle exec rails credentials:show
# Look for the line that says "master_key:" - copy that value
```

**Important**: Keep this secret! Don't commit it to Git. You'll paste it when the script asks.

### 3.3 Run the Bootstrap Script

**From your project root** (not the terraform directory):

```bash
# Make sure you're in the project root
cd /path/to/curated.www

# Get your server IP (if you don't have it)
cd terraform
DROPLET_IP=$(terraform output -raw droplet_ip)
cd ..

# Run the bootstrap script
./script/bootstrap-dokku.sh $DROPLET_IP curated.cx admin@curated.cx
```

**What will happen**:
1. Script connects to your server
2. Installs Dokku (takes 2-3 minutes)
3. Configures firewall
4. Creates PostgreSQL database
5. Sets up your app
6. **Prompts you for RAILS_MASTER_KEY** - paste the key you got in step 3.2
7. Configures domains
8. Sets up SSL preparation
9. Creates storage volumes

**What you should see**:
```
🚀 Bootstrapping Dokku on DigitalOcean droplet...
Server IP: 192.0.2.1
App Domain: curated.cx
Admin Email: admin@curated.cx

Step 1: Installing Dokku...
✓ Dokku installed

Step 2: Configuring firewall...
✓ Firewall configured

Step 3: Creating Dokku app 'curated'...
✓ App created

Step 4: Installing PostgreSQL plugin...
✓ PostgreSQL plugin installed

Step 5: Creating PostgreSQL database...
✓ PostgreSQL database created and linked

Step 6: Setting up environment variables...
Enter your RAILS_MASTER_KEY (from config/master.key or rails credentials:show):
[Paste your key here and press Enter]

✓ Environment variables set

... (more steps)

✅ Dokku bootstrap complete!
```

**If something fails**:
- **"Permission denied"**: Make sure your SSH key is working (test with `ssh root@$DROPLET_IP`)
- **"Connection refused"**: Server might still be starting - wait 2 minutes and try again
- **"Command not found"**: Make sure the script is executable: `chmod +x script/bootstrap-dokku.sh`

### 3.4 Verify Dokku Installation

**What this does**: Confirms Dokku is installed and working correctly.

```bash
# Connect to your server
ssh root@$DROPLET_IP

# Check Dokku version
dokku version
# Should show: 0.33.3 or similar

# List apps (should show "curated")
dokku apps:list
# Should show: curated

# Exit
exit
```

**What you just verified**:
- ✅ Dokku is installed
- ✅ Your "curated" app exists
- ✅ You can run Dokku commands

**If `dokku version` doesn't work**:
- The bootstrap script might have failed
- Try running it again: `./script/bootstrap-dokku.sh ...`
- Check the error messages for clues

---


## Step 4: Deploy Your Application

### 4.1 Understanding Git Remotes

**What is a Git remote?** It's a location where you can push your code. You probably already have `origin` (GitHub). Now we're adding `dokku` (your server).

**How it works**:
- You push code to `dokku` remote
- Dokku automatically builds and deploys your app
- It's like `git push origin main` but instead of GitHub, it goes to your server

### 4.2 Add Dokku as a Git Remote

```bash
# Get your server IP (if you don't have it saved)
cd terraform
DROPLET_IP=$(terraform output -raw droplet_ip)
cd ..

# Add Dokku remote
git remote add dokku dokku@$DROPLET_IP:curated

# Verify it was added
git remote -v
```

**What you should see**:
```
dokku  dokku@192.0.2.1:curated (fetch)
dokku  dokku@192.0.2.1:curated (push)
origin  git@github.com:mitchellfyi/curated.cx.git (fetch)
origin  git@github.com:mitchellfyi/curated.cx.git (push)
```

**Understanding**:
- `dokku@192.0.2.1:curated` means:
  - User: `dokku` (the Dokku user on the server)
  - Server: `192.0.2.1` (your server IP)
  - App: `curated` (the app name we created)

### 4.3 Deploy Your Code

**What this does**: Pushes your code to the server, builds your app, and starts it running.

```bash
# Make sure you're on the branch you want to deploy (usually main)
git checkout main

# Push to Dokku (this triggers the deployment)
git push dokku main
```

**What will happen** (this takes 5-10 minutes the first time):

1. **Pushing code**: Your code is uploaded to the server
2. **Building**: Dokku detects it's a Rails app and:
   - Installs Ruby
   - Runs `bundle install` (installs gems)
   - Runs `yarn install` (installs JavaScript packages)
   - Precompiles assets
   - Builds your Docker image
3. **Starting**: Your app starts running
4. **Ready**: Your app is live!

**What you should see**:
```
Enumerating objects: 1234, done.
Counting objects: 100% (1234/1234), done.
...
-----> Building on the fly...
-----> Ruby app detected
-----> Installing bundler 2.x
-----> Installing dependencies using bundler
...
-----> Detecting rake tasks
-----> Releasing curated...
-----> Deploying curated...
-----> App Procfile file found
-----> DOKKU_SCALE file found
-----> Running pre-flight checks
-----> App deployed successfully!
```

**If deployment fails**:
- **"Permission denied"**: Your SSH key might not be authorized - check Step 1.3
- **"Build failed"**: Check the error message - usually a missing dependency or compilation error
- **"Out of memory"**: Your server might be too small - try a larger droplet size

### 4.4 Monitor Deployment

**Watch the logs in real-time** (in a separate terminal):

```bash
ssh root@$DROPLET_IP 'dokku logs curated --tail'
```

**What you'll see**: Real-time logs from your app. This is useful for debugging.

**Press Ctrl+C** to stop watching logs.

### 4.5 Run Database Migrations

**What this does**: Creates all the database tables your app needs.

```bash
# Run migrations
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate'
```

**What you should see**:
```
== 20250927140745 CreateTenants: migrating ====================================
-- create_table(:tenants)
   -> 0.0123s
== 20250927140745 CreateTenants: migrated (0.0125s) ===========================

== 20250927140999 CreateSites: migrating =====================================
...
```

**If migrations fail**:
- **"Connection refused"**: Database might not be ready - wait 30 seconds and try again
- **"Table already exists"**: Migrations already ran - this is OK
- **"Migration error"**: Check the error message for the specific issue

**For multi-database setup** (if you have multiple databases):
```bash
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate:all'
```

---


## Step 5: Set Up SSL/TLS (HTTPS)

### 5.1 What is SSL/TLS?

**What it is**: SSL/TLS encrypts the connection between users and your website. This is what makes the lock icon appear in browsers.

**Why you need it**:
- **Security**: Protects user data
- **Trust**: Users expect HTTPS
- **SEO**: Google favors HTTPS sites
- **Required**: Many features (like geolocation) require HTTPS

**Let's Encrypt**: A free service that provides SSL certificates. Dokku can automatically get and renew them for you.

### 5.2 Point Your Domain to Your Server

**Before enabling SSL, you need to point your domain to your server.**

**What this means**: When someone types `curated.cx` in their browser, DNS tells them to go to your server's IP address.

**How to do it** (varies by domain registrar):

1. **Get your server IP**:
   ```bash
   cd terraform
   terraform output droplet_ip
   # Example output: 192.0.2.1
   ```

2. **Log into your domain registrar** (where you bought the domain):
   - GoDaddy, Namecheap, Cloudflare, etc.

3. **Find DNS settings**:
   - Look for "DNS Management" or "DNS Settings"
   - Find "A Records" or "DNS Records"

4. **Add/Update A records**:
   - **Type**: A
   - **Name**: `@` (or leave blank, means root domain)
   - **Value**: `192.0.2.1` (your server IP)
   - **TTL**: 3600 (or default)

   - **Type**: A
   - **Name**: `www`
   - **Value**: `192.0.2.1` (same IP)
   - **TTL**: 3600

5. **Wait for DNS propagation** (5 minutes to 48 hours, usually 10-30 minutes):
   ```bash
   # Check if DNS is working
   dig curated.cx
   # Look for "A" record - should show your server IP

   # Or use nslookup
   nslookup curated.cx
   ```

**Important**: SSL won't work until DNS is pointing to your server!

### 5.3 Verify Domains Before SSL

**Before enabling SSL, verify your domains are correct**:

```bash
# Check current domains
ssh root@$DROPLET_IP 'dokku domains:report curated'
```

**What you should see**:
```
=====> curated domains information
       Domains app vhosts:            curated.cx www.curated.cx
```

**If you see invalid domains** (like `curated.curated-cx` or other malformed names):
```bash
# Remove invalid domain
ssh root@$DROPLET_IP 'dokku domains:remove curated invalid-domain-name'

# Add correct domains if missing
ssh root@$DROPLET_IP 'dokku domains:add curated curated.cx'
ssh root@$DROPLET_IP 'dokku domains:add curated www.curated.cx'
```

### 5.4 Enable Let's Encrypt SSL

**Once DNS is working and domains are correct, enable SSL**:

```bash
# Step 1: Set email address for Let's Encrypt notifications
ssh root@$DROPLET_IP 'dokku letsencrypt:set curated email admin@curated.cx'

# Step 2: Enable SSL (this gets the certificate)
ssh root@$DROPLET_IP 'dokku letsencrypt:enable curated'
```

**What will happen**:
1. Dokku contacts Let's Encrypt
2. Let's Encrypt verifies you own the domain (checks DNS)
3. Certificate is issued (takes 1-2 minutes)
4. HTTPS is enabled

**What you should see**:
```
=====> Enabling letsencrypt for curated
-----> Enabling ACME proxy for curated...
-----> Getting letsencrypt certificate for curated via HTTP-01
       - Domain 'curated.cx'
       - Domain 'www.curated.cx'
-----> Certificate retrieved successfully.
-----> Installing let's encrypt certificates
-----> Done
```

**If it fails**:
- **"Cannot request certificate without email"**: Run the `letsencrypt:set email` command first
- **"Invalid identifiers"**: You have invalid domain names - check and fix with `dokku domains:report`
- **"DNS not pointing to server"**: Wait longer for DNS propagation, then try again
- **"Rate limit exceeded"**: You've requested too many certificates - wait 1 hour
- **"Domain validation failed"**: Check your DNS settings

### 5.5 Enable Auto-Renewal

**What this does**: Automatically renews your SSL certificate before it expires (certificates last 90 days).

```bash
# Enable auto-renewal cron job
ssh root@$DROPLET_IP 'dokku letsencrypt:cron-job --add'
```

**What you should see**:
```
-----> Added cron job to renew certificates
```

**This is important!** Without auto-renewal, your SSL certificate will expire and your site will show security warnings.

### 5.6 Verify SSL is Working

**Check certificate status**:
```bash
ssh root@$DROPLET_IP 'dokku letsencrypt:list'
```

**Test HTTPS**:
```bash
# Test your site with HTTPS
curl -I https://curated.cx/up

# Should see:
# HTTP/2 200
# (and no SSL errors)
```

**Test in browser**:
1. Go to `https://curated.cx`
2. You should see a lock icon 🔒 in the address bar
3. Click the lock to see certificate details

**If HTTPS doesn't work**:
- **"Connection refused"**: Your app might not be running - check `dokku ps:report curated`
- **"Certificate error"**: DNS might not be fully propagated - wait and try again
- **"404 Not Found"**: Your app is running but the route doesn't exist - this is OK, just means `/up` isn't defined

---


## Step 6: Configure Recurring Tasks

### 6.1 Understanding Background Jobs

**What are background jobs?** Tasks that run automatically on a schedule, like:
- Sending daily email digests
- Cleaning up old data
- Fetching news from APIs
- Generating reports

**How it works in this app**: We use **Solid Queue** which runs background jobs. It's built into Rails and runs automatically - no extra setup needed!

### 6.2 Verify Recurring Tasks

**Check if recurring tasks are configured**:

```bash
# List all recurring tasks
ssh root@$DROPLET_IP 'dokku run curated rails runner "puts SolidQueue::RecurringTask.all.map(&:name)"'
```

**What you should see**:
```
heartbeat
```

**This means**: The `HeartbeatJob` is configured to run every 5 minutes (as defined in `config/recurring.yml`).

**If you see nothing**: That's OK - it means no recurring tasks are configured yet. You can add them later in `config/recurring.yml`.

### 6.3 (Optional) Dokku Cron for Custom Tasks

**When to use this**: If you need to run tasks that aren't Rails jobs, or need more control over scheduling.

**Install the cron plugin**:
```bash
ssh root@$DROPLET_IP 'sudo dokku plugin:install https://github.com/dokku/dokku-cron.git'
```

**Add a cron job** (example - runs at 3 AM every day):
```bash
ssh root@$DROPLET_IP 'dokku cron:add curated "0 3 * * * dokku run curated rails runner \"SomeTask.perform\"'
```

**Understanding cron syntax**: `0 3 * * *` means:
- `0` = minute (0th minute)
- `3` = hour (3 AM)
- `*` = day of month (every day)
- `*` = month (every month)
- `*` = day of week (every day)

**For most cases, you don't need this** - Solid Queue handles recurring tasks automatically!

---


## Step 7: Set Up Automatic Deployments (GitHub Actions)

### 7.1 What is Automatic Deployment?

**What it does**: Instead of manually running `git push dokku main` every time, GitHub Actions automatically deploys your app whenever you push to the `main` branch.

**Benefits**:
- **Automatic**: Deploy happens without you doing anything
- **Consistent**: Same process every time
- **Trackable**: See deployment history in GitHub
- **Safe**: Can require CI to pass before deploying

**How it works**:
1. You push code to GitHub (`git push origin main`)
2. GitHub Actions detects the push
3. Runs your deployment workflow
4. Pushes code to Dokku server
5. Dokku builds and deploys your app

### 7.2 Create GitHub Secrets (Automated)

**The easy way - use the automated script:**

```bash
./script/setup-github-deploy.sh <your-server-ip>
```

This script automatically:
1. Generates an SSH deploy key
2. Adds it to the dokku user on your server
3. Sets `DOKKU_HOST` and `DOKKU_SSH_PRIVATE_KEY` secrets in GitHub
4. Tests the connection

**That's it!** You're done. Skip to section 7.4 to test.

---


### 7.2b Manual Setup (If Needed)

If you prefer to set up secrets manually:

**What are GitHub Secrets?** Secure storage for sensitive information like passwords, API keys, and SSH keys. They're encrypted and only accessible to your GitHub Actions workflows.

**You need to add these secrets**:

1. **Go to your GitHub repository**
   - Navigate to: `https://github.com/mitchellfyi/curated.cx`
   - Click **Settings** → **Secrets and variables** → **Actions**

2. **Add `DOKKU_HOST` secret**:
   - Click **New repository secret**
   - **Name**: `DOKKU_HOST`
   - **Value**: Your server IP address (e.g., `192.0.2.1`)
   - Click **Add secret**

3. **Add `DOKKU_SSH_PRIVATE_KEY` secret**:
   - **Generate a dedicated SSH key for deployments** (recommended):
     ```bash
     # Generate a new SSH key specifically for GitHub Actions
     ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/dokku_deploy

     # This creates two files:
     # ~/.ssh/dokku_deploy (private key - you'll add this to GitHub)
     # ~/.ssh/dokku_deploy.pub (public key - you'll add this to your server)
     ```

   - **Add the public key to your Dokku server**:
     ```bash
     # Get your server IP
     cd terraform
     DROPLET_IP=$(terraform output -raw droplet_ip)

     # Add the key to the dokku user (IMPORTANT: not root!)
     cat ~/.ssh/dokku_deploy.pub | ssh root@$DROPLET_IP "
       mkdir -p /home/dokku/.ssh
       cat >> /home/dokku/.ssh/authorized_keys
       chmod 600 /home/dokku/.ssh/authorized_keys
       chmod 700 /home/dokku/.ssh
       chown -R dokku:dokku /home/dokku/.ssh
     "
     ```

     **Important**: The deployment workflow connects as the `dokku` user, not `root`. Make sure the SSH key is added to the `dokku` user's `~/.ssh/authorized_keys` file.

   - **Add the private key to GitHub**:
     ```bash
     # Display the private key (copy the entire output)
     cat ~/.ssh/dokku_deploy
     ```

   - In GitHub:
     - Click **New repository secret**
     - **Name**: `DOKKU_SSH_PRIVATE_KEY`
     - **Value**: Paste the entire private key (starts with `-----BEGIN OPENSSH PRIVATE KEY-----`)
     - Click **Add secret**

**Why a separate SSH key?**
- **Security**: If GitHub Actions is compromised, you can revoke just this key
- **Tracking**: You know which deployments came from GitHub Actions
- **Best practice**: Separate keys for different purposes

### 7.3 Verify the Deployment Workflow Exists

**The workflow file is already created** at `.github/workflows/deploy.yml`. Let's verify it exists:

```bash
# Check if the file exists
cat .github/workflows/deploy.yml
```

**What the workflow does**:
1. Triggers on push to `main` branch
2. Sets up SSH using your private key
3. Adds Dokku server to known hosts
4. Pushes code to Dokku
5. Runs database migrations
6. Restarts the app
7. Verifies deployment

### 7.4 Test Automatic Deployment

**Test the deployment workflow**:

1. **Make a small change** (or just push your current code):
   ```bash
   # Make a small change
   echo "# Test deployment" >> README.md

   # Commit and push
   git add README.md
   git commit -m "Test automatic deployment"
   git push origin main
   ```

2. **Watch the deployment**:
   - Go to your GitHub repository
   - Click **Actions** tab
   - You should see "Deploy to Dokku" workflow running
   - Click on it to see the progress

3. **What you should see**:
   - ✅ Green checkmarks for each step
   - "Deploy to Dokku" step shows git push output
   - "Run database migrations" step shows migration output
   - "Verify deployment" step shows app status

**If deployment fails**:
- **"Permission denied"**: Check your SSH key is correct in GitHub secrets
- **"Host key verification failed"**: The workflow adds the host automatically, but if it fails, check the known_hosts step
- **"Connection refused"**: Check your `DOKKU_HOST` secret is correct
- **"App not found"**: Make sure you ran the bootstrap script and created the app

### 7.5 Understanding the Deployment Workflow

**Let's break down what happens**:

```yaml
# This triggers on push to main branch
on:
  push:
    branches: [ main ]

# Sets up SSH so GitHub Actions can connect to your server
- name: Setup SSH
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.DOKKU_SSH_PRIVATE_KEY }}

# Adds your server to known hosts (prevents SSH warnings)
- name: Add Dokku to known hosts
  run: |
    ssh-keyscan -H ${{ secrets.DOKKU_HOST }} >> ~/.ssh/known_hosts

# Pushes your code to Dokku (this triggers the build)
- name: Deploy to Dokku
  run: |
    git remote add dokku dokku@${{ secrets.DOKKU_HOST }}:curated
    git push dokku HEAD:main --force

# Runs migrations (updates database schema)
- name: Run database migrations
  run: |
    ssh dokku@${{ secrets.DOKKU_HOST }} run curated rails db:migrate

# Restarts the app (picks up new code)
- name: Restart application
  run: |
    ssh dokku@${{ secrets.DOKKU_HOST }} ps:restart curated
```

**Timeline of a deployment**:
1. **0:00** - You push to GitHub
2. **0:05** - GitHub Actions starts
3. **0:10** - SSH connection established
4. **0:15** - Code pushed to Dokku
5. **2:00** - Dokku builds your app (installs gems, compiles assets)
6. **2:30** - App starts running
7. **2:35** - Migrations run
8. **2:40** - App restarted
9. **2:45** - Deployment complete!

### 7.6 Optional: Require CI to Pass Before Deploying

**By default, the deployment runs independently of CI**. If you want to only deploy when CI passes:

1. **Edit `.github/workflows/deploy.yml`**
2. **Uncomment and modify the `if` line**:
   ```yaml
   jobs:
     deploy:
       name: Deploy to Production
       runs-on: ubuntu-latest
       # Only deploy if CI passes (uncomment to enable)
       # if: github.event_name == 'push' && github.ref == 'refs/heads/main'
   ```

**Note**: Your CI workflow (`.github/workflows/ci.yml`) already runs on push to main. The deployment workflow runs independently by default, but you can add conditions to make it wait for CI if needed.

### 7.7 Manual Deployment Trigger

**You can also trigger deployments manually** (useful for testing):

1. Go to **Actions** tab in GitHub
2. Click **Deploy to Dokku** workflow
3. Click **Run workflow** button
4. Select branch (usually `main`)
5. Click **Run workflow**

This is useful if:
- You want to redeploy without pushing code
- You want to test the deployment process
- You need to deploy a specific branch

---


## Step 8: Post-Deployment Configuration

### 8.1 Verify Application is Working

```bash
# Health check
curl https://curated.cx/up

# Check logs
ssh root@$DROPLET_IP 'dokku logs curated --tail 50'
```

### 8.2 Set Additional Environment Variables

```bash
# Set any additional env vars
ssh root@$DROPLET_IP 'dokku config:set curated VARIABLE_NAME=value'

# View all config
ssh root@$DROPLET_IP 'dokku config curated'
```

### 8.3 Seed Database (Optional)

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
# Verify domains first
ssh root@$DROPLET_IP 'dokku domains:report curated'

# Set email for Let's Encrypt
ssh root@$DROPLET_IP 'dokku letsencrypt:set curated email admin@curated.cx'

# Enable SSL
ssh root@$DROPLET_IP 'dokku letsencrypt:enable curated'

# Enable auto-renewal
ssh root@$DROPLET_IP 'dokku letsencrypt:cron-job --add'
```

---


## Troubleshooting

### Common Issues

#### App Won't Start

**Symptoms**: App deployed but returns 502 Bad Gateway or connection refused

**Debug steps**:

```bash
# 1. Check recent logs for errors
ssh root@$DROPLET_IP 'dokku logs curated --tail 100'

# 2. Check if the app process is running
ssh root@$DROPLET_IP 'dokku ps:report curated'

# 3. Check configuration
ssh root@$DROPLET_IP 'dokku config curated'

# 4. Verify RAILS_MASTER_KEY is set (critical!)
ssh root@$DROPLET_IP 'dokku config:get curated RAILS_MASTER_KEY'
# Should show a long string of characters, not empty

# 5. Check resource limits (might be out of memory)
ssh root@$DROPLET_IP 'dokku resource:report curated'

# 6. Restart the app
ssh root@$DROPLET_IP 'dokku ps:restart curated'
```

**Common causes**:
- **Missing RAILS_MASTER_KEY**: App can't decrypt credentials
- **Out of memory**: Server too small, upgrade droplet size
- **Database connection failed**: Check DATABASE_URL is set
- **Build failed**: Check deployment logs for compilation errors

#### Database Connection Issues

**Symptoms**: App starts but shows database errors, migrations fail

**Debug steps**:

```bash
# 1. Check if database exists and is running
ssh root@$DROPLET_IP 'dokku postgres:info curated-db'
# Should show database name, size, status

# 2. Verify DATABASE_URL is set correctly
ssh root@$DROPLET_IP 'dokku config:get curated DATABASE_URL'
# Should show: postgres://user:password@host:port/dbname

# 3. Test database connection
ssh root@$DROPLET_IP 'dokku run curated rails db:version'
# Should show current database version, not an error

# 4. Check database logs
ssh root@$DROPLET_IP 'dokku postgres:logs curated-db --tail 50'
```

**Common causes**:
- **Database not linked**: Run `dokku postgres:link curated-db curated`
- **Wrong DATABASE_URL**: Check it matches the database info
- **Database full**: Check disk space with `df -h`
- **Connection limit**: Too many connections (unlikely on small app)

#### SSL Certificate Issues

**Symptoms**: Browser shows "Not Secure" or certificate errors, HTTPS doesn't work

**Debug steps**:

```bash
# 1. Check certificate status
ssh root@$DROPLET_IP 'dokku letsencrypt:list'
# Should show certificate expiration date

# 2. Check if DNS is pointing to your server
dig curated.cx
# Look for "A" record - should match your server IP

# 3. Check if domains are configured correctly in Dokku
ssh root@$DROPLET_IP 'dokku domains:report curated'
# Should list curated.cx and www.curated.cx
# If you see invalid domains like 'curated.curated-cx', remove them:
ssh root@$DROPLET_IP 'dokku domains:remove curated curated.curated-cx'

# 4. Verify email is set for Let's Encrypt
ssh root@$DROPLET_IP 'dokku letsencrypt:set curated email admin@curated.cx'

# 5. Force certificate renewal (if certificate exists but expired)
ssh root@$DROPLET_IP 'dokku letsencrypt:enable curated'
```

**Common causes**:
- **Invalid domain names**: Check for malformed domains (e.g., `appname.domain-name` pattern) and remove them
- **Missing email**: Let's Encrypt requires an email - set it with `letsencrypt:set email`
- **DNS not pointing to server**: Update DNS records, wait for propagation
- **Certificate expired**: Auto-renewal might have failed, manually renew
- **Rate limit**: Too many certificate requests, wait 1 hour
- **Domain not added**: Run `dokku domains:add curated curated.cx`

#### Deployment Fails


**Debug steps**:

```bash
# 1. Check build logs (most important!)
ssh root@$DROPLET_IP 'dokku logs curated --tail 200'
# Look for error messages - they'll tell you what's wrong

# 2. Check if previous deployment is blocking
ssh root@$DROPLET_IP 'dokku ps:report curated'
# If app is running, try restarting first

# 3. Check resource limits (might be out of memory during build)
ssh root@$DROPLET_IP 'dokku resource:report curated'

# 4. Check disk space (builds need space)
ssh root@$DROPLET_IP 'df -h'
# Should have at least 2GB free

# 5. Try rebuilding from scratch
ssh root@$DROPLET_IP 'dokku ps:rebuild curated'
```

**Common causes**:
- **Build timeout**: Server too slow, upgrade droplet size
- **Out of memory**: Build process needs more RAM
- **Missing dependencies**: Check Gemfile or package.json
- **Compilation errors**: Ruby gems or Node packages failing to compile
- **Git issues**: Make sure you're pushing the right branch

### Useful Debug Commands

**These commands help you understand what's happening**:

```bash
# Enter app container (like SSH into your app)
ssh root@$DROPLET_IP 'dokku enter curated'
# Now you're inside the container - you can run commands directly
# Type 'exit' to leave

# Run one-off Rails commands
ssh root@$DROPLET_IP 'dokku run curated rails runner "puts Rails.env"'
# Useful for testing database connections, running scripts, etc.

# Open Rails console
ssh root@$DROPLET_IP 'dokku run curated rails console'
# Interactive console - you can query the database, test code, etc.

# Check Dokku version
ssh root@$DROPLET_IP 'dokku version'

# List all apps on the server
ssh root@$DROPLET_IP 'dokku apps:list'

# Check which plugins are installed
ssh root@$DROPLET_IP 'dokku plugin:list'

# View all environment variables (secrets hidden)
ssh root@$DROPLET_IP 'dokku config curated'

# Check app resource usage
ssh root@$DROPLET_IP 'dokku resource:report curated'

# View app info
ssh root@$DROPLET_IP 'dokku apps:info curated'
```

### Getting Help

**If you're stuck**:

1. **Check the logs first**: `dokku logs curated --tail 100`
2. **Search error messages**: Copy the error and search Google/Dokku docs
3. **Dokku documentation**: https://dokku.com/docs/
4. **DigitalOcean guides**: https://www.digitalocean.com/community/tags/dokku
5. **Terraform docs**: https://www.terraform.io/docs

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


## Quick Reference

### Maintenance Script (Recommended)

Use the maintenance script for common operations:

```bash
# View logs
./script/dokku-maintenance.sh logs

# Rails console
./script/dokku-maintenance.sh console

# Database console
./script/dokku-maintenance.sh dbconsole

# Run migrations
./script/dokku-maintenance.sh migrate

# Restart app
./script/dokku-maintenance.sh restart

# Check status
./script/dokku-maintenance.sh status

# Create database backup
./script/dokku-maintenance.sh backup

# Restore from backup
./script/dokku-maintenance.sh restore backup-file.dump

# Rollback to previous release
./script/dokku-maintenance.sh rollback

# SSH into server
./script/dokku-maintenance.sh ssh

# Run any command
./script/dokku-maintenance.sh run rails db:seed

# See all commands
./script/dokku-maintenance.sh help
```

### Automation Scripts

| Script | Purpose |
|--------|---------|
| `./script/deploy-full-setup.sh` | **One-command full setup** - does everything |
| `./script/setup-github-deploy.sh <ip>` | Configure GitHub Actions auto-deploy |
| `./script/bootstrap-dokku.sh <ip> <domain> <email>` | Install Dokku on fresh server |
| `./script/dokku-maintenance.sh <cmd>` | Common maintenance operations |

### Essential Commands (Manual)

```bash
# Get server IP
cd terraform && terraform output droplet_ip

# Deploy new code (automatic via GitHub Actions - recommended)
git push origin main  # This triggers automatic deployment

# Deploy new code (manual - if automatic deployment isn't set up)
git push dokku main

# View logs
ssh root@$DROPLET_IP 'dokku logs curated --tail'

# Run migrations
ssh root@$DROPLET_IP 'dokku run curated rails db:migrate'

# Restart app
ssh root@$DROPLET_IP 'dokku ps:restart curated'

# Check app status
ssh root@$DROPLET_IP 'dokku ps:report curated'

# Set environment variable
ssh root@$DROPLET_IP 'dokku config:set curated KEY=value'

# Open Rails console
ssh root@$DROPLET_IP 'dokku run curated rails console'
```

### Cost Breakdown

**Monthly costs** (approximate):
- **Droplet (s-2vcpu-4gb)**: $24/month
- **Domain**: $10-15/year (one-time or annual)
- **SSL Certificate**: Free (Let's Encrypt)
- **Total**: ~$25/month

**Scaling costs**:
- **s-4vcpu-8gb**: $48/month (better performance)
- **Separate database**: +$24/month (if needed)
- **Load balancer**: +$12/month (if needed)

### Security Checklist

- ✅ SSH key authentication (no passwords)
- ✅ Firewall configured (only HTTP, HTTPS, SSH)
- ✅ SSL certificates enabled
- ✅ Auto-renewal enabled
- ✅ Regular backups (set up automated backups)
- ✅ Keep Dokku updated: `dokku update`
- ✅ Keep system updated: `apt update && apt upgrade`

### Next Steps After Deployment

1. **Set up monitoring**: Use Uptime Robot or Pingdom to monitor your site
2. **Configure backups**: Set up automated PostgreSQL backups
3. **Set up error tracking**: Add Sentry or similar for error monitoring
4. **Configure CDN**: Add Cloudflare for faster static asset delivery
5. **Set up logging**: Configure centralized logging (optional)
6. **Set up automatic domain sync**: See section below

---


## Automatic Domain Management

### Overview

This feature automatically synchronizes domains between your Rails application and Dokku. When you add or remove domains/tenants in Rails, they are automatically configured in Dokku with Let's Encrypt SSL certificates.

### Components

1. **Rails rake task** (`lib/tasks/dokku.rake`): Outputs active domains as JSON
2. **Sync script** (`script/dokku/sync-domains.sh`): Host-side script that syncs domains

### Setup on Dokku Host

1. **Copy the sync script to your server**:
   ```bash
   scp script/dokku/sync-domains.sh root@$DROPLET_IP:/usr/local/bin/
   ssh root@$DROPLET_IP 'chmod +x /usr/local/bin/sync-domains.sh'
   ```

2. **Test the sync script**:
   ```bash
   ssh root@$DROPLET_IP '/usr/local/bin/sync-domains.sh curated'
   ```

3. **Set up automatic sync via cron** (runs every 5 minutes):
   ```bash
   ssh root@$DROPLET_IP 'echo "*/5 * * * * root /usr/local/bin/sync-domains.sh curated >> /var/log/domain-sync.log 2>&1" > /etc/cron.d/domain-sync'
   ```

4. **Or set up as post-deploy hook**:
   ```bash
   ssh root@$DROPLET_IP 'mkdir -p /var/lib/dokku/plugins/enabled/domain-sync'
   ssh root@$DROPLET_IP 'cat > /var/lib/dokku/plugins/enabled/domain-sync/post-deploy << "EOF"
#!/usr/bin/env bash
set -eo pipefail
APP="$1"
if [ "$APP" = "curated" ]; then
    /usr/local/bin/sync-domains.sh curated
fi
EOF
chmod +x /var/lib/dokku/plugins/enabled/domain-sync/post-deploy'
   ```

### How It Works

1. The Rails app tracks domains in the `domains` table (with status `active`) and tenant hostnames in the `tenants` table
2. The `dokku:domains` rake task outputs all required domains as JSON
3. The sync script:
   - Fetches required domains from Rails
   - Compares with current Dokku domains
   - Adds missing domains
   - Removes stale domains (except the default Dokku domain)
   - Re-enables Let's Encrypt if changes were made

### Manual Domain Sync

To manually trigger a domain sync:
```bash
ssh root@$DROPLET_IP '/usr/local/bin/sync-domains.sh curated'
```

### Viewing Sync Status

```bash
# Check current domains in Dokku
ssh root@$DROPLET_IP 'dokku domains:report curated'

# Check what domains Rails expects
ssh root@$DROPLET_IP 'dokku run curated ./bin/rails dokku:domains'

# Check domain sync logs
ssh root@$DROPLET_IP 'tail -100 /var/log/domain-sync.log'
```

### Adding a New Tenant/Domain

1. Add the tenant or domain in Rails (via admin panel or seeds)
2. Wait for the cron to run (up to 5 minutes) or trigger manually
3. The domain will be automatically added to Dokku with SSL

### Removing a Tenant/Domain

1. Set the tenant status to `disabled` or domain status to non-active
2. The sync script will remove it from Dokku on next run

---


*Last Updated: 2026-01-25*
*Written for beginners new to Terraform, DigitalOcean, and Dokku*