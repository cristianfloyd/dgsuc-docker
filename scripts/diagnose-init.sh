#!/bin/bash

# Script de diagnóstico para problemas de inicialización de DGSUC Docker
# Identifica y reporta problemas comunes en el entorno

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}→${NC} $1"; }
log_title() { echo -e "${MAGENTA}═══ $1 ═══${NC}"; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC Docker - Diagnóstico de Problemas        ║"
echo "║                 Initialization Issues                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Verificar Docker
log_title "Verificación de Docker"
if command -v docker &> /dev/null; then
    log_info "Docker está instalado: $(docker --version)"
else
    log_error "Docker no está instalado"
    exit 1
fi

if docker info &> /dev/null; then
    log_info "Docker daemon está ejecutándose"
else
    log_error "Docker daemon no está ejecutándose"
    exit 1
fi

# 2. Verificar Docker Compose
log_title "Verificación de Docker Compose"
if command -v docker-compose &> /dev/null; then
    log_info "Docker Compose está instalado: $(docker-compose --version)"
else
    log_error "Docker Compose no está instalado"
    exit 1
fi

# 3. Verificar Git
log_title "Verificación de Git"
if command -v git &> /dev/null; then
    log_info "Git está instalado: $(git --version)"
else
    log_error "Git no está instalado"
    exit 1
fi

# 4. Verificar estructura del proyecto
log_title "Verificación de Estructura del Proyecto"
if [ -f "docker-compose.yml" ]; then
    log_info "docker-compose.yml encontrado"
else
    log_error "docker-compose.yml no encontrado"
    exit 1
fi

if [ -f "docker-compose.dev.yml" ]; then
    log_info "docker-compose.dev.yml encontrado"
else
    log_error "docker-compose.dev.yml no encontrado"
    exit 1
fi

if [ -f "docker-compose.override.yml" ]; then
    log_info "docker-compose.override.yml encontrado"
else
    log_warn "docker-compose.override.yml no encontrado"
fi

if [ -f "docker-compose.wsl.yml" ]; then
    log_info "docker-compose.wsl.yml encontrado"
else
    log_warn "docker-compose.wsl.yml no encontrado"
fi

# 5. Verificar directorio app
log_title "Verificación del Directorio de la Aplicación"
if [ -d "./app" ]; then
    log_info "Directorio ./app existe"
    if [ -f "./app/.env" ]; then
        log_info "Archivo ./app/.env existe"
    else
        log_warn "Archivo ./app/.env no existe"
    fi
    if [ -f "./app/composer.json" ]; then
        log_info "Archivo ./app/composer.json existe"
    else
        log_warn "Archivo ./app/composer.json no existe"
    fi
else
    log_error "Directorio ./app no existe"
fi

# 6. Verificar archivos .env
log_title "Verificación de Archivos de Configuración"
if [ -f ".env" ]; then
    log_info "Archivo .env principal existe"
else
    log_warn "Archivo .env principal no existe"
fi

if [ -f ".env.dev" ]; then
    log_info "Archivo .env.dev existe"
else
    log_warn "Archivo .env.dev no existe"
fi

if [ -f ".env.prod" ]; then
    log_info "Archivo .env.prod existe"
else
    log_warn "Archivo .env.prod no existe"
fi

if [ -f ".env.example" ]; then
    log_info "Archivo .env.example existe"
else
    log_warn "Archivo .env.example no existe"
fi

# 7. Verificar volúmenes Docker
log_title "Verificación de Volúmenes Docker"
if docker volume ls | grep -q "dgsuc-docker_app_code"; then
    log_info "Volumen dgsuc-docker_app_code existe"
    VOLUME_SIZE=$(docker volume inspect dgsuc-docker_app_code --format '{{.Mountpoint}}' 2>/dev/null | xargs du -sh 2>/dev/null || echo "No disponible")
    log_info "Tamaño del volumen: $VOLUME_SIZE"
else
    log_warn "Volumen dgsuc-docker_app_code no existe"
fi

# 8. Verificar contenedores
log_title "Verificación de Contenedores"
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep dgsuc || echo "Ninguno")
if [ "$RUNNING_CONTAINERS" != "Ninguno" ]; then
    log_info "Contenedores ejecutándose:"
    echo "$RUNNING_CONTAINERS"
else
    log_warn "No hay contenedores ejecutándose"
fi

STOPPED_CONTAINERS=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep dgsuc || echo "Ninguno")
if [ "$STOPPED_CONTAINERS" != "Ninguno" ]; then
    log_info "Contenedores detenidos:"
    echo "$STOPPED_CONTAINERS"
fi

# 9. Verificar imágenes
log_title "Verificación de Imágenes Docker"
DGSUC_IMAGES=$(docker images | grep dgsuc || echo "Ninguna")
if [ "$DGSUC_IMAGES" != "Ninguna" ]; then
    log_info "Imágenes DGSUC disponibles:"
    echo "$DGSUC_IMAGES"
else
    log_warn "No hay imágenes DGSUC disponibles"
fi

# 10. Verificar permisos
log_title "Verificación de Permisos"
if [ -d "./app" ]; then
    if [ -r "./app" ] && [ -w "./app" ]; then
        log_info "Permisos de lectura/escritura en ./app: OK"
    else
        log_error "Problemas de permisos en ./app"
    fi
fi

if [ -d "./storage" ]; then
    if [ -r "./storage" ] && [ -w "./storage" ]; then
        log_info "Permisos de lectura/escritura en ./storage: OK"
    else
        log_error "Problemas de permisos en ./storage"
    fi
fi

# 11. Verificar espacio en disco
log_title "Verificación de Espacio en Disco"
DISK_USAGE=$(df -h . | tail -1)
log_info "Uso de disco en el directorio actual:"
echo "$DISK_USAGE"

# 12. Verificar configuración de red
log_title "Verificación de Red"
if docker network ls | grep -q "dgsuc-docker_default"; then
    log_info "Red dgsuc-docker_default existe"
else
    log_warn "Red dgsuc-docker_default no existe"
fi

# 13. Verificar puertos
log_title "Verificación de Puertos"
if netstat -an 2>/dev/null | grep -q ":8080.*LISTEN"; then
    log_warn "Puerto 8080 está en uso"
else
    log_info "Puerto 8080 está disponible"
fi

if netstat -an 2>/dev/null | grep -q ":5432.*LISTEN"; then
    log_warn "Puerto 5432 está en uso"
else
    log_info "Puerto 5432 está disponible"
fi

# 14. Verificar logs recientes
log_title "Verificación de Logs Recientes"
if [ -f "./storage/logs/laravel.log" ]; then
    log_info "Archivo de log Laravel existe"
    echo "Últimas 5 líneas del log:"
    tail -5 ./storage/logs/laravel.log 2>/dev/null || echo "No se puede leer el log"
else
    log_warn "Archivo de log Laravel no existe"
fi

echo ""
log_title "Diagnóstico Completado"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Resumen del Diagnóstico               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Contar problemas encontrados
ERRORS=$(grep -c "✗" <<< "$(cat /dev/stdin)" 2>/dev/null || echo "0")
WARNINGS=$(grep -c "⚠" <<< "$(cat /dev/stdin)" 2>/dev/null || echo "0")

echo "Problemas encontrados:"
echo "  • Errores críticos: $ERRORS"
echo "  • Advertencias: $WARNINGS"
echo ""

if [ "$ERRORS" -gt 0 ]; then
    log_error "Se encontraron errores críticos que deben resolverse"
    echo ""
    echo "Comandos recomendados:"
    echo "  • make fix-init     - Solucionar errores de inicialización"
    echo "  • make clean        - Limpiar contenedores e imágenes"
    echo "  • make init         - Reinicializar el entorno"
else
    log_info "No se encontraron errores críticos"
    echo ""
    echo "Si tienes problemas específicos:"
    echo "  • make logs         - Ver logs de los contenedores"
    echo "  • make ps           - Ver estado de los contenedores"
    echo "  • make dev          - Iniciar entorno de desarrollo"
fi

echo ""
