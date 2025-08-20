#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Funciones de logging
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}→${NC} $1"; }
log_title() { echo -e "${MAGENTA}═══ $1 ═══${NC}"; }

# Header
clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC - Migración a WSL para Performance        ║"
echo "║                Script de Migración Automática             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Verificar si estamos en WSL
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    log_info "Ya estás ejecutando desde WSL ($WSL_DISTRO_NAME)"
else
    log_error "Este script debe ejecutarse desde WSL, no desde Windows"
    echo ""
    echo "Para ejecutar este script:"
    echo "1. Abre PowerShell como administrador"
    echo "2. Ejecuta: wsl"
    echo "3. Navega al proyecto: cd /mnt/d/dgsuc-docker"
    echo "4. Ejecuta: ./scripts/migrate-to-wsl.sh"
    exit 1
fi

# Verificar prerrequisitos
log_title "Verificación de Prerrequisitos"

# Verificar que Docker esté instalado en WSL
if ! command -v docker &> /dev/null; then
    log_error "Docker no está instalado en WSL"
    echo ""
    echo "Para instalar Docker en WSL:"
    echo "curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "sudo sh get-docker.sh"
    echo "sudo usermod -aG docker \$USER"
    exit 1
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose no está instalado en WSL"
    echo ""
    echo "Para instalar Docker Compose:"
    echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
    echo "sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

log_info "Docker y Docker Compose están disponibles"

# Detectar ubicación actual del proyecto
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == /mnt/* ]]; then
    WINDOWS_PATH="$CURRENT_DIR"
    WSL_PATH="/home/$(whoami)/dgsuc-docker"
    log_info "Proyecto detectado en Windows: $CURRENT_DIR"
else
    log_warn "El proyecto ya parece estar en WSL: $CURRENT_DIR"
    read -p "¿Quieres continuar con la optimización de configuración? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 0
    fi
    WSL_PATH="$CURRENT_DIR"
fi

echo ""
log_title "Configuración de Migración"

echo "Opciones de migración:"
echo "  1) Copiar proyecto completo a WSL (recomendado para máximo rendimiento)"
echo "  2) Solo optimizar configuración actual (mantener en Windows)"
echo "  3) Crear symlink desde WSL a Windows (híbrido)"
read -p "Selecciona una opción [1-3]: " MIGRATION_OPTION

case $MIGRATION_OPTION in
    1) MIGRATION_TYPE="copy" ;;
    2) MIGRATION_TYPE="optimize" ;;
    3) MIGRATION_TYPE="symlink" ;;
    *) log_error "Opción inválida"; exit 1 ;;
esac

echo ""
log_title "Ejecutando Migración: $MIGRATION_TYPE"

# Función para copiar proyecto a WSL
copy_to_wsl() {
    log_step "Creando directorio destino en WSL..."
    mkdir -p "$WSL_PATH"
    
    log_step "Copiando archivos del proyecto..."
    # Copiar todo excepto directorios que se regeneran
    rsync -av --progress \
        --exclude='app/vendor/' \
        --exclude='app/node_modules/' \
        --exclude='app/storage/logs/' \
        --exclude='app/storage/framework/cache/' \
        --exclude='app/storage/framework/sessions/' \
        --exclude='app/storage/framework/views/' \
        --exclude='app/bootstrap/cache/' \
        --exclude='.git/' \
        "$WINDOWS_PATH/" "$WSL_PATH/"
    
    log_info "Proyecto copiado a $WSL_PATH"
    
    # Crear alias para fácil acceso
    if ! grep -q "alias dgsuc=" ~/.bashrc; then
        echo "alias dgsuc='cd $WSL_PATH'" >> ~/.bashrc
        log_info "Alias 'dgsuc' agregado a ~/.bashrc"
    fi
}

# Función para crear symlink
create_symlink() {
    log_step "Creando symlink en WSL..."
    ln -sf "$WINDOWS_PATH" "$WSL_PATH"
    log_info "Symlink creado: $WSL_PATH -> $WINDOWS_PATH"
}

# Función para optimizar configuración
optimize_config() {
    local target_dir="$1"
    
    log_step "Optimizando docker-compose.wsl.yml..."
    
    # Backup del archivo actual
    if [ -f "$target_dir/docker-compose.wsl.yml" ]; then
        cp "$target_dir/docker-compose.wsl.yml" "$target_dir/docker-compose.wsl.yml.backup"
    fi
    
    # Crear configuración optimizada
    cat > "$target_dir/docker-compose.wsl.yml" << 'EOF'
# Docker Compose optimizado para WSL2
# Uso: docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d

services:
  app:
    volumes:
      # Volúmenes optimizados para WSL2 - usar rutas WSL nativas
      - ./app:/var/www/html:cached
      - ./app/storage:/var/www/html/storage:delegated
      - ./app/bootstrap/cache:/var/www/html/bootstrap/cache:delegated
      # Volúmenes nombrados para mejor performance
      - php_sessions:/var/www/html/storage/framework/sessions
      - php_cache:/var/www/html/storage/framework/cache
      - composer_cache:/home/dgsuc_user/.composer
    environment:
      # Optimizaciones para WSL2
      - COMPOSER_MEMORY_LIMIT=-1
      - PHP_MEMORY_LIMIT=512M
      # Cache optimizations
      - OPcache.enable=1
      - OPcache.memory_consumption=256
      - OPcache.max_accelerated_files=20000
      - OPcache.revalidate_freq=0
      
  nginx:
    volumes:
      # Solo archivos estáticos con cache optimizado
      - ./app/public:/var/www/html/public:cached,ro
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/sites:/etc/nginx/sites-available:ro
      - ./docker/nginx/certs:/etc/nginx/certs:ro
      - nginx_logs:/var/log/nginx
      
  workers:
    volumes:
      # Misma optimización que app
      - ./app:/var/www/html:cached
      - ./app/storage:/var/www/html/storage:delegated
      - ./app/bootstrap/cache:/var/www/html/bootstrap/cache:delegated
      - php_sessions:/var/www/html/storage/framework/sessions
      - php_cache:/var/www/html/storage/framework/cache
      
  scheduler:
    volumes:
      # Misma optimización que app
      - ./app:/var/www/html:cached
      - ./app/storage:/var/www/html/storage:delegated
      - ./app/bootstrap/cache:/var/www/html/bootstrap/cache:delegated
      - php_sessions:/var/www/html/storage/framework/sessions
      - php_cache:/var/www/html/storage/framework/cache

  # Servicio adicional para desarrollo con hot reload optimizado
  node:
    image: node:18-alpine
    container_name: dgsuc_node_wsl
    working_dir: /var/www/html
    volumes:
      - ./app:/var/www/html:cached
      - node_modules_cache:/var/www/html/node_modules
    networks:
      - dgsuc_network
    command: sh -c "npm install && npm run dev"
    environment:
      - CHOKIDAR_USEPOLLING=false  # Usar eventos nativos en WSL2
      - WATCHPACK_POLLING=false

volumes:
  composer_cache:
    driver: local
  node_modules_cache:
    driver: local
EOF
    
    log_info "Configuración WSL optimizada creada"
}

# Ejecutar migración según opción seleccionada
case $MIGRATION_TYPE in
    "copy")
        copy_to_wsl
        optimize_config "$WSL_PATH"
        cd "$WSL_PATH"
        ;;
    "optimize")
        optimize_config "$CURRENT_DIR"
        ;;
    "symlink")
        create_symlink
        optimize_config "$WSL_PATH"
        cd "$WSL_PATH"
        ;;
esac

echo ""
log_title "Configuración del Entorno WSL"

# Instalar dependencias WSL si es necesario
log_step "Verificando dependencias del sistema..."

# Actualizar paquetes si es necesario
if command -v apt-get &> /dev/null; then
    if [ ! -f "/var/lib/apt/periodic/update-success-stamp" ] || [ $(find /var/lib/apt/periodic/update-success-stamp -mtime +7) ]; then
        log_step "Actualizando paquetes del sistema..."
        sudo apt-get update
    fi
    
    # Instalar herramientas útiles si no están presentes
    PACKAGES_TO_INSTALL=""
    for pkg in rsync make git curl; do
        if ! command -v $pkg &> /dev/null; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
        fi
    done
    
    if [ ! -z "$PACKAGES_TO_INSTALL" ]; then
        log_step "Instalando paquetes faltantes:$PACKAGES_TO_INSTALL"
        sudo apt-get install -y $PACKAGES_TO_INSTALL
    fi
fi

# Configurar Docker para usuario actual
if ! groups | grep -q docker; then
    log_step "Agregando usuario al grupo docker..."
    sudo usermod -aG docker $(whoami)
    log_warn "Debes cerrar sesión y volver a iniciar para que los cambios surtan efecto"
fi

# Verificar que Docker Desktop esté configurado para WSL2
log_step "Verificando configuración de Docker Desktop..."
if docker info | grep -q "WSL"; then
    log_info "Docker Desktop está usando WSL2 backend"
else
    log_warn "Docker Desktop podría no estar usando WSL2 backend"
    echo "Para habilitarlo:"
    echo "1. Abre Docker Desktop"
    echo "2. Ve a Settings > General"
    echo "3. Habilita 'Use the WSL 2 based engine'"
    echo "4. Ve a Settings > Resources > WSL Integration"
    echo "5. Habilita integración con tu distribución WSL"
fi

echo ""
log_title "Configuración de Scripts de Desarrollo"

# Crear script wrapper para desarrollo
cat > wsl-dev.sh << 'EOF'
#!/bin/bash
# Script wrapper para desarrollo en WSL

set -e

# Función para mostrar ayuda
show_help() {
    echo "Uso: ./wsl-dev.sh [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  start     - Iniciar entorno de desarrollo"
    echo "  stop      - Detener entorno"
    echo "  restart   - Reiniciar entorno"
    echo "  logs      - Mostrar logs"
    echo "  shell     - Entrar al contenedor de la aplicación"
    echo "  optimize  - Ejecutar optimizaciones de performance"
    echo "  status    - Mostrar estado de contenedores"
    echo "  clean     - Limpiar contenedores y volúmenes"
}

# Comando principal
case "${1:-start}" in
    "start")
        echo "🚀 Iniciando entorno de desarrollo optimizado para WSL..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d
        echo "✅ Entorno iniciado. Accede en: http://localhost:8080"
        ;;
    "stop")
        echo "🛑 Deteniendo entorno..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml down
        ;;
    "restart")
        echo "🔄 Reiniciando entorno..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml restart
        ;;
    "logs")
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml logs -f ${2:-}
        ;;
    "shell")
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml exec app bash
        ;;
    "optimize")
        echo "⚡ Ejecutando optimizaciones..."
        # Limpiar caches
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml exec app php artisan cache:clear
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml exec app php artisan config:clear
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml exec app php artisan view:clear
        echo "✅ Optimizaciones completadas"
        ;;
    "status")
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml ps
        ;;
    "clean")
        echo "🧹 Limpiando entorno..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml down -v
        docker system prune -f
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Comando desconocido: $1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x wsl-dev.sh
log_info "Script de desarrollo WSL creado: ./wsl-dev.sh"

echo ""
log_title "¡Migración Completada!"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Próximos Pasos                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

case $MIGRATION_TYPE in
    "copy")
        echo "  📁 Proyecto migrado a: $WSL_PATH"
        echo "  🔧 Para acceder rápidamente: alias 'dgsuc' configurado"
        echo ""
        ;;
    "symlink")
        echo "  🔗 Symlink creado: $WSL_PATH"
        echo ""
        ;;
esac

echo "  🚀 Para iniciar el entorno optimizado:"
echo "    ./wsl-dev.sh start"
echo ""
echo "  📊 Para ver el estado:"
echo "    ./wsl-dev.sh status"
echo ""
echo "  🔧 Para optimizar performance:"
echo "    ./wsl-dev.sh optimize"
echo ""
echo "  📝 Para ver todos los comandos:"
echo "    ./wsl-dev.sh help"
echo ""

if [ "$MIGRATION_TYPE" = "copy" ]; then
    echo "  ⚠️  Recuerda:"
    echo "    • El proyecto original en Windows sigue intacto"
    echo "    • Desarrolla desde WSL para mejor performance"
    echo "    • Usa VS Code con extensión Remote-WSL"
    echo ""
fi

echo "  📈 Mejoras de performance esperadas:"
echo "    • 50-80% más rápido en operaciones de archivos"
echo "    • Inicio de contenedores 3-5x más rápido"
echo "    • Hot reload más eficiente"
echo ""

log_info "¡Migración a WSL completada exitosamente!"

# Mostrar ubicación actual y siguiente comando sugerido
echo ""
echo "📍 Ubicación actual: $(pwd)"
echo "💡 Comando sugerido: ./wsl-dev.sh start"