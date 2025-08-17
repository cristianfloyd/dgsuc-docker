#!/bin/bash

# Script para solucionar errores de inicialización de DGSUC Docker
# Versión específica para Windows

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
echo "║        DGSUC Docker - Solución de Errores (Windows)      ║"
echo "║              Fix Initialization Errors                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Verificar que el directorio app existe
log_title "Verificación del Directorio de la Aplicación"
if [ ! -d "./app" ]; then
    log_step "Directorio ./app no existe, clonando aplicación..."
    if [ -f "./scripts/clone-app.sh" ]; then
        chmod +x ./scripts/clone-app.sh
        ./scripts/clone-app.sh
        log_info "Aplicación clonada exitosamente"
    else
        log_error "Script clone-app.sh no encontrado"
        exit 1
    fi
else
    log_info "Directorio ./app existe"
fi

# 2. Verificar que el volumen Docker existe
log_title "Verificación del Volumen Docker"
if ! docker volume ls | grep -q "dgsuc-docker_app_code"; then
    log_step "Creando volumen dgsuc-docker_app_code..."
    docker volume create dgsuc-docker_app_code
    log_info "Volumen creado exitosamente"
else
    log_info "Volumen dgsuc-docker_app_code ya existe"
fi

# 3. Sincronizar código al volumen usando docker cp (más confiable en Windows)
log_title "Sincronización de Código al Volumen"
log_step "Sincronizando código al volumen Docker (método Windows)..."

# Crear contenedor temporal con Git instalado
TIMESTAMP=$(date +%s)
CONTAINER_NAME="dgsuc-sync-$TIMESTAMP"

# Crear contenedor temporal
docker run -d --name "$CONTAINER_NAME" \
    -v dgsuc-docker_app_code:/var/www/html \
    alpine:latest sh -c "apk add --no-cache git && sleep 300"

# Esperar que el contenedor esté listo
sleep 5

# Verificar que el contenedor está ejecutándose
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    log_error "El contenedor temporal no se pudo crear"
    exit 1
fi

log_info "Contenedor temporal creado: $CONTAINER_NAME"

# Limpiar el volumen
docker exec "$CONTAINER_NAME" sh -c "rm -rf /var/www/html/*"

# Copiar archivos usando docker cp (más confiable en Windows)
log_step "Copiando archivos al volumen..."
if docker cp ./app/. "$CONTAINER_NAME:/var/www/html/"; then
    log_info "Código copiado exitosamente usando docker cp"
else
    log_error "Error al copiar archivos con docker cp"
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
    exit 1
fi

# Verificar que los archivos se copiaron correctamente
if docker exec "$CONTAINER_NAME" test -f /var/www/html/composer.json; then
    log_info "Archivos verificados correctamente"
else
    log_error "Los archivos no se copiaron correctamente"
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
    exit 1
fi

# Limpiar contenedor temporal
docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
log_info "Contenedor temporal limpiado"

# 4. Verificar que los contenedores se pueden construir
log_title "Verificación de Construcción de Contenedores"
log_step "Verificando construcción de contenedores..."
if docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml build --no-cache; then
    log_info "Contenedores construidos exitosamente"
else
    log_error "Error al construir contenedores"
    exit 1
fi

# 5. Iniciar servicios
log_title "Inicio de Servicios"
log_step "Iniciando servicios..."
if docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml up -d; then
    log_info "Servicios iniciados exitosamente"
else
    log_error "Error al iniciar servicios"
    exit 1
fi

# 6. Instalar dependencias de Composer
log_title "Instalación de Dependencias"
log_step "Instalando dependencias de Composer..."
sleep 15  # Esperar más tiempo en Windows para que los contenedores estén listos

# Intentar instalar dependencias con timeout más largo
if timeout 300 docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app composer install --no-interaction; then
    log_info "Dependencias de Composer instaladas"
else
    log_warn "Error al instalar dependencias de Composer (puede ser un timeout)"
    log_step "Reintentando instalación de dependencias con configuración optimizada..."
    
    # Configurar Composer para mejor rendimiento en Windows
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app composer config --global process-timeout 2000 || true
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app composer config --global memory-limit -1 || true
    
    if timeout 600 docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app composer install --no-interaction --optimize-autoloader; then
        log_info "Dependencias de Composer instaladas en el segundo intento"
    else
        log_warn "No se pudieron instalar las dependencias automáticamente"
        log_info "Puedes instalarlas manualmente con: make composer-install"
    fi
fi

# 7. Configurar Git en el contenedor
log_title "Configuración de Git"
log_step "Configurando Git en el contenedor..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app git config --global user.name "DGSUC Docker" || true
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app git config --global user.email "docker@dgsuc.local" || true
log_info "Git configurado en el contenedor"

# 8. Verificar permisos
log_title "Verificación de Permisos"
log_step "Verificando y corrigiendo permisos..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app chown -R dgsuc_user:www-data /var/www/html/storage || true
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app chmod -R 775 /var/www/html/storage || true
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app chown -R dgsuc_user:www-data /var/www/html/bootstrap/cache || true
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml exec -T app chmod -R 775 /var/www/html/bootstrap/cache || true
log_info "Permisos verificados y corregidos"

# 9. Verificar estado final
log_title "Verificación Final"
log_step "Verificando estado de los contenedores..."
if docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml ps | grep -q "Up"; then
    log_info "Contenedores ejecutándose correctamente"
else
    log_error "Algunos contenedores no están ejecutándose"
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.override.yml ps
    exit 1
fi

# 10. Verificar conectividad
log_title "Verificación de Conectividad"
log_step "Verificando conectividad de la aplicación..."
sleep 5

# Verificar que la aplicación responde
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302\|404"; then
    log_info "La aplicación responde correctamente"
else
    log_warn "La aplicación no responde aún (puede estar iniciando)"
    log_info "Puedes verificar manualmente en: http://localhost:8080"
fi

echo ""
log_title "¡Solución de Errores Completada!"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Próximos Pasos                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "✅ El entorno ha sido corregido y está listo para usar."
echo ""
echo "Comandos útiles:"
echo "  • make ps              - Ver estado de los contenedores"
echo "  • make logs            - Ver logs de los contenedores"
echo "  • make dev             - Iniciar entorno de desarrollo"
echo "  • make dev-shell       - Entrar al contenedor de la aplicación"
echo "  • make composer-install - Instalar dependencias de Composer"
echo "  • make db-migrate      - Ejecutar migraciones de base de datos"
echo "  • make sync-to-volume  - Sincronizar cambios al volumen"
echo ""
echo "🌐 La aplicación debería estar disponible en: http://localhost:8080"
echo ""
echo "💡 Notas para Windows:"
echo "  • Si tienes problemas de rendimiento, considera usar WSL"
echo "  • Para sincronizar cambios de código, usa: make sync-to-volume"
echo "  • El código se almacena en volúmenes Docker para mejor rendimiento"
echo ""

log_info "¡Proceso completado exitosamente!"
