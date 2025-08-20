#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting DGSUC Application Container...${NC}"

# Check if application exists
if [ ! -f "/var/www/html/artisan" ]; then
    echo -e "${YELLOW}Laravel application not found. Please run 'make init' first.${NC}"
    echo "Waiting for application files..."
    # Keep container running but waiting
    while [ ! -f "/var/www/html/artisan" ]; do
        sleep 5
    done
fi

# Wait for database to be ready
echo "Waiting for database..."
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_DATABASE" -c '\q' 2>/dev/null; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 1
done
echo -e "${GREEN}Database is ready!${NC}"

# Check if vendor directory exists
if [ ! -d "/var/www/html/vendor" ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --no-dev --optimize-autoloader
fi

# Run migrations if in development
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    echo "Running migrations..."
    php artisan migrate --force
fi

# Clear and optimize caches for production
if [ "$APP_ENV" = "production" ]; then
    echo "Optimizing for production..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    php artisan event:cache
fi

# Create storage directories if they don't exist
mkdir -p storage/framework/{sessions,views,cache}
mkdir -p storage/logs
mkdir -p bootstrap/cache

# Set permissions and ownership
chmod -R 775 storage bootstrap/cache
# Ensure correct ownership (run as root first, then switch to www-data)
if [ "$(id -u)" = "0" ]; then
    chown -R 1000:1000 storage bootstrap/cache
    # Create psysh config directory for tinker
    mkdir -p /.config/psysh
    chown -R 1000:1000 /.config
fi

echo -e "${GREEN}Application container ready!${NC}"

# Execute the main command
exec "$@"