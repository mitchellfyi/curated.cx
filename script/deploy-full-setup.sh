#!/bin/bash
set -euo pipefail

# FULL AUTOMATED DEPLOYMENT SETUP
# This is the one-command script that does EVERYTHING
# Usage: ./script/deploy-full-setup.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${MAGENTA}"
cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║     ██████╗██╗   ██╗██████╗  █████╗ ████████╗███████╗██████╗              ║
║    ██╔════╝██║   ██║██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗             ║
║    ██║     ██║   ██║██████╔╝███████║   ██║   █████╗  ██║  ██║             ║
║    ██║     ██║   ██║██╔══██╗██╔══██║   ██║   ██╔══╝  ██║  ██║             ║
║    ╚██████╗╚██████╔╝██║  ██║██║  ██║   ██║   ███████╗██████╔╝             ║
║     ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝              ║
║                                                                           ║
║                    Full Automated Deployment Setup                        ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo ""

# Function to display steps
step() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}   $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Check prerequisites
step "Step 1: Checking Prerequisites"

MISSING_PREREQS=0

echo -n "Checking Terraform... "
if command -v terraform &> /dev/null; then
  echo -e "${GREEN}✓ Found ($(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1))${NC}"
else
  echo -e "${RED}✗ Not found${NC}"
  echo "  Install: brew install terraform"
  MISSING_PREREQS=1
fi

echo -n "Checking GitHub CLI... "
if command -v gh &> /dev/null; then
  echo -e "${GREEN}✓ Found${NC}"
  if gh auth status &> /dev/null; then
    echo -e "  ${GREEN}✓ Authenticated${NC}"
  else
    echo -e "  ${RED}✗ Not authenticated. Run: gh auth login${NC}"
    MISSING_PREREQS=1
  fi
else
  echo -e "${RED}✗ Not found${NC}"
  echo "  Install: brew install gh"
  MISSING_PREREQS=1
fi

echo -n "Checking SSH... "
if command -v ssh &> /dev/null; then
  echo -e "${GREEN}✓ Found${NC}"
else
  echo -e "${RED}✗ Not found${NC}"
  MISSING_PREREQS=1
fi

echo -n "Checking Git... "
if command -v git &> /dev/null; then
  echo -e "${GREEN}✓ Found${NC}"
else
  echo -e "${RED}✗ Not found${NC}"
  MISSING_PREREQS=1
fi

echo -n "Checking jq... "
if command -v jq &> /dev/null; then
  echo -e "${GREEN}✓ Found${NC}"
else
  echo -e "${YELLOW}⚠ Not found (optional, but recommended)${NC}"
  echo "  Install: brew install jq"
fi

if [[ $MISSING_PREREQS -eq 1 ]]; then
  echo ""
  echo -e "${RED}Please install missing prerequisites and try again.${NC}"
  exit 1
fi

# Check for terraform directory
if [[ ! -d "terraform" ]]; then
  echo -e "${RED}Error: terraform directory not found${NC}"
  echo "Make sure you're running this from the project root"
  exit 1
fi

# Check for terraform.tfvars
if [[ ! -f "terraform/terraform.tfvars" ]]; then
  echo ""
  echo -e "${YELLOW}terraform/terraform.tfvars not found${NC}"

  if [[ -f "terraform/terraform.tfvars.example" ]]; then
    echo "Creating from example..."
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars

    echo ""
    echo -e "${YELLOW}Please edit terraform/terraform.tfvars with your values:${NC}"
    echo ""
    cat terraform/terraform.tfvars
    echo ""
    echo -e "${YELLOW}Required:${NC}"
    echo "  - do_token: Your DigitalOcean API token"
    echo "  - ssh_fingerprint: Your SSH key fingerprint from DigitalOcean"
    echo ""
    read -p "Press Enter when you've updated terraform.tfvars..."
  else
    echo -e "${RED}terraform/terraform.tfvars.example not found${NC}"
    exit 1
  fi
fi

step "Step 2: Collecting Configuration"

# Default values
DEFAULT_DOMAIN="curated.cx"
DEFAULT_EMAIL="admin@curated.cx"

read -p "App domain [$DEFAULT_DOMAIN]: " APP_DOMAIN
APP_DOMAIN="${APP_DOMAIN:-$DEFAULT_DOMAIN}"

read -p "Admin email [$DEFAULT_EMAIL]: " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_EMAIL}"

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Domain: $APP_DOMAIN"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""

read -p "Continue with this configuration? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Aborted."
  exit 1
fi

step "Step 3: Provisioning Infrastructure with Terraform"

cd terraform

echo "Initializing Terraform..."
terraform init

echo ""
echo "Planning infrastructure..."
terraform plan -out=tfplan

echo ""
read -p "Apply this plan? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Aborted."
  exit 1
fi

echo "Creating infrastructure..."
terraform apply tfplan

DROPLET_IP=$(terraform output -raw droplet_ip)
echo ""
echo -e "${GREEN}✓ Droplet created: $DROPLET_IP${NC}"

cd ..

step "Step 4: Waiting for Droplet to Initialize"

echo "Waiting for SSH to become available..."
MAX_WAIT=120
WAITED=0
while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$DROPLET_IP" "echo 'ready'" &> /dev/null; do
  if [[ $WAITED -ge $MAX_WAIT ]]; then
    echo -e "${RED}Timeout waiting for SSH${NC}"
    exit 1
  fi
  echo -n "."
  sleep 5
  WAITED=$((WAITED + 5))
done
echo ""
echo -e "${GREEN}✓ SSH is ready${NC}"

step "Step 5: Bootstrapping Dokku"

echo "This will install and configure Dokku on the server."
echo "You'll be asked for your RAILS_MASTER_KEY during this process."
echo ""

./script/bootstrap-dokku.sh "$DROPLET_IP" "$APP_DOMAIN" "$ADMIN_EMAIL"

step "Step 6: Setting Up GitHub Actions Deployment"

echo "This will configure automatic deployments from GitHub."
echo ""

./script/setup-github-deploy.sh "$DROPLET_IP"

step "Step 7: Initial Deployment"

echo "Would you like to deploy the app now?"
read -p "Deploy? (Y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo "Pushing to GitHub (this will trigger automatic deployment)..."
  git push origin main

  echo ""
  echo "Deployment triggered! Watching GitHub Actions..."
  echo "You can also watch at: https://github.com/$(gh repo view --json nameWithOwner -q '.nameWithOwner')/actions"
  echo ""

  # Wait a bit for deployment to complete
  echo "Waiting for deployment..."
  sleep 30

  # Enable SSL after first deployment
  echo ""
  echo "Enabling SSL certificates..."
  ssh -o StrictHostKeyChecking=no root@"$DROPLET_IP" "dokku letsencrypt:enable curated" || echo "SSL setup may require DNS to be configured first"
fi

step "Step 8: DNS Configuration"

echo -e "${YELLOW}Important: Configure your DNS${NC}"
echo ""
echo "Add these DNS records for $APP_DOMAIN:"
echo ""
echo -e "  ${BLUE}A Record:${NC}"
echo "    Name: @"
echo "    Value: $DROPLET_IP"
echo ""
echo -e "  ${BLUE}A Record (for www):${NC}"
echo "    Name: www"
echo "    Value: $DROPLET_IP"
echo ""
echo "Or if using Cloudflare/other with ALIAS support:"
echo ""
echo -e "  ${BLUE}ALIAS/ANAME Record:${NC}"
echo "    Name: @"
echo "    Value: $DROPLET_IP"
echo ""

echo -e "${GREEN}"
cat << 'COMPLETE'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                         🎉 SETUP COMPLETE! 🎉                             ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
COMPLETE
echo -e "${NC}"

echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  • Server IP: $DROPLET_IP"
echo "  • Domain: $APP_DOMAIN"
echo "  • Admin Email: $ADMIN_EMAIL"
echo ""
echo -e "${BLUE}What's automated:${NC}"
echo "  ✓ Push to main → Automatic deployment"
echo "  ✓ Database migrations run automatically"
echo "  ✓ Zero-downtime deployments"
echo "  ✓ Health checks before/after deploy"
echo "  ✓ Automatic rollback on failure"
echo "  ✓ SSL certificate auto-renewal"
echo "  ✓ Daily database backups"
echo ""
echo -e "${BLUE}To deploy changes:${NC}"
echo "  git push origin main"
echo ""
echo -e "${BLUE}Manual commands:${NC}"
echo "  View logs:        ssh root@$DROPLET_IP 'dokku logs curated --tail'"
echo "  Rails console:    ssh root@$DROPLET_IP 'dokku run curated rails console'"
echo "  Run migrations:   ssh root@$DROPLET_IP 'dokku run curated rails db:migrate'"
echo "  Restart app:      ssh root@$DROPLET_IP 'dokku ps:restart curated'"
echo ""
echo -e "${BLUE}Verify your app:${NC}"
echo "  curl https://$APP_DOMAIN/up"
echo ""
