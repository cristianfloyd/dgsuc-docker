#!/bin/bash
set -e

# Colores para la salida de consola
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

# Encabezado del script
clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC Docker Environment Setup                  ║"
echo "║                 Initialization Script                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Verificación de prerrequisitos
log_title "Verificación de Prerrequisitos"

check_command() {
    if command -v $1 &> /dev/null; then
        log_info "$1 está instalado ($(command -v $1))"
        return 0
    else
        log_error "$1 no está instalado"
        return 1
    fi
}

MISSING_DEPS=0

check_command docker || MISSING_DEPS=1
check_command docker-compose || MISSING_DEPS=1
check_command git || MISSING_DEPS=1
check_command make || log_warn "make no está instalado (opcional pero recomendado)"

if [ $MISSING_DEPS -eq 1 ]; then
    log_error "Faltan dependencias requeridas. Por favor instálalas primero."
    exit 1
fi

# Verificación del daemon de Docker
if ! docker info &> /dev/null; then
    log_error "El daemon de Docker no está ejecutándose"
    exit 1
fi
log_info "El daemon de Docker está ejecutándose"

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

# Sincronizar archivos .env después de crearlos
log_step "Sincronizando archivos de configuración..."
sync_env_files

echo ""

# Generación de clave de Laravel si es necesario
if [ -f "./app/.env" ]; then
    if grep -q "APP_KEY=$" "./app/.env" || grep -q "APP_KEY=\s*$" "./app/.env"; then
        log_step "Generando clave de aplicación Laravel..."
        docker run --rm -v $(pwd)/app:/app -w /app php:8.3-cli php artisan key:generate
        log_info "Clave de aplicación generada"
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
    
    if [ "$ENV" = "dev" ]; then
        BUILD_TARGET=development docker-compose -f docker-compose.yml -f docker-compose.dev.yml build
    else
        BUILD_TARGET=production docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Imágenes $ENV construidas exitosamente"
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
    echo "    2. Iniciar servicios: make dev"
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
echo "    • make help       - Mostrar todos los comandos disponibles"
echo "    • make logs       - Ver logs"
echo "    • make shell      - Entrar al contenedor"
echo "    • make db-migrate - Ejecutar migraciones"
echo ""

log_info "¡Inicialización completada!"