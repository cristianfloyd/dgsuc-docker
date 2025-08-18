#!/bin/bash

# ============================================================================
# Script para sincronizar código hacia volúmenes Docker (Linux/WSL)
# ============================================================================

set -e

# Configuración
PROJECT_NAME="dgsuc-docker"
APP_VOLUME="${PROJECT_NAME}_app_code"
NGINX_VOLUME="${PROJECT_NAME}_nginx_config"
COMPOSER_VOLUME="${PROJECT_NAME}_composer_cache"

# Colores para output
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m' # No Color

function log_status() {
    echo -e "🔄 $1" >&2
}

function log_success() {
    echo -e "✅ ${COLOR_GREEN}$1${COLOR_NC}" >&2
}

function log_error() {
    echo -e "❌ ${COLOR_RED}$1${COLOR_NC}" >&2
}

function log_warning() {
    echo -e "⚠️  ${COLOR_YELLOW}$1${COLOR_NC}" >&2
}

function sync_app_code() {
    log_status "Sincronizando código de aplicación..."
    
    # Verificar que el directorio app existe
    if [ ! -d "app" ]; then
        log_error "Directorio 'app' no encontrado"
        return 1
    fi
    
    # Crear contenedor temporal para copiar archivos
    local temp_container="temp_sync_$(date +%s)"
    
    # Crear contenedor temporal con el volumen montado
    if ! docker run -d --name "$temp_container" -v "${APP_VOLUME}:/sync" alpine:latest tail -f /dev/null >/dev/null 2>&1; then
        log_error "Error al crear contenedor temporal"
        return 1
    fi
    
    # Función de limpieza
    cleanup() {
        docker rm -f "$temp_container" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    
    # Copiar archivos de la aplicación
    log_status "Copiando archivos de aplicación..."
    if docker cp "app/." "${temp_container}:/sync/" >/dev/null 2>&1; then
        log_success "Código de aplicación sincronizado"
        return 0
    else
        log_error "Error al copiar código de aplicación"
        return 1
    fi
}

function sync_nginx_config() {
    log_status "Sincronizando configuración de Nginx..."
    
    # Verificar que el directorio de configuración existe
    if [ ! -d "docker/nginx/sites" ]; then
        log_error "Directorio 'docker/nginx/sites' no encontrado"
        return 1
    fi
    
    # Crear contenedor temporal para copiar archivos
    local temp_container="temp_nginx_sync_$(date +%s)"
    
    # Crear contenedor temporal con el volumen montado
    if ! docker run -d --name "$temp_container" -v "${NGINX_VOLUME}:/sync" alpine:latest tail -f /dev/null >/dev/null 2>&1; then
        log_error "Error al crear contenedor temporal para Nginx"
        return 1
    fi
    
    # Función de limpieza
    cleanup() {
        docker rm -f "$temp_container" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    
    # Copiar configuración de Nginx para desarrollo
    log_status "Copiando configuración de Nginx para desarrollo..."
    if docker cp "docker/nginx/sites/development.conf" "${temp_container}:/sync/default.conf" >/dev/null 2>&1; then
        log_success "Configuración de Nginx sincronizada"
        return 0
    else
        log_error "Error al copiar configuración de Nginx"
        return 1
    fi
}

function sync_specific_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_error "Archivo no encontrado: $file_path"
        return 1
    fi
    
    log_status "Sincronizando archivo: $file_path"
    
    # Determinar el volumen de destino basado en la ruta
    local target_volume="$APP_VOLUME"
    local target_path="/sync"
    
    if [[ "$file_path" == docker/nginx/* ]]; then
        target_volume="$NGINX_VOLUME"
        file_path="${file_path#docker/nginx/sites/}"
    elif [[ "$file_path" == app/* ]]; then
        file_path="${file_path#app/}"
    fi
    
    # Crear contenedor temporal
    local temp_container="temp_file_sync_$(date +%s)"
    
    if ! docker run -d --name "$temp_container" -v "${target_volume}:/sync" alpine:latest tail -f /dev/null >/dev/null 2>&1; then
        log_error "Error al crear contenedor temporal"
        return 1
    fi
    
    # Función de limpieza
    cleanup() {
        docker rm -f "$temp_container" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    
    # Crear directorio padre si es necesario
    local parent_dir=$(dirname "$file_path")
    if [ "$parent_dir" != "." ]; then
        docker exec "$temp_container" mkdir -p "/sync/$parent_dir" >/dev/null 2>&1
    fi
    
    # Copiar archivo específico
    if docker cp "$file_path" "${temp_container}:/sync/$file_path" >/dev/null 2>&1; then
        log_success "Archivo sincronizado: $file_path"
        return 0
    else
        log_error "Error al sincronizar archivo: $file_path"
        return 1
    fi
}

function show_help() {
    echo -e "${COLOR_BLUE}🔄 Script de Sincronización para Volúmenes Docker (Linux/WSL)${COLOR_NC}"
    echo ""
    echo "USO:"
    echo "    $0 [ACCIÓN] [ARCHIVO]"
    echo ""
    echo "ACCIONES:"
    echo "    sync-all          Sincronizar todo el código y configuración"
    echo "    sync-app          Sincronizar solo código de aplicación"
    echo "    sync-nginx        Sincronizar solo configuración de Nginx"
    echo "    sync-file         Sincronizar archivo específico (requiere ARCHIVO)"
    echo "    help              Mostrar esta ayuda"
    echo ""
    echo "EJEMPLOS:"
    echo "    $0 sync-all"
    echo "    $0 sync-app"
    echo "    $0 sync-file app/config/app.php"
    echo ""
    echo "VOLÚMENES:"
    echo "    app_code:         $APP_VOLUME"
    echo "    nginx_config:     $NGINX_VOLUME"
    echo "    composer_cache:   $COMPOSER_VOLUME"
}

# Función principal
function main() {
    local action="${1:-help}"
    local file_path="$2"
    
    echo -e "${COLOR_BLUE}🚀 Sincronización de Volúmenes Docker para Linux/WSL${COLOR_NC}"
    echo -e "${COLOR_BLUE}=================================================${COLOR_NC}"
    
    case "$action" in
        "sync-all")
            log_status "Iniciando sincronización completa..."
            if sync_app_code && sync_nginx_config; then
                log_success "Sincronización completa exitosa"
            else
                log_error "Error en la sincronización"
                exit 1
            fi
            ;;
        
        "sync-app")
            if sync_app_code; then
                log_success "Sincronización de aplicación exitosa"
            else
                log_error "Error en sincronización de aplicación"
                exit 1
            fi
            ;;
        
        "sync-nginx")
            if sync_nginx_config; then
                log_success "Sincronización de Nginx exitosa"
            else
                log_error "Error en sincronización de Nginx"
                exit 1
            fi
            ;;
        
        "sync-file")
            if [ -z "$file_path" ]; then
                log_error "Debe especificar la ruta del archivo"
                echo "Ejemplo: $0 sync-file app/config/app.php"
                exit 1
            fi
            
            if sync_specific_file "$file_path"; then
                log_success "Sincronización de archivo exitosa"
            else
                log_error "Error en sincronización de archivo"
                exit 1
            fi
            ;;
        
        "help"|"-h"|"--help")
            show_help
            ;;
        
        *)
            log_error "Acción no válida: $action"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"
