#!/bin/bash
set -euo pipefail

# Dokku Maintenance Commands
# Usage: ./script/dokku-maintenance.sh <command> [args]

# Get server IP from terraform or environment
get_server_ip() {
  if [[ -n "${DOKKU_HOST:-}" ]]; then
    echo "$DOKKU_HOST"
  elif [[ -d "terraform" ]] && [[ -f "terraform/terraform.tfstate" ]]; then
    cd terraform
    terraform output -raw droplet_ip 2>/dev/null || echo ""
    cd ..
  else
    echo ""
  fi
}

SERVER_IP=$(get_server_ip)

if [[ -z "$SERVER_IP" ]]; then
  echo "Error: Cannot determine server IP"
  echo "Set DOKKU_HOST environment variable or run terraform first"
  exit 1
fi

APP_NAME="curated"

# SSH helper
dokku_cmd() {
  ssh -o StrictHostKeyChecking=no root@"$SERVER_IP" "dokku $*"
}

ssh_cmd() {
  ssh -o StrictHostKeyChecking=no root@"$SERVER_IP" "$*"
}

# Commands
case "${1:-help}" in
  logs)
    echo "Streaming logs (Ctrl+C to stop)..."
    dokku_cmd logs "$APP_NAME" --tail
    ;;

  console)
    echo "Opening Rails console..."
    dokku_cmd run "$APP_NAME" rails console
    ;;

  dbconsole)
    echo "Opening database console..."
    dokku_cmd postgres:connect "${APP_NAME}-db"
    ;;

  migrate)
    echo "Running database migrations..."
    dokku_cmd run "$APP_NAME" rails db:migrate
    ;;

  restart)
    echo "Restarting app..."
    dokku_cmd ps:restart "$APP_NAME"
    ;;

  stop)
    echo "Stopping app..."
    dokku_cmd ps:stop "$APP_NAME"
    ;;

  start)
    echo "Starting app..."
    dokku_cmd ps:start "$APP_NAME"
    ;;

  status)
    echo "App Status:"
    dokku_cmd ps:report "$APP_NAME"
    echo ""
    echo "Resource Usage:"
    dokku_cmd resource:report "$APP_NAME"
    ;;

  config)
    echo "Environment Variables:"
    dokku_cmd config "$APP_NAME"
    ;;

  config:set)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 config:set KEY=value"
      exit 1
    fi
    shift
    echo "Setting config..."
    dokku_cmd config:set "$APP_NAME" "$@"
    ;;

  backup)
    BACKUP_NAME="manual-$(date +%Y%m%d-%H%M%S)"
    echo "Creating database backup: $BACKUP_NAME"
    dokku_cmd postgres:export "${APP_NAME}-db" > "backup-${BACKUP_NAME}.dump"
    echo "Backup saved to: backup-${BACKUP_NAME}.dump"
    ;;

  restore)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 restore <backup-file>"
      exit 1
    fi
    BACKUP_FILE="$2"
    if [[ ! -f "$BACKUP_FILE" ]]; then
      echo "Backup file not found: $BACKUP_FILE"
      exit 1
    fi
    echo "Restoring from backup: $BACKUP_FILE"
    echo "Warning: This will overwrite the current database!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      dokku_cmd postgres:import "${APP_NAME}-db" < "$BACKUP_FILE"
      echo "Restore complete!"
    fi
    ;;

  ssl:status)
    echo "SSL Certificate Status:"
    dokku_cmd letsencrypt:list
    ;;

  ssl:renew)
    echo "Renewing SSL certificates..."
    dokku_cmd letsencrypt:auto-renew
    ;;

  deploy)
    echo "Triggering deployment..."
    git push origin main
    ;;

  rollback)
    echo "Available releases:"
    dokku_cmd tags:list "$APP_NAME"
    echo ""
    read -p "Enter tag to rollback to: " TAG
    if [[ -n "$TAG" ]]; then
      echo "Rolling back to $TAG..."
      dokku_cmd tags:deploy "$APP_NAME" "$TAG"
    fi
    ;;

  cleanup)
    echo "Cleaning up old containers and images..."
    dokku_cmd cleanup
    ssh_cmd "docker system prune -f"
    ;;

  update)
    echo "Updating Dokku and plugins..."
    ssh_cmd "apt-get update && apt-get upgrade -y dokku"
    dokku_cmd plugin:update
    ;;

  ssh)
    echo "Connecting to server..."
    ssh -o StrictHostKeyChecking=no root@"$SERVER_IP"
    ;;

  run)
    shift
    if [[ -z "${1:-}" ]]; then
      echo "Usage: $0 run <command>"
      exit 1
    fi
    echo "Running: $*"
    dokku_cmd run "$APP_NAME" "$@"
    ;;

  help|*)
    echo "Dokku Maintenance Commands"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "App Management:"
    echo "  logs          Stream application logs"
    echo "  status        Show app status and resources"
    echo "  restart       Restart the application"
    echo "  stop          Stop the application"
    echo "  start         Start the application"
    echo "  deploy        Trigger a new deployment (git push)"
    echo "  rollback      Rollback to a previous release"
    echo ""
    echo "Rails Commands:"
    echo "  console       Open Rails console"
    echo "  migrate       Run database migrations"
    echo "  run <cmd>     Run any command in app container"
    echo ""
    echo "Database:"
    echo "  dbconsole     Open PostgreSQL console"
    echo "  backup        Create database backup"
    echo "  restore <f>   Restore database from backup file"
    echo ""
    echo "Configuration:"
    echo "  config        Show environment variables"
    echo "  config:set    Set environment variable"
    echo ""
    echo "SSL:"
    echo "  ssl:status    Show SSL certificate status"
    echo "  ssl:renew     Renew SSL certificates"
    echo ""
    echo "Server:"
    echo "  ssh           SSH into server"
    echo "  cleanup       Clean up old containers"
    echo "  update        Update Dokku and plugins"
    echo ""
    echo "Server IP: $SERVER_IP"
    ;;
esac
