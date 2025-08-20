#!/bin/bash
# Script para corregir permisos de Laravel en desarrollo

# Asegurar que los directorios existan
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/{cache,sessions,views}
mkdir -p /var/www/html/bootstrap/cache

# Corregir permisos y ownership para UID 1000 (usuario que ejecuta PHP)
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache
chown -R 1000:1000 /var/www/html/storage
chown -R 1000:1000 /var/www/html/bootstrap/cache

# Ejecutar el comando original
exec "$@"