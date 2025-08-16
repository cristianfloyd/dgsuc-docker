#!/bin/bash

# Script para sincronizar código desde Windows al volumen interno de Docker
# Esto mejora el rendimiento en sistemas Windows host

set -e

echo "🔄 Sincronizando código al volumen interno de Docker..."

# Verificar que el volumen existe
if ! docker volume inspect dgsuc-docker_app_code >/dev/null 2>&1; then
    echo "⚠️  El volumen app_code no existe. Creándolo..."
    docker volume create dgsuc-docker_app_code
fi

# Verificar que la carpeta app existe
if [ ! -d "./app" ]; then
    echo "❌ La carpeta ./app no existe. No hay nada que sincronizar."
    echo "💡 Primero clona la aplicación con: make clone"
    exit 1
fi

# Crear un contenedor temporal para la sincronización
echo "📦 Creando contenedor temporal para sincronización..."
CONTAINER_ID=$(docker run -d \
    --name sync_temp_$(date +%s) \
    -v dgsuc-docker_app_code:/var/www/html \
    -v "$(pwd)/app:/source:ro" \
    alpine:latest \
    sleep 300)

echo "📦 Contenedor creado: $CONTAINER_ID"

# Esperar un momento para que el contenedor esté listo
sleep 2

# Sincronizar archivos
echo "📁 Copiando archivos al volumen..."
docker exec $CONTAINER_ID sh -c "
    # Limpiar destino (mantener directorios especiales)
    find /var/www/html -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'storage' ! -name 'bootstrap' -exec rm -rf {} + || true
    
    # Copiar archivos principales
    cp -r /source/. /var/www/html/ || true
    
    # Ajustar permisos
    chown -R 1000:1000 /var/www/html || true
    find /var/www/html -type f -exec chmod 644 {} \; || true
    find /var/www/html -type d -exec chmod 755 {} \; || true
    
    # Permisos especiales para Laravel
    if [ -d '/var/www/html/storage' ]; then
        chmod -R 775 /var/www/html/storage || true
    fi
    if [ -d '/var/www/html/bootstrap/cache' ]; then
        chmod -R 775 /var/www/html/bootstrap/cache || true
    fi
    
    # Configurar Git para evitar warnings de ownership
    git config --global --add safe.directory /var/www/html || true
    
    echo 'Sincronización de archivos completada'
"

# Limpiar contenedor temporal
echo "🧹 Limpiando contenedor temporal..."
docker stop $CONTAINER_ID >/dev/null 2>&1 || true
docker rm $CONTAINER_ID >/dev/null 2>&1 || true

echo "✅ Sincronización completada. El código está ahora en el volumen interno de Docker."
echo "💡 Para volver a sincronizar cambios, ejecuta este script nuevamente."