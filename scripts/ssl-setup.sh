#!/bin/bash
set -e

# Configuration
CERT_DIR="./docker/nginx/certs"
ACTION=${1:-"self-signed"}
DOMAIN=${2:-"localhost"}
EMAIL=${3:-"admin@localhost"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create certificate directory
mkdir -p "$CERT_DIR"

case "$ACTION" in
    "self-signed")
        log_info "Generating self-signed certificate for $DOMAIN..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$CERT_DIR/privkey.pem" \
            -out "$CERT_DIR/fullchain.pem" \
            -subj "/C=AR/ST=Buenos Aires/L=CABA/O=UBA/CN=$DOMAIN"
        
        log_info "Self-signed certificate generated successfully!"
        log_warn "This certificate should only be used for development/testing!"
        ;;
        
    "letsencrypt")
        log_info "Generating Let's Encrypt certificate for $DOMAIN..."
        
        # Check if docker is running
        if ! docker info > /dev/null 2>&1; then
            log_error "Docker is not running"
            exit 1
        fi
        
        # Create temporary webroot
        WEBROOT="./app/public"
        if [ ! -d "$WEBROOT" ]; then
            mkdir -p "$WEBROOT"
        fi
        
        # Run certbot
        docker run -it --rm \
            -v "$(pwd)/$CERT_DIR:/etc/letsencrypt" \
            -v "$(pwd)/$WEBROOT:/var/www/html" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/html \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --force-renewal \
            -d "$DOMAIN"
        
        # Move certificates to correct location
        if [ -d "$CERT_DIR/live/$DOMAIN" ]; then
            cp "$CERT_DIR/live/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
            cp "$CERT_DIR/live/$DOMAIN/privkey.pem" "$CERT_DIR/privkey.pem"
            log_info "Let's Encrypt certificate generated successfully!"
        else
            log_error "Certificate generation failed"
            exit 1
        fi
        ;;
        
    "renew")
        log_info "Renewing Let's Encrypt certificates..."
        
        docker run -it --rm \
            -v "$(pwd)/$CERT_DIR:/etc/letsencrypt" \
            -v "$(pwd)/app/public:/var/www/html" \
            certbot/certbot renew
        
        # Copy renewed certificates
        for domain_dir in "$CERT_DIR"/live/*/; do
            if [ -d "$domain_dir" ]; then
                domain=$(basename "$domain_dir")
                cp "$domain_dir/fullchain.pem" "$CERT_DIR/fullchain.pem"
                cp "$domain_dir/privkey.pem" "$CERT_DIR/privkey.pem"
                log_info "Certificate for $domain renewed!"
            fi
        done
        ;;
        
    "import")
        CERT_FILE=${2:-""}
        KEY_FILE=${3:-""}
        
        if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
            log_error "Usage: $0 import <certificate-file> <key-file>"
            exit 1
        fi
        
        if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
            log_error "Certificate or key file not found"
            exit 1
        fi
        
        log_info "Importing existing certificate..."
        cp "$CERT_FILE" "$CERT_DIR/fullchain.pem"
        cp "$KEY_FILE" "$CERT_DIR/privkey.pem"
        chmod 644 "$CERT_DIR/fullchain.pem"
        chmod 600 "$CERT_DIR/privkey.pem"
        
        log_info "Certificate imported successfully!"
        ;;
        
    *)
        log_error "Unknown action: $ACTION"
        echo "Usage: $0 [self-signed|letsencrypt|renew|import] [domain] [email]"
        echo ""
        echo "Actions:"
        echo "  self-signed  - Generate a self-signed certificate"
        echo "  letsencrypt  - Generate a Let's Encrypt certificate"
        echo "  renew        - Renew existing Let's Encrypt certificates"
        echo "  import       - Import existing certificate and key files"
        exit 1
        ;;
esac

# Set proper permissions
chmod 644 "$CERT_DIR"/*.pem 2>/dev/null || true

log_info "SSL setup complete!"