#!/bin/bash
set -e

# Definición de códigos de color ANSI para la interfaz de línea de comandos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Funciones de logging para estandarizar la salida de mensajes
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}→${NC} $1"; }
log_title() { echo -e "${MAGENTA}═══ $1 ═══${NC}"; }

# Presentación visual del script de inicialización
clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC Docker Environment Setup                  ║"
echo "║                 Initialization Script                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Validación de dependencias del sistema requeridas
log_title "Verificación de Prerrequisitos"

# Función para validar la disponibilidad de comandos en el PATH del sistema
check_command() {
    if command -v $1 &> /dev/null; then
        log_info "$1 está instalado ($(command -v $1))"
        return 0
    else
        log_error "$1 no está instalado"
        return 1
    fi
}

# Contador de dependencias faltantes para control de flujo
MISSING_DEPS=0

# Validación de herramientas esenciales para el entorno Docker
check_command docker || MISSING_DEPS=1
check_command docker-compose || MISSING_DEPS=1
check_command git || MISSING_DEPS=1
check_command make || log_warn "make no está instalado (opcional pero recomendado)"

# Verificación de integridad de dependencias antes de continuar
if [ $MISSING_DEPS -eq 1 ]; then
    log_error "Faltan dependencias requeridas. Por favor instálalas primero."
    exit 1
fi

# Verificación del estado del servicio Docker daemon
if ! docker info &> /dev/null; then
    log_error "El daemon de Docker no está ejecutándose"
    exit 1
fi
log_info "El daemon de Docker está ejecutándose"

# Detección automática de entorno WSL y recomendaciones de performance
log_title "Detección de Entorno"

# Verificar si estamos en WSL
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    log_info "Entorno WSL detectado: $WSL_DISTRO_NAME"
    WSL_DETECTED=true
    
    # Verificar si el proyecto está en filesystem WSL o Windows
    CURRENT_PATH=$(pwd)
    if [[ "$CURRENT_PATH" == /mnt/* ]]; then
        log_warn "El proyecto está en filesystem Windows (/mnt/...)"
        echo ""
        echo "🚀 RECOMENDACIÓN DE PERFORMANCE:"
        echo "   Para obtener 50-80% mejor rendimiento, considera migrar a WSL:"
        echo "   ./scripts/migrate-to-wsl.sh"
        echo ""
        read -p "¿Quieres ejecutar la migración a WSL ahora? (y/N): " RUN_WSL_MIGRATION
        if [[ $RUN_WSL_MIGRATION =~ ^[Yy]$ ]]; then
            if [ -f "./scripts/migrate-to-wsl.sh" ]; then
                log_step "Ejecutando migración a WSL..."
                chmod +x ./scripts/migrate-to-wsl.sh
                ./scripts/migrate-to-wsl.sh
                exit 0
            else
                log_error "Script de migración no encontrado"
            fi
        fi
        USE_WSL_COMPOSE=true
    else
        log_info "Proyecto en filesystem WSL nativo (óptimo)"
        USE_WSL_COMPOSE=true
    fi
elif [[ "$OS" == "Windows_NT" ]] || command -v wsl.exe &> /dev/null; then
    log_warn "Entorno Windows detectado"
    WSL_DETECTED=false
    
    # Verificar si WSL está disponible
    if command -v wsl.exe &> /dev/null; then
        echo ""
        echo "🚀 OPTIMIZACIÓN DISPONIBLE:"
        echo "   WSL está instalado en tu sistema. Para mejor performance:"
        echo "   1. Abre PowerShell como Administrador"
        echo "   2. Ejecuta: wsl"
        echo "   3. Navega a: cd /mnt/$(echo $PWD | cut -d: -f1 | tr '[:upper:]' '[:lower:]')/$(echo $PWD | cut -d: -f2- | tr '\\' '/')"
        echo "   4. Ejecuta: ./scripts/migrate-to-wsl.sh"
        echo ""
        echo "   Alternativamente, puedes usar volúmenes Docker para mejor rendimiento:"
        echo "   - Esta configuración usará volúmenes internos de Docker"
        echo "   - Mejora significativamente el rendimiento en Windows"
        echo ""
        read -p "¿Qué opción prefieres? (w)sl / (v)olumen Docker / (e)stándar: " WINDOWS_OPTION
        case $WINDOWS_OPTION in
            [Ww]*)
                log_info "Configuración cancelada. Ejecuta desde WSL para mejor performance."
                exit 0
                ;;
            [Vv]*)
                log_info "Configurando para usar volúmenes Docker (optimizado para Windows)"
                USE_DOCKER_VOLUME=true
                ;;
            *)
                log_info "Continuando con configuración estándar"
                USE_DOCKER_VOLUME=false
                ;;
        esac
    else
        echo ""
        echo "💡 OPTIMIZACIÓN PARA WINDOWS:"
        echo "   Se detectó Windows sin WSL. Para mejor rendimiento se usarán"
        echo "   volúmenes internos de Docker en lugar de bind mounts."
        echo ""
        read -p "¿Usar volúmenes Docker para mejor rendimiento? (Y/n): " USE_VOLUMES
        if [[ $USE_VOLUMES =~ ^[Nn]$ ]]; then
            USE_DOCKER_VOLUME=false
        else
            USE_DOCKER_VOLUME=true
            log_info "Configurando para usar volúmenes Docker (optimizado para Windows)"
        fi
    fi
    USE_WSL_COMPOSE=false
else
    log_info "Entorno Linux/Unix detectado"
    WSL_DETECTED=false
    USE_WSL_COMPOSE=false
    USE_DOCKER_VOLUME=false
fi

echo ""

# Selección del entorno
log_title "Selección de Entorno"
echo "Selecciona el entorno a inicializar:"
echo "  1) Desarrollo"
echo "  2) Producción"
echo "  3) Ambos"
read -p "Ingresa tu elección [1-3]: " ENV_CHOICE

case $ENV_CHOICE in
    1) ENVIRONMENTS="dev" ;;
    2) ENVIRONMENTS="prod" ;;
    3) ENVIRONMENTS="dev prod" ;;
    *) log_error "Elección inválida"; exit 1 ;;
esac

echo ""

# Clonación de la aplicación
log_title "Configuración de la Aplicación"

if [ ! -d "./app" ]; then
    read -p "Ingresa la URL del repositorio Git (o presiona Enter para el predeterminado): " REPO_URL
    REPO_URL=${REPO_URL:-"https://github.com/cristianfloyd/dgsuc-app.git"}
    
    read -p "Ingresa el nombre de la rama (predeterminado: main): " BRANCH
    BRANCH=${BRANCH:-"main"}
    
    log_step "Clonando aplicación..."
    ./scripts/clone-app.sh "$REPO_URL" "$BRANCH"
else
    log_info "El directorio de la aplicación ya existe"
    read -p "¿Quieres actualizarlo? (y/N): " UPDATE_APP
    if [[ $UPDATE_APP =~ ^[Yy]$ ]]; then
        cd app && git pull && cd ..
        log_info "Aplicación actualizada"
    fi
fi

# Función para sincronizar archivos .env con el entorno específico
sync_env_files() {
    # Determinar qué archivo .env usar
    local source_env_file
    if [ -f ".env" ] && [ -L ".env" ]; then
        # Si .env es un symlink, obtener el archivo real
        source_env_file=$(readlink .env)
    elif [ -f ".env" ]; then
        source_env_file=".env"
    else
        log_warn "No se encontró archivo .env para sincronizar"
        return 1
    fi
    
    if [ -f "$source_env_file" ] && [ -d "./app" ]; then
        if [ ! -f "./app/.env" ]; then
            log_step "Copiando $source_env_file a la aplicación Laravel..."
            cp "$source_env_file" ./app/.env
            log_info "Archivo $source_env_file copiado a ./app/.env"
        else
            # Verificar si las credenciales de DB están sincronizadas
            ROOT_DB_USER=$(grep "^DB_USERNAME=" "$source_env_file" | cut -d'=' -f2)
            ROOT_DB_PASS=$(grep "^DB_PASSWORD=" "$source_env_file" | cut -d'=' -f2)
            ROOT_DB_NAME=$(grep "^DB_DATABASE=" "$source_env_file" | cut -d'=' -f2)
            
            APP_DB_USER=$(grep "^DB_USERNAME=" ./app/.env | cut -d'=' -f2 2>/dev/null || echo "")
            APP_DB_PASS=$(grep "^DB_PASSWORD=" ./app/.env | cut -d'=' -f2 2>/dev/null || echo "")
            APP_DB_NAME=$(grep "^DB_DATABASE=" ./app/.env | cut -d'=' -f2 2>/dev/null || echo "")
            
            if [ "$ROOT_DB_USER" != "$APP_DB_USER" ] || [ "$ROOT_DB_PASS" != "$APP_DB_PASS" ] || [ "$ROOT_DB_NAME" != "$APP_DB_NAME" ]; then
                log_warn "Las credenciales de base de datos no están sincronizadas"
                echo "  Entorno ($source_env_file): DB_USERNAME=$ROOT_DB_USER, DB_DATABASE=$ROOT_DB_NAME"
                echo "  App (./app/.env): DB_USERNAME=$APP_DB_USER, DB_DATABASE=$APP_DB_NAME"
                read -p "¿Quieres sobrescribir ./app/.env con la configuración de $source_env_file? (y/N): " SYNC_ENV
                if [[ $SYNC_ENV =~ ^[Yy]$ ]]; then
                    cp "$source_env_file" ./app/.env
                    log_info "Archivo .env sincronizado desde $source_env_file"
                fi
            else
                log_info "Credenciales de base de datos ya están sincronizadas con $source_env_file"
            fi
        fi
    fi
}

echo ""

# Configuración de archivos de entorno
log_title "Configuración del Entorno"

# Crear archivos específicos del entorno si no existen
for ENV in $ENVIRONMENTS; do
    ENV_FILE=".env.$ENV"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_step "Creando $ENV_FILE..."
        cp .env.example "$ENV_FILE"
        log_warn "Por favor configura $ENV_FILE antes de continuar"
        
        # Generar APP_KEY si no existe o está vacía
        if ! grep -q "^APP_KEY=base64:" "$ENV_FILE" 2>/dev/null; then
            if command -v openssl &> /dev/null; then
                APP_KEY="base64:$(openssl rand -base64 32)"
                if grep -q "^APP_KEY=" "$ENV_FILE"; then
                    sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" "$ENV_FILE"
                else
                    echo "APP_KEY=$APP_KEY" >> "$ENV_FILE"
                fi
                log_info "APP_KEY generada para $ENV_FILE"
            fi
        fi
        
        # Configuración interactiva para valores críticos
        if [ "$ENV" = "prod" ]; then
            echo ""
            log_step "Configurar ajustes de producción:"
            read -p "Contraseña de la base de datos: " -s DB_PASS
            echo ""
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" "$ENV_FILE"
            
            read -p "Contraseña de Redis (opcional): " -s REDIS_PASS
            echo ""
            if [ ! -z "$REDIS_PASS" ]; then
                sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASS/" "$ENV_FILE"
            fi
            
            read -p "URL de la aplicación (ej., https://dgsuc.uba.ar): " APP_URL
            sed -i "s|APP_URL=.*|APP_URL=$APP_URL|" "$ENV_FILE"
        elif [ "$ENV" = "dev" ]; then
            echo ""
            log_step "Configurar ajustes de desarrollo:"
            read -p "Contraseña de la base de datos principal: " -s DB_PASS
            echo ""
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" "$ENV_FILE"
            
            read -p "¿Configurar contraseña de Redis? (y/N): " CONFIG_REDIS
            if [[ $CONFIG_REDIS =~ ^[Yy]$ ]]; then
                read -p "Contraseña de Redis (opcional): " -s REDIS_PASS
                echo ""
                if [ ! -z "$REDIS_PASS" ]; then
                    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASS/" "$ENV_FILE"
                fi
            fi
        fi
    else
        log_info "$ENV_FILE ya existe"
    fi
done

# Determinar el entorno principal y crear symlink .env
if [[ " $ENVIRONMENTS " =~ " dev " ]]; then
    PRIMARY_ENV="dev"
elif [[ " $ENVIRONMENTS " =~ " prod " ]]; then
    PRIMARY_ENV="prod"
else
    PRIMARY_ENV="dev"  # fallback
fi

log_step "Configurando .env principal para entorno: $PRIMARY_ENV"
if [ -f ".env" ] && [ -L ".env" ]; then
    rm .env  # Remover symlink existente
elif [ -f ".env" ]; then
    mv .env .env.backup  # Backup del archivo manual si existe
    log_warn "Se hizo backup del .env existente como .env.backup"
fi

# Crear symlink .env -> .env.{entorno}
if [ "$OS" = "Windows_NT" ]; then
    # En Windows, copiar en lugar de symlink
    cp ".env.$PRIMARY_ENV" .env
    log_info ".env copiado desde .env.$PRIMARY_ENV (Windows)"
else
    ln -sf ".env.$PRIMARY_ENV" .env
    log_info ".env enlazado a .env.$PRIMARY_ENV"
fi

# Verificar y generar APP_KEY para archivos existentes
log_step "Verificando claves de aplicación..."
for ENV_FILE in .env.dev .env.prod; do
    if [ -f "$ENV_FILE" ]; then
        if ! grep -q "^APP_KEY=base64:" "$ENV_FILE" 2>/dev/null; then
            if command -v openssl &> /dev/null; then
                APP_KEY="base64:$(openssl rand -base64 32)"
                if grep -q "^APP_KEY=" "$ENV_FILE"; then
                    sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" "$ENV_FILE"
                else
                    echo "APP_KEY=$APP_KEY" >> "$ENV_FILE"
                fi
                log_info "APP_KEY generada para $ENV_FILE"
            fi
        fi
    fi
done

# Sincronizar archivos .env después de crearlos
log_step "Sincronizando archivos de configuración..."
sync_env_files

echo ""

# Generación de clave de Laravel si es necesario
if [ -f "./app/.env" ]; then
    # Verificar si APP_KEY está vacía o no existe
    if ! grep -q "^APP_KEY=base64:" "./app/.env" 2>/dev/null; then
        log_step "Generando clave de aplicación Laravel..."
        
        # Generar una clave base64 válida usando openssl
        if command -v openssl &> /dev/null; then
            APP_KEY="base64:$(openssl rand -base64 32)"
            
            # Actualizar el archivo .env con la nueva clave
            if grep -q "^APP_KEY=" "./app/.env"; then
                # Reemplazar línea existente
                sed -i "s|^APP_KEY=.*|APP_KEY=$APP_KEY|" "./app/.env"
            else
                # Agregar nueva línea
                echo "APP_KEY=$APP_KEY" >> "./app/.env"
            fi
            
            log_info "Clave de aplicación generada: ${APP_KEY:0:20}..."
        else
            log_warn "OpenSSL no está disponible. Deberás generar APP_KEY manualmente con: php artisan key:generate"
        fi
    else
        log_info "Clave de aplicación Laravel ya está configurada"
    fi
fi

echo ""

# Configuración de claves SSH
log_title "Configuración SSH"

if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
fi

read -p "¿Necesitas configurar túneles SSH para bases de datos externas? (y/N): " SETUP_SSH
if [[ $SETUP_SSH =~ ^[Yy]$ ]]; then
    log_step "Configurando claves SSH..."
    
    read -p "Ruta a la clave privada SSH para túneles: " SSH_KEY_PATH
    if [ -f "$SSH_KEY_PATH" ]; then
        cp "$SSH_KEY_PATH" "$HOME/.ssh/tunnel_key"
        chmod 600 "$HOME/.ssh/tunnel_key"
        log_info "Clave SSH configurada"
    else
        log_error "Clave SSH no encontrada en $SSH_KEY_PATH"
    fi
    
    # Actualización de la configuración del túnel
    read -p "Host del túnel SSH: " SSH_HOST
    read -p "Usuario del túnel SSH: " SSH_USER
    read -p "Puerto del túnel SSH (predeterminado: 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    
    for ENV_FILE in .env.dev .env.prod; do
        if [ -f "$ENV_FILE" ]; then
            sed -i "s/MAPUCHE_SSH_HOST=.*/MAPUCHE_SSH_HOST=$SSH_HOST/" "$ENV_FILE"
            sed -i "s/MAPUCHE_SSH_USER=.*/MAPUCHE_SSH_USER=$SSH_USER/" "$ENV_FILE"
            sed -i "s/MAPUCHE_SSH_PORT=.*/MAPUCHE_SSH_PORT=$SSH_PORT/" "$ENV_FILE"
        fi
    done
fi

echo ""

# Configuración SSL para producción
if [[ " $ENVIRONMENTS " =~ " prod " ]]; then
    log_title "Configuración SSL"
    
    echo "Selecciona la opción de certificado SSL:"
    echo "  1) Generar con Let's Encrypt"
    echo "  2) Usar certificados existentes"
    echo "  3) Generar autofirmado (solo para pruebas)"
    echo "  4) Omitir por ahora"
    read -p "Ingresa tu elección [1-4]: " SSL_CHOICE
    
    case $SSL_CHOICE in
        1)
            read -p "Ingresa el dominio (ej., dgsuc.uba.ar): " DOMAIN
            read -p "Ingresa el email para Let's Encrypt: " LE_EMAIL
            ./scripts/ssl-setup.sh letsencrypt "$DOMAIN" "$LE_EMAIL"
            ;;
        2)
            read -p "Ruta al archivo de certificado: " CERT_PATH
            read -p "Ruta al archivo de clave privada: " KEY_PATH
            if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
                cp "$CERT_PATH" docker/nginx/certs/fullchain.pem
                cp "$KEY_PATH" docker/nginx/certs/privkey.pem
                log_info "Certificados SSL copiados"
            else
                log_error "Archivos de certificado no encontrados"
            fi
            ;;
        3)
            ./scripts/ssl-setup.sh self-signed
            log_warn "Certificado autofirmado generado (¡no para producción!)"
            ;;
        4)
            log_warn "Configuración SSL omitida"
            ;;
    esac
fi

echo ""

# Construcción de imágenes Docker
log_title "Construyendo Imágenes Docker"

for ENV in $ENVIRONMENTS; do
    log_step "Construyendo imágenes $ENV..."
    
    # Determinar archivos compose a usar según entorno y detección WSL/Windows
    COMPOSE_FILES="-f docker-compose.yml"
    
    if [ "$ENV" = "dev" ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.dev.yml"
        BUILD_TARGET=development
        
        # Agregar archivo WSL si aplica
        if [ "$USE_WSL_COMPOSE" = true ]; then
            COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.wsl.yml"
            log_info "Usando configuración optimizada para WSL"
        fi
    else
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.prod.yml"
        BUILD_TARGET=production
    fi
    
    log_info "Archivos compose: $COMPOSE_FILES"
    BUILD_TARGET=$BUILD_TARGET docker-compose $COMPOSE_FILES build
    
    if [ $? -eq 0 ]; then
        log_info "Imágenes $ENV construidas exitosamente"
        
        # Si usamos volúmenes Docker y es entorno dev, sincronizar código
        if [ "$USE_DOCKER_VOLUME" = true ] && [ "$ENV" = "dev" ]; then
            log_step "Sincronizando código al volumen Docker..."
            if [ -f "./scripts/sync-to-volume.sh" ]; then
                chmod +x ./scripts/sync-to-volume.sh
                ./scripts/sync-to-volume.sh
            elif [ -f "./scripts/sync-to-volume.bat" ]; then
                ./scripts/sync-to-volume.bat
            else
                log_warn "Script de sincronización no encontrado"
            fi
        fi
    else
        log_error "Error al construir imágenes $ENV"
        exit 1
    fi
done

echo ""

# Inicialización de la base de datos
log_title "Inicialización de la Base de Datos"

read -p "¿Quieres inicializar la base de datos ahora? (Y/n): " INIT_DB
if [[ ! $INIT_DB =~ ^[Nn]$ ]]; then
    log_step "Iniciando servicio de base de datos..."
    docker-compose up -d postgres
    
    log_step "Esperando que la base de datos esté lista..."
    sleep 10
    
    log_step "Creando esquemas de base de datos..."
    # Esperar un poco más para que la base esté completamente inicializada
    sleep 5
    
    # La base de datos se inicializa automáticamente a través del script init.sql
    # Solo verificamos que esté accesible
    if docker-compose exec -T postgres psql -U dgsuc_user -d dgsuc_app -c "SELECT 1;" > /dev/null 2>&1; then
        log_info "Base de datos inicializada y accesible"
    else
        log_warn "Base de datos no completamente accesible, pero se inicializará automáticamente"
    fi
    
    log_info "Base de datos inicializada"
fi

echo ""

# Resumen final
log_title "¡Configuración Completada!"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Próximos Pasos                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [[ " $ENVIRONMENTS " =~ " dev " ]]; then
    echo "  Entorno de Desarrollo:"
    echo "    1. Revisar configuración: .env.dev"
    if [ "$USE_WSL_COMPOSE" = true ]; then
        echo "    2. Iniciar servicios (WSL optimizado): ./wsl-dev.sh start"
        echo "       O manualmente: docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.wsl.yml up -d"
    elif [ "$USE_DOCKER_VOLUME" = true ]; then
        echo "    2. Iniciar servicios (Windows optimizado): make dev-windows"
        echo "       Para sincronizar cambios: make sync-to-volume"
    else
        echo "    2. Iniciar servicios: make dev"
    fi
    echo "    3. Acceder a la aplicación: http://localhost:8080"
    echo ""
fi

if [[ " $ENVIRONMENTS " =~ " prod " ]]; then
    echo "  Entorno de Producción:"
    echo "    1. Revisar configuración: .env.prod"
    echo "    2. Desplegar: make prod"
    echo "    3. Acceder a la aplicación: https://tu-dominio.com"
    echo ""
fi

echo "  Comandos útiles:"
if [ "$USE_WSL_COMPOSE" = true ]; then
    echo "    • ./wsl-dev.sh help      - Mostrar comandos optimizados para WSL"
    echo "    • ./wsl-dev.sh logs      - Ver logs"
    echo "    • ./wsl-dev.sh shell     - Entrar al contenedor"
    echo "    • ./wsl-dev.sh optimize  - Optimizar caches"
    echo "    • make db-migrate        - Ejecutar migraciones"
elif [ "$USE_DOCKER_VOLUME" = true ]; then
    echo "    • make dev-windows       - Iniciar desarrollo (Windows optimizado)"
    echo "    • make sync-to-volume    - Sincronizar cambios al volumen"
    echo "    • make logs              - Ver logs"
    echo "    • make dev-shell         - Entrar al contenedor"
    echo "    • make db-migrate        - Ejecutar migraciones"
else
    echo "    • make help              - Mostrar todos los comandos disponibles"
    echo "    • make logs              - Ver logs"
    echo "    • make dev-shell         - Entrar al contenedor"
    echo "    • make db-migrate        - Ejecutar migraciones"
fi
echo ""

if [ "$WSL_DETECTED" = true ] && [[ "$CURRENT_PATH" == /mnt/* ]]; then
    echo "  📈 Tip de Performance:"
    echo "    Para mejor rendimiento, ejecuta: ./scripts/migrate-to-wsl.sh"
    echo ""
fi

log_info "¡Inicialización completada!"

# Mostrar información adicional según el entorno detectado
if [ "$USE_WSL_COMPOSE" = true ]; then
    echo ""
    log_info "Configuración WSL optimizada aplicada para mejor performance"
elif [ "$USE_DOCKER_VOLUME" = true ]; then
    echo ""
    log_info "Configuración con volúmenes Docker aplicada para mejor performance en Windows"
    echo ""
    echo "  💡 Nota sobre volúmenes Docker:"
    echo "    • El código se almacena en volúmenes internos de Docker"
    echo "    • Esto mejora significativamente el rendimiento en Windows"
    echo "    • Para sincronizar cambios, usa: make sync-to-volume"
    echo "    • El volumen se llama: dgsuc-docker_app_code"
fi