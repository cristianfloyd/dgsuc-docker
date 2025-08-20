#!/bin/bash
# scripts/verify-domain-change.sh

set -e

NEW_DOMAIN=${1:-"dgsuc.cristianarenas.com"}
NEW_EMAIL=${2:-"admin@cristianarenas.com"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Verifying domain change to $NEW_DOMAIN..."

# Check .env file
echo "=== Checking .env file ==="
grep -E "(APP_URL|CERTBOT_DOMAIN|CERTBOT_EMAIL|SESSION_DOMAIN)" .env

# Check nginx configuration
echo -e "\n=== Checking nginx configuration ==="
grep -n "server_name" docker/nginx/sites/default-ssl.conf

# Check SSL certificate
echo -e "\n=== Checking SSL certificate ==="
if [ -f "docker/nginx/certs/fullchain.pem" ]; then
    openssl x509 -in docker/nginx/certs/fullchain.pem -text -noout | grep -A1 "Subject:"
else
    log_warn "SSL certificate not found"
fi

# Test domain resolution
echo -e "\n=== Testing domain resolution ==="
if nslookup "$NEW_DOMAIN" > /dev/null 2>&1; then
    log_info "Domain $NEW_DOMAIN resolves correctly"
else
    log_warn "Domain $NEW_DOMAIN does not resolve - check DNS configuration"
fi

# Test SSL connection
echo -e "\n=== Testing SSL connection ==="
if curl -s -o /dev/null -w "%{http_code}" https://$NEW_DOMAIN | grep -q "200\|301\|302"; then
    log_info "SSL connection to $NEW_DOMAIN successful"
else
    log_warn "SSL connection to $NEW_DOMAIN failed"
fi

log_info "Verification completed!"
