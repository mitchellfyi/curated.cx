#!/bin/bash
# Dokku Domain Sync Script
#
# This script synchronizes domains between the Rails application and Dokku.
# It adds new domains, removes stale ones, and manages Let's Encrypt certificates.
#
# Usage: ./sync-domains.sh [app-name]
# Default app-name: curated
#
# This script is designed to run on the Dokku host, either:
# - Manually when needed
# - As a post-deploy hook
# - Via cron for periodic sync

set -e

APP_NAME="${1:-curated}"
DOKKU_CMD="dokku"
CHANGES_MADE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get required domains from Rails app
get_required_domains() {
    # Use rake task and filter to get only the JSON output (line that starts with [)
    $DOKKU_CMD run "$APP_NAME" bundle exec rake dokku:domains 2>/dev/null | grep '^\[' | tail -n 1
}

# Get current Dokku domains for the app
get_current_domains() {
    $DOKKU_CMD domains:report "$APP_NAME" --domains-app-vhosts 2>/dev/null | tr ' ' '\n' | grep -v '^$' | sort -u
}

# Add a domain to Dokku
add_domain() {
    local domain="$1"
    log_info "Adding domain: $domain"
    if $DOKKU_CMD domains:add "$APP_NAME" "$domain" 2>/dev/null; then
        CHANGES_MADE=1
    fi
}

# Remove a domain from Dokku
remove_domain() {
    local domain="$1"
    log_warn "Removing domain: $domain"
    if $DOKKU_CMD domains:remove "$APP_NAME" "$domain" 2>/dev/null; then
        CHANGES_MADE=1
    fi
}

# Enable Let's Encrypt for all domains
enable_letsencrypt() {
    log_info "Enabling Let's Encrypt certificates..."

    # Check if letsencrypt plugin is installed
    if ! $DOKKU_CMD plugin:list 2>/dev/null | grep -q "letsencrypt"; then
        log_error "Let's Encrypt plugin not installed. Install with: dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git"
        return 1
    fi

    # Enable letsencrypt (this will get certs for all domains)
    $DOKKU_CMD letsencrypt:enable "$APP_NAME" 2>/dev/null || {
        log_warn "Let's Encrypt enable failed - this may be normal if already enabled or rate limited"
    }
}

# Main sync logic
main() {
    log_info "Starting domain sync for app: $APP_NAME"

    # Check if app exists
    if ! $DOKKU_CMD apps:exists "$APP_NAME" 2>/dev/null; then
        log_error "App '$APP_NAME' does not exist"
        exit 1
    fi

    # Get required domains from Rails (JSON array)
    log_info "Fetching required domains from Rails app..."
    REQUIRED_JSON=$(get_required_domains)
    if [ -z "$REQUIRED_JSON" ] || [ "$REQUIRED_JSON" = "[]" ]; then
        log_warn "No required domains found from Rails app"
        exit 0
    fi

    # Parse JSON array to newline-separated list and sort
    REQUIRED_DOMAINS=$(echo "$REQUIRED_JSON" | tr -d '[]"' | tr ',' '\n' | sed 's/^ *//' | sort -u)

    # Get current Dokku domains
    log_info "Fetching current Dokku domains..."
    CURRENT_DOMAINS=$(get_current_domains)

    log_info "Required domains:"
    echo "$REQUIRED_DOMAINS" | while read -r d; do [ -n "$d" ] && echo "  - $d"; done

    log_info "Current Dokku domains:"
    echo "$CURRENT_DOMAINS" | while read -r d; do [ -n "$d" ] && echo "  - $d"; done

    # Create temp files for comparison
    TEMP_REQUIRED=$(mktemp)
    TEMP_CURRENT=$(mktemp)
    trap "rm -f $TEMP_REQUIRED $TEMP_CURRENT" EXIT

    echo "$REQUIRED_DOMAINS" | grep -v '^$' > "$TEMP_REQUIRED"
    echo "$CURRENT_DOMAINS" | grep -v '^$' > "$TEMP_CURRENT"

    # Find domains to add (in required but not in current)
    DOMAINS_TO_ADD=$(comm -23 "$TEMP_REQUIRED" "$TEMP_CURRENT" | grep -v '^$' || true)

    # Find domains to remove (in current but not in required)
    # Filter out: default Dokku domain pattern (appname.*) and www variants of required domains
    DOMAINS_TO_REMOVE=""
    for domain in $(comm -13 "$TEMP_REQUIRED" "$TEMP_CURRENT" | grep -v "^${APP_NAME}\." | grep -v '^$'); do
        # Skip www variants of required domains
        base_domain="${domain#www.}"
        if ! grep -q "^${base_domain}$" "$TEMP_REQUIRED" 2>/dev/null; then
            DOMAINS_TO_REMOVE="${DOMAINS_TO_REMOVE} ${domain}"
        else
            log_info "Preserving www variant: $domain (base: $base_domain is required)"
        fi
    done
    DOMAINS_TO_REMOVE=$(echo "$DOMAINS_TO_REMOVE" | tr ' ' '\n' | grep -v '^$' | sort -u || true)

    # Add missing domains
    if [ -n "$DOMAINS_TO_ADD" ]; then
        log_info "Domains to add:"
        for domain in $DOMAINS_TO_ADD; do
            if [ -n "$domain" ]; then
                add_domain "$domain"
            fi
        done
    else
        log_info "No domains to add"
    fi

    # Remove stale domains
    if [ -n "$DOMAINS_TO_REMOVE" ]; then
        log_info "Domains to remove:"
        for domain in $DOMAINS_TO_REMOVE; do
            if [ -n "$domain" ]; then
                remove_domain "$domain"
            fi
        done
    else
        log_info "No domains to remove"
    fi

    # Re-enable Let's Encrypt if changes were made
    if [ "$CHANGES_MADE" -eq 1 ]; then
        enable_letsencrypt
    else
        log_info "No changes made, skipping Let's Encrypt refresh"
    fi

    log_info "Domain sync complete!"

    # Show final state
    log_info "Final domain configuration:"
    $DOKKU_CMD domains:report "$APP_NAME"
}

# Run main function
main
