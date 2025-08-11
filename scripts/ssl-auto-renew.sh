#!/bin/bash
# scripts/ssl-auto-renew.sh

set -e

# Configuration
CERT_DIR="./docker/nginx/certs"
DOMAIN=${CERTBOT_DOMAIN:-"dgsuc.uba.ar"}
EMAIL=${CERTBOT_EMAIL:-"admin@uba.ar"}
WEBROOT="./app/public"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if certificate needs renewal
check_cert_expiry() {
    if [ -f "$CERT_DIR/fullchain.pem" ]; then
        expiry_date=$(openssl x509 -enddate -noout -in "$CERT_DIR/fullchain.pem" | cut -d= -f2)
        expiry_timestamp=$(date -d "$expiry_date" +%s)
        current_timestamp=$(date +%s)
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_until_expiry -lt 30 ]; then
            log_warn "Certificate expires in $days_until_expiry days"
            return 0
        else
            log_info "Certificate is valid for $days_until_expiry days"
            return 1
        fi
    else
        log_warn "No certificate found"
        return 0
    fi
}

# Renew certificate
renew_certificate() {
    log_info "Renewing SSL certificate for $DOMAIN..."
    
    # Stop nginx temporarily
    docker-compose stop nginx
    
    # Run certbot
    docker run --rm \
        -v "$(pwd)/$CERT_DIR:/etc/letsencrypt" \
        -v "$(pwd)/$WEBROOT:/var/www/html" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"
    
    # Copy certificates
    if [ -d "$CERT_DIR/live/$DOMAIN" ]; then
        cp "$CERT_DIR/live/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
        cp "$CERT_DIR/live/$DOMAIN/privkey.pem" "$CERT_DIR/privkey.pem"
        chmod 644 "$CERT_DIR/fullchain.pem"
        chmod 600 "$CERT_DIR/privkey.pem"
        log_info "Certificate renewed successfully!"
    fi
    
    # Restart nginx
    docker-compose start nginx
    
    # Test certificate
    if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200"; then
        log_info "SSL certificate is working correctly"
    else
        log_error "SSL certificate test failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "Checking SSL certificate status..."
    
    if check_cert_expiry; then
        renew_certificate
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
