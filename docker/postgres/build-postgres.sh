#!/bin/bash

# Script para construir y publicar la imagen personalizada de PostgreSQL
# Para usar en el registry privado de Portainer

set -e

echo "🐘 Construyendo imagen personalizada de PostgreSQL para DGSUC..."

# Variables
REGISTRY="registry.rec.uba.ar"
IMAGE_NAME="dgsuc/postgres"
TAG="production"
FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"


# Cambiar al directorio correcto
cd "$(dirname "$0")"

echo "📂 Directorio actual: $(pwd)"
echo "🏗️  Construyendo imagen: ${FULL_IMAGE_NAME}"

# Construir la imagen
docker build -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    echo "✅ Imagen construida exitosamente: ${FULL_IMAGE_NAME}"
    
    echo "📤 Subiendo imagen al registry..."
    docker push "${FULL_IMAGE_NAME}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Imagen subida exitosamente al registry"
        echo "🎉 La imagen está disponible como: ${FULL_IMAGE_NAME}"
        echo ""
        echo "📋 Para usar en Portainer:"
        echo "   - Crear o actualizar el stack con docker-compose.portainer.yml"
        echo "   - La imagen será: ${FULL_IMAGE_NAME}"
        echo "   - Los logs estarán visibles directamente en Portainer"
    else
        echo "❌ Error al subir la imagen al registry"
        exit 1
    fi
else
    echo "❌ Error al construir la imagen"
    exit 1
fi

echo ""
echo "🔍 Verificar configuración de logging:"
echo "   - logging_collector = off"
echo "   - log_destination = 'stderr'"
echo "   - log_min_messages = info"
echo "   - Logs visibles en Portainer logs del contenedor"