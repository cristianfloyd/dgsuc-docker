#!/bin/bash
set -e

# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Iniciando aplicación Laravel simplificada..."

# Configurar Laravel
log "Configurando Laravel..."

# Verificar que APP_KEY esté configurado
if [ -z "$APP_KEY" ]; then
    log "Generando APP_KEY..."
    php artisan key:generate --force
fi

# Crear directorios de storage si no existen
mkdir -p storage/logs storage/framework/{cache,sessions,views} bootstrap/cache
chown -R 1000:1000 storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Esperar que PostgreSQL esté disponible
log "Esperando que la base de datos esté disponible..."
while ! pg_isready -h ${DB_HOST:-postgres} -p ${DB_PORT:-5432} -U ${DB_USERNAME:-postgres} > /dev/null 2>&1; do
    sleep 1
done

log "Ejecutando migraciones de Laravel..."
php artisan migrate --force || log "Error en migraciones (continuando...)"

# Optimizar Laravel para producción
if [ "$APP_ENV" = "production" ]; then
    log "Optimizando Laravel para producción..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

log "Configuración completada. Iniciando servicios..."

# Ejecutar comando principal
exec "$@"