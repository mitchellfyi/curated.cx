#!/bin/bash
set -euo pipefail

# Bootstrap script for Dokku setup on DigitalOcean
# Usage: ./script/bootstrap-dokku.sh <server-ip> <app-domain> <admin-email>

SERVER_IP="${1:-}"
APP_DOMAIN="${2:-}"
ADMIN_EMAIL="${3:-}"

if [[ -z "$SERVER_IP" ]] || [[ -z "$APP_DOMAIN" ]] || [[ -z "$ADMIN_EMAIL" ]]; then
  echo "Usage: $0 <server-ip> <app-domain> <admin-email>"
  echo "Example: $0 192.0.2.1 curated.cx admin@curated.cx"
  exit 1
fi

echo "🚀 Bootstrapping Dokku on DigitalOcean droplet..."
echo "Server IP: $SERVER_IP"
echo "App Domain: $APP_DOMAIN"
echo "Admin Email: $ADMIN_EMAIL"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run commands on remote server
run_remote() {
  ssh -o StrictHostKeyChecking=no root@"$SERVER_IP" "$@"
}

# Function to check if command exists on remote
command_exists() {
  run_remote "command -v $1 > /dev/null 2>&1"
}

echo -e "${YELLOW}Step 0: Clearing apt locks (if any)...${NC}"
run_remote "pkill -9 apt-get 2>/dev/null || true"
run_remote "pkill -9 dpkg 2>/dev/null || true"
run_remote "rm -f /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true"
run_remote "dpkg --configure -a 2>/dev/null || true"
echo -e "${GREEN}✓ Apt locks cleared${NC}"

echo ""
echo -e "${YELLOW}Step 1: Installing Dokku...${NC}"
if ! command_exists dokku; then
  run_remote "wget -q https://raw.githubusercontent.com/dokku/dokku/v0.33.3/bootstrap.sh -O bootstrap.sh"
  run_remote "sudo DOKKU_TAG=v0.33.3 bash bootstrap.sh"
  echo -e "${GREEN}✓ Dokku installed${NC}"
else
  echo -e "${GREEN}✓ Dokku already installed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Configuring firewall...${NC}"
run_remote "ufw allow http"
run_remote "ufw allow https"
run_remote "ufw allow 22/tcp"
echo -e "${GREEN}✓ Firewall configured${NC}"

echo ""
echo -e "${YELLOW}Step 3: Creating Dokku app 'curated'...${NC}"
run_remote "dokku apps:create curated 2>/dev/null || echo 'App already exists'"
echo -e "${GREEN}✓ App created${NC}"

echo ""
echo -e "${YELLOW}Step 4: Installing PostgreSQL plugin...${NC}"
if ! command_exists dokku-postgres; then
  run_remote "sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres"
  echo -e "${GREEN}✓ PostgreSQL plugin installed${NC}"
else
  echo -e "${GREEN}✓ PostgreSQL plugin already installed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 5: Creating PostgreSQL database...${NC}"
run_remote "dokku postgres:create curated-db 2>/dev/null || echo 'Database already exists'"
run_remote "dokku postgres:link curated-db curated"
echo -e "${GREEN}✓ PostgreSQL database created and linked${NC}"

echo ""
echo -e "${YELLOW}Step 6: Setting up environment variables...${NC}"

# Get database URL from Dokku
DB_URL=$(run_remote "dokku postgres:info curated-db --dsn" | grep -i "DSN" | awk '{print $3}' || echo "")

if [[ -n "$DB_URL" ]]; then
  run_remote "dokku config:set curated DATABASE_URL=\"$DB_URL\""
  # Extract password for separate variable (Rails multi-database support)
  DB_PASSWORD=$(echo "$DB_URL" | sed -n 's/.*:\([^@]*\)@.*/\1/p')
  if [[ -n "$DB_PASSWORD" ]]; then
    run_remote "dokku config:set curated CURATED_DATABASE_PASSWORD=\"$DB_PASSWORD\""
  fi
fi

# Set production environment
run_remote "dokku config:set curated RAILS_ENV=production"
run_remote "dokku config:set curated SOLID_QUEUE_IN_PUMA=true"
run_remote "dokku config:set curated SECRET_KEY_BASE=\$(openssl rand -hex 64)"

# Prompt for Rails master key
echo ""
echo -e "${YELLOW}Enter your RAILS_MASTER_KEY [from config/master.key or rails credentials:show]:${NC}"
read -s RAILS_MASTER_KEY
run_remote "dokku config:set curated RAILS_MASTER_KEY=\"$RAILS_MASTER_KEY\""

echo ""
echo -e "${GREEN}✓ Environment variables set${NC}"

echo ""
echo -e "${YELLOW}Step 7: Configuring domains...${NC}"

# Set global domain
run_remote "dokku domains:set-global $APP_DOMAIN"

# Set app domain
run_remote "dokku domains:add curated $APP_DOMAIN"
run_remote "dokku domains:add curated www.$APP_DOMAIN"

echo -e "${GREEN}✓ Domains configured${NC}"

echo ""
echo -e "${YELLOW}Step 8: Installing Let's Encrypt plugin...${NC}"
if ! command_exists dokku-letsencrypt; then
  run_remote "sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git"
  echo -e "${GREEN}✓ Let's Encrypt plugin installed${NC}"
else
  echo -e "${GREEN}✓ Let's Encrypt plugin already installed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 9: Configuring Let's Encrypt...${NC}"
run_remote "dokku config:set --no-restart curated DOKKU_LETSENCRYPT_EMAIL=$ADMIN_EMAIL"

# Enable Let's Encrypt
echo ""
echo -e "${YELLOW}Step 10: Enabling SSL certificates...${NC}"
echo -e "${YELLOW}Note: SSL certificates will be provisioned on first deployment${NC}"
echo -e "${YELLOW}Run 'dokku letsencrypt curated' after first deployment to get certificates${NC}"

echo ""
echo -e "${YELLOW}Step 11: Configuring storage volumes...${NC}"
run_remote "dokku storage:ensure-directory curated-storage"
run_remote "dokku storage:mount curated /var/lib/dokku/data/storage/curated-storage:/rails/storage"
echo -e "${GREEN}✓ Storage volumes configured${NC}"

echo ""
echo -e "${YELLOW}Step 12: Setting resource limits (optional)...${NC}"
# Set memory limit (2GB = 2097152 KB)
run_remote "dokku resource:limit curated --memory 2097152"
# Set CPU limit (2 cores)
run_remote "dokku resource:limit curated --cpu 2"
echo -e "${GREEN}✓ Resource limits set${NC}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Dokku bootstrap complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy your app:"
echo "   git remote add dokku dokku@$SERVER_IP:curated"
echo "   git push dokku main"
echo ""
echo "2. After deployment, enable SSL:"
echo "   ssh root@$SERVER_IP 'dokku letsencrypt curated'"
echo ""
echo "3. Set up recurring tasks (Solid Queue handles this automatically)"
echo ""
echo "4. Verify deployment:"
echo "   curl https://$APP_DOMAIN/up"
echo ""
echo "Server IP: $SERVER_IP"
echo "App domain: $APP_DOMAIN"
