#!/bin/bash
set -e

# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Iniciando contenedor simplificado DGSUC..."

# Configurar PostgreSQL si no está inicializado
if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
    log "Inicializando base de datos PostgreSQL..."

    # Cambiar temporalmente a usuario postgres para inicialización
    su postgres -c "initdb -D /var/lib/postgresql/data --locale=es_AR.UTF-8 --encoding=UTF8"

    # Configurar PostgreSQL
    echo "listen_addresses = '*'" >> /var/lib/postgresql/data/postgresql.conf
    echo "port = 5432" >> /var/lib/postgresql/data/postgresql.conf

    # Configurar autenticación
    cat >> /var/lib/postgresql/data/pg_hba.conf << EOF
host all all 0.0.0.0/0 md5
local all postgres trust
local all all md5
EOF

    # Iniciar PostgreSQL temporalmente para crear usuario y BD
    log "Iniciando PostgreSQL para configuración inicial..."
    su postgres -c "pg_ctl -D /var/lib/postgresql/data start"

    # Esperar que PostgreSQL esté listo
    sleep 5

    # Crear usuario y base de datos
    log "Creando usuario y base de datos..."
    su postgres -c "psql -c \"CREATE USER ${POSTGRES_USER:-postgres} WITH PASSWORD '${POSTGRES_PASSWORD:-1234}';\""
    su postgres -c "psql -c \"CREATE DATABASE ${POSTGRES_DB:-suc_app} OWNER ${POSTGRES_USER:-postgres};\""
    su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB:-suc_app} TO ${POSTGRES_USER:-postgres};\""

    # Crear esquema si se especifica
    if [ ! -z "${DB_SCHEMA}" ]; then
        su postgres -c "psql -d ${POSTGRES_DB:-suc_app} -c \"CREATE SCHEMA IF NOT EXISTS ${DB_SCHEMA};\""
        su postgres -c "psql -d ${POSTGRES_DB:-suc_app} -c \"GRANT ALL ON SCHEMA ${DB_SCHEMA} TO ${POSTGRES_USER:-postgres};\""
    fi

    # Detener PostgreSQL
    su postgres -c "pg_ctl -D /var/lib/postgresql/data stop"

    log "PostgreSQL configurado correctamente."
fi

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

# Ejecutar migraciones si la base de datos está lista
log "Esperando que la base de datos esté disponible..."
while ! pg_isready -h localhost -p 5432 -U ${POSTGRES_USER:-postgres} > /dev/null 2>&1; do
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