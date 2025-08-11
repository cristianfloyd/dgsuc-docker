#!/bin/bash
# scripts/ssl-health-check.sh

set -e

DOMAIN=${CERTBOT_DOMAIN:-"dgsuc.uba.ar"}
CERT_FILE="./docker/nginx/certs/fullchain.pem"

# Check certificate file exists
if [ ! -f "$CERT_FILE" ]; then
    echo "ERROR: SSL certificate not found"
    exit 1
fi

# Check certificate expiry
expiry_date=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
expiry_timestamp=$(date -d "$expiry_date" +%s)
current_timestamp=$(date +%s)
days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

if [ $days_until_expiry -lt 7 ]; then
    echo "WARNING: SSL certificate expires in $days_until_expiry days"
    exit 1
elif [ $days_until_expiry -lt 30 ]; then
    echo "WARNING: SSL certificate expires in $days_until_expiry days"
    exit 0
else
    echo "OK: SSL certificate valid for $days_until_expiry days"
    exit 0
fi
