#!/bin/bash
# scripts/change-domain.sh

set -e

# Configuration
OLD_DOMAIN=${1:-"dgsuc.uba.ar"}
NEW_DOMAIN=${2:-"dgsuc.cristianarenas.com"}
OLD_EMAIL=${3:-"admin@uba.ar"}
NEW_EMAIL=${4:-"admin@cristianarenas.com"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate inputs
if [ -z "$NEW_DOMAIN" ]; then
    log_error "Usage: $0 <old-domain> <new-domain> [old-email] [new-email]"
    log_error "Example: $0 dgsuc.uba.ar dgsuc.cristianarenas.com admin@uba.ar admin@cristianarenas.com"
    exit 1
fi

log_info "Changing domain from $OLD_DOMAIN to $NEW_DOMAIN..."

# Backup current configuration
log_info "Creating backup..."
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
cp docker/nginx/sites/default-ssl.conf docker/nginx/sites/default-ssl.conf.backup.$(date +%Y%m%d_%H%M%S)

# Update .env file
log_info "Updating .env file..."
sed -i "s|APP_URL=.*|APP_URL=https://$NEW_DOMAIN|g" .env
sed -i "s|CERTBOT_EMAIL=.*|CERTBOT_EMAIL=$NEW_EMAIL|g" .env
sed -i "s|CERTBOT_DOMAIN=.*|CERTBOT_DOMAIN=$NEW_DOMAIN|g" .env
sed -i "s|SESSION_DOMAIN=.*|SESSION_DOMAIN=.${NEW_DOMAIN#*.}|g" .env
sed -i "s|MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=dgsuc@${NEW_DOMAIN#*.}|g" .env
sed -i "s|MAIL_USERNAME=.*|MAIL_USERNAME=dgsuc@${NEW_DOMAIN#*.}|g" .env

# Update CORS if exists
if grep -q "CORS_ALLOWED_ORIGINS" .env; then
    sed -i "s|CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=https://$NEW_DOMAIN,https://www.$NEW_DOMAIN|g" .env
fi

# Update nginx configuration
log_info "Updating nginx configuration..."
sed -i "s|server_name.*$OLD_DOMAIN.*|server_name $NEW_DOMAIN www.$NEW_DOMAIN;|g" docker/nginx/sites/default-ssl.conf

# Remove old SSL certificates
log_info "Removing old SSL certificates..."
rm -f docker/nginx/certs/fullchain.pem
rm -f docker/nginx/certs/privkey.pem

# Update Laravel configuration if app exists
if [ -d "app" ]; then
    log_info "Updating Laravel configuration..."
    
    # Update config/app.php
    if [ -f "app/config/app.php" ]; then
        sed -i "s|'url' => env('APP_URL', 'https://$OLD_DOMAIN')|'url' => env('APP_URL', 'https://$NEW_DOMAIN')|g" app/config/app.php
    fi
    
    # Update config/session.php
    if [ -f "app/config/session.php" ]; then
        sed -i "s|'domain' => env('SESSION_DOMAIN', '.${OLD_DOMAIN#*.}')|'domain' => env('SESSION_DOMAIN', '.${NEW_DOMAIN#*.}')|g" app/config/session.php
    fi
fi

# Generate new SSL certificate
log_info "Generating new SSL certificate for $NEW_DOMAIN..."
./scripts/ssl-setup.sh letsencrypt "$NEW_DOMAIN" "$NEW_EMAIL"

# Update crontab for SSL renewal
log_info "Updating SSL renewal cron job..."
(crontab -l 2>/dev/null | grep -v "ssl-auto-renew.sh"; echo "0 2 * * * $(pwd)/scripts/ssl-auto-renew.sh >> /var/log/ssl-renewal.log 2>&1") | crontab -

log_info "Domain change completed!"
log_info "New domain: $NEW_DOMAIN"
log_info "New email: $NEW_EMAIL"
log_warn "Remember to:"
log_warn "1. Update your DNS records to point to this server"
log_warn "2. Restart the containers: make restart"
log_warn "3. Test the new domain: make ssl-test"
