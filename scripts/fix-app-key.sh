#!/bin/bash

# Script para solucionar el problema de APP_KEY en Laravel
# Este script asegura que la clave de aplicación esté correctamente configurada

set -e

echo "🔧 Solucionando problema de APP_KEY en Laravel..."

# Verificar que el contenedor esté ejecutándose
if ! docker ps | grep -q "dgsuc_app"; then
    echo "❌ Error: El contenedor dgsuc_app no está ejecutándose"
    exit 1
fi

# Hacer backup del archivo .env actual
echo "📋 Haciendo backup del archivo .env..."
docker exec dgsuc_app cp /var/www/html/.env /var/www/html/.env.backup.$(date +%Y%m%d_%H%M%S)

# Eliminar todas las líneas APP_KEY existentes
echo "🧹 Limpiando líneas APP_KEY existentes..."
docker exec dgsuc_app sed -i '/^APP_KEY=/d' /var/www/html/.env

# Agregar una línea APP_KEY vacía después de la línea APP_NAME
echo "➕ Agregando línea APP_KEY..."
docker exec dgsuc_app sed -i '/^APP_NAME=/a APP_KEY=' /var/www/html/.env

# Generar nueva clave de aplicación
echo "🔑 Generando nueva clave de aplicación..."
docker exec dgsuc_app php artisan key:generate

# Verificar que la clave se haya generado correctamente
echo "✅ Verificando que la clave se haya generado..."
if docker exec dgsuc_app grep -q "APP_KEY=base64:" /var/www/html/.env; then
    echo "✅ Clave de aplicación generada correctamente"
else
    echo "❌ Error: La clave de aplicación no se generó correctamente"
    exit 1
fi

# Limpiar caché de configuración
echo "🧹 Limpiando caché de configuración..."
docker exec dgsuc_app php artisan config:clear
docker exec dgsuc_app php artisan cache:clear

echo "🎉 Problema de APP_KEY solucionado exitosamente!"
echo "📝 La aplicación debería funcionar correctamente ahora."
