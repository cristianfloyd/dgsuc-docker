#!/bin/bash
set -e

echo "Iniciando Queue Workers..."

# Wait for application to be ready
while [ ! -f "/var/www/html/artisan" ]; do
    echo "Esperando archivos de aplicación..."
    sleep 5
done

# Wait for database
until php -r "
try {
    \$pdo = new PDO('pgsql:host=$DB_HOST;port=5432;dbname=$DB_DATABASE', '$DB_USERNAME', '$DB_PASSWORD');
    \$pdo->query('SELECT 1');
    exit(0);
} catch (Exception \$e) {
    exit(1);
}
" 2>/dev/null; do
    echo "PostgreSQL no está disponible - esperando 1seg antes de reintentar"
    sleep 1
done

echo "La base de datos está lista!"

# Wait for Redis
until php -r "
try {
    \$redis = new Redis();
    \$redis->connect('$REDIS_HOST', 6379);
    \$redis->ping();
    exit(0);
} catch (Exception \$e) {
    exit(1);
}
" 2>/dev/null; do
    echo "Redis no está disponible - esperando 1seg antes de reintentar"
    sleep 1
done

echo "Redis está listo!"

# Clear any stuck jobs (optional, for development)
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    php /var/www/html/artisan queue:flush || true
fi

echo "Iniciando supervisor..."

# Execute supervisor
exec "$@"