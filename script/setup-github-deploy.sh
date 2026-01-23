#!/bin/bash
set -euo pipefail

# Automated GitHub deployment setup script
# This script sets up everything needed for automatic deployments
# Usage: ./script/setup-github-deploy.sh <server-ip>

SERVER_IP="${1:-}"

if [[ -z "$SERVER_IP" ]]; then
  echo "Usage: $0 <server-ip>"
  echo "Example: $0 192.0.2.1"
  exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   GitHub Actions Deployment Setup - Automated Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for gh CLI
if ! command -v gh &> /dev/null; then
  echo -e "${RED}❌ GitHub CLI (gh) not found${NC}"
  echo "Install it with: brew install gh"
  echo "Then authenticate: gh auth login"
  exit 1
fi
echo -e "${GREEN}✓ GitHub CLI found${NC}"

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo -e "${RED}❌ Not authenticated with GitHub CLI${NC}"
  echo "Run: gh auth login"
  exit 1
fi
echo -e "${GREEN}✓ Authenticated with GitHub${NC}"

# Check SSH access to server
echo -e "${YELLOW}Testing SSH connection to $SERVER_IP...${NC}"
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$SERVER_IP" "echo 'SSH OK'" &> /dev/null; then
  echo -e "${RED}❌ Cannot SSH to root@$SERVER_IP${NC}"
  echo "Make sure you can SSH to the server first"
  exit 1
fi
echo -e "${GREEN}✓ SSH connection successful${NC}"

# Get repo info
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [[ -z "$REPO" ]]; then
  echo -e "${RED}❌ Not in a GitHub repository${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Repository: $REPO${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 1: Generating SSH deploy key${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DEPLOY_KEY_PATH="$HOME/.ssh/dokku_deploy_$(echo $REPO | tr '/' '_')"

if [[ -f "$DEPLOY_KEY_PATH" ]]; then
  echo -e "${YELLOW}Deploy key already exists at $DEPLOY_KEY_PATH${NC}"
  read -p "Regenerate? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$DEPLOY_KEY_PATH" "$DEPLOY_KEY_PATH.pub"
  else
    echo "Using existing key"
  fi
fi

if [[ ! -f "$DEPLOY_KEY_PATH" ]]; then
  echo "Generating new ED25519 SSH key..."
  ssh-keygen -t ed25519 -C "github-actions-deploy-$REPO" -f "$DEPLOY_KEY_PATH" -N ""
  echo -e "${GREEN}✓ Deploy key generated${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 2: Adding public key to Dokku server${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Add public key to dokku user
PUBLIC_KEY=$(cat "$DEPLOY_KEY_PATH.pub")
echo "Adding deploy key to dokku user on server..."

ssh -o StrictHostKeyChecking=no root@"$SERVER_IP" bash << REMOTE_SCRIPT
# Ensure dokku user exists and has .ssh directory
mkdir -p /home/dokku/.ssh
chmod 700 /home/dokku/.ssh
chown dokku:dokku /home/dokku/.ssh

# Add the public key if not already present
PUBKEY="$PUBLIC_KEY"
if ! grep -q "\$PUBKEY" /home/dokku/.ssh/authorized_keys 2>/dev/null; then
  echo "\$PUBKEY" >> /home/dokku/.ssh/authorized_keys
  chmod 600 /home/dokku/.ssh/authorized_keys
  chown dokku:dokku /home/dokku/.ssh/authorized_keys
  echo "Key added successfully"
else
  echo "Key already exists"
fi
REMOTE_SCRIPT

echo -e "${GREEN}✓ Public key added to dokku user${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3: Setting GitHub repository secrets${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Set DOKKU_HOST secret
echo "Setting DOKKU_HOST secret..."
gh secret set DOKKU_HOST --body "$SERVER_IP"
echo -e "${GREEN}✓ DOKKU_HOST set to $SERVER_IP${NC}"

# Set DOKKU_SSH_PRIVATE_KEY secret
echo "Setting DOKKU_SSH_PRIVATE_KEY secret..."
gh secret set DOKKU_SSH_PRIVATE_KEY < "$DEPLOY_KEY_PATH"
echo -e "${GREEN}✓ DOKKU_SSH_PRIVATE_KEY set${NC}"

# Set APP_URL secret (optional but helpful)
read -p "Enter your app URL (e.g., https://curated.cx) [skip]: " APP_URL
if [[ -n "$APP_URL" ]]; then
  gh secret set APP_URL --body "$APP_URL"
  echo -e "${GREEN}✓ APP_URL set to $APP_URL${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 4: Testing deployment connection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Testing SSH connection as dokku user..."
if ssh -o StrictHostKeyChecking=no -i "$DEPLOY_KEY_PATH" dokku@"$SERVER_IP" apps:list &> /dev/null; then
  echo -e "${GREEN}✓ SSH connection to dokku@$SERVER_IP works!${NC}"
  echo ""
  echo "Available apps on server:"
  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_KEY_PATH" dokku@"$SERVER_IP" apps:list
else
  echo -e "${RED}❌ SSH connection failed${NC}"
  echo "Debug: Try running manually:"
  echo "  ssh -i $DEPLOY_KEY_PATH dokku@$SERVER_IP apps:list"
  exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   ✅ Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Your GitHub Actions deployment is now configured!"
echo ""
echo -e "${BLUE}To deploy:${NC}"
echo "  git push origin main"
echo ""
echo -e "${BLUE}To manually trigger a deploy:${NC}"
echo "  Go to GitHub → Actions → Deploy to Dokku → Run workflow"
echo ""
echo -e "${BLUE}Secrets configured:${NC}"
echo "  • DOKKU_HOST: $SERVER_IP"
echo "  • DOKKU_SSH_PRIVATE_KEY: (SSH private key)"
if [[ -n "${APP_URL:-}" ]]; then
  echo "  • APP_URL: $APP_URL"
fi
echo ""
echo -e "${BLUE}Deploy key location:${NC}"
echo "  Private: $DEPLOY_KEY_PATH"
echo "  Public:  $DEPLOY_KEY_PATH.pub"
echo ""
