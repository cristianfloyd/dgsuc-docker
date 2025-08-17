#!/bin/bash
# Script para corregir permisos de Laravel en desarrollo

# Asegurar que los directorios existan
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/{cache,sessions,views}
mkdir -p /var/www/html/bootstrap/cache

# Corregir permisos y ownership para www-data:www-data
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache

# Ejecutar el comando original
exec "$@"