#!/bin/bash
set -e

echo "Starting Queue Workers..."

# Wait for application to be ready
while [ ! -f "/var/www/html/artisan" ]; do
    echo "Waiting for application files..."
    sleep 5
done

# Wait for database
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_DATABASE" -c '\q' 2>/dev/null; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 1
done

echo "Database is ready!"

# Wait for Redis
until redis-cli -h "$REDIS_HOST" ping 2>/dev/null; do
    echo "Redis is unavailable - sleeping"
    sleep 1
done

echo "Redis is ready!"

# Clear any stuck jobs (optional, for development)
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    php /var/www/html/artisan queue:flush || true
fi

echo "Starting supervisor..."

# Execute supervisor
exec "$@"