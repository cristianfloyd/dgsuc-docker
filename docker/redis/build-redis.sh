#!/bin/bash

# Script para construir la imagen personalizada de Redis para DGSUC
# Incluye configuraciones optimizadas para producción y logging para Portainer

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
REGISTRY_URL="${REGISTRY_URL:-registry.rec.uba.ar}"
PROJECT_NAME="${PROJECT_NAME:-dgsuc}"
IMAGE_NAME="${IMAGE_NAME:-redis}"
TAG="${TAG:-production}"
FULL_IMAGE_NAME="${REGISTRY_URL}/${PROJECT_NAME}/${IMAGE_NAME}:${TAG}"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  DGSUC Redis Docker Image Builder${NC}"
echo -e "${BLUE}===============================================${NC}"
echo

# Función para manejar errores
handle_error() {
    echo -e "${RED}❌ Error en línea $1: Comando falló${NC}"
    exit 1
}

# Trap para capturar errores
trap 'handle_error $LINENO' ERR

# Verificar que estamos en el directorio correcto
if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}❌ Error: No se encontró Dockerfile en el directorio actual${NC}"
    echo -e "${YELLOW}💡 Asegúrate de ejecutar este script desde docker/redis/${NC}"
    exit 1
fi

# Verificar que existe el archivo de configuración
if [[ ! -f "redis-prod.conf" ]]; then
    echo -e "${RED}❌ Error: No se encontró redis-prod.conf${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Configuración:${NC}"
echo -e "   Registry: ${REGISTRY_URL}"
echo -e "   Proyecto: ${PROJECT_NAME}"
echo -e "   Imagen: ${IMAGE_NAME}"
echo -e "   Tag: ${TAG}"
echo -e "   Nombre completo: ${FULL_IMAGE_NAME}"
echo

# Preguntar confirmación si no estamos en modo CI
if [[ "${CI:-false}" != "true" ]]; then
    echo -e "${YELLOW}¿Continuar con la construcción? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏸️  Construcción cancelada${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}📋 Iniciando construcción de imagen Redis...${NC}"

# Construir la imagen
echo -e "${YELLOW}🔨 Construyendo imagen Docker...${NC}"
docker build \
    --tag "${FULL_IMAGE_NAME}" \
    --tag "${REGISTRY_URL}/${PROJECT_NAME}/${IMAGE_NAME}:latest" \
    --progress=plain \
    .

echo -e "${GREEN}✅ Imagen construida exitosamente${NC}"

# Mostrar información de la imagen
echo -e "${BLUE}📊 Información de la imagen:${NC}"
docker images "${REGISTRY_URL}/${PROJECT_NAME}/${IMAGE_NAME}"

# Verificar la imagen
echo -e "${YELLOW}🔍 Verificando imagen...${NC}"
echo -e "${BLUE}📋 Verificando configuración de Redis...${NC}"

# Test básico de la imagen
if docker run --rm --name redis-test-build \
    -e REDIS_PASSWORD=test123 \
    "${FULL_IMAGE_NAME}" \
    timeout 5s redis-server --version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Imagen verificada correctamente${NC}"
else
    echo -e "${RED}❌ Error: La imagen no pasa las verificaciones básicas${NC}"
    exit 1
fi

# Preguntar si subir al registry
if [[ "${PUSH:-}" == "true" ]] || [[ "${CI:-false}" == "true" ]]; then
    PUSH_TO_REGISTRY="y"
else
    echo -e "${YELLOW}¿Subir imagen al registry ${REGISTRY_URL}? (y/N)${NC}"
    read -r PUSH_TO_REGISTRY
fi

if [[ "$PUSH_TO_REGISTRY" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📤 Subiendo imagen al registry...${NC}"

    # Push de ambos tags
    docker push "${FULL_IMAGE_NAME}"
    docker push "${REGISTRY_URL}/${PROJECT_NAME}/${IMAGE_NAME}:latest"

    echo -e "${GREEN}✅ Imagen subida al registry exitosamente${NC}"
    echo -e "${BLUE}🔗 Imagen disponible en: ${FULL_IMAGE_NAME}${NC}"
else
    echo -e "${YELLOW}⏸️  Imagen construida localmente (no subida al registry)${NC}"
fi

echo
echo -e "${GREEN}🎉 ¡Proceso completado exitosamente!${NC}"
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  Imagen Redis personalizada lista para usar${NC}"
echo -e "${BLUE}===============================================${NC}"
echo
echo -e "${YELLOW}💡 Para usar esta imagen, actualiza tu docker-compose.yml:${NC}"
echo -e "${BLUE}   redis:${NC}"
echo -e "${BLUE}     image: ${FULL_IMAGE_NAME}${NC}"
echo