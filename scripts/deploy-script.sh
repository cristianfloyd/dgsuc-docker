#!/bin/bash
set -e

# Definición de códigos de color ANSI para la interfaz de línea de comandos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin Color

# Configuración de variables de entorno y archivos de composición
ENVIRONMENT=${1:-production}
COMPOSE_FILES="-f docker-compose.yml"

# Funciones de logging para estandarizar la salida de mensajes
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validación y configuración del entorno de despliegue
if [ "$ENVIRONMENT" == "production" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.prod.yml"
    ENV_FILE=".env.prod"
    BUILD_TARGET="production"
elif [ "$ENVIRONMENT" == "development" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.dev.yml"
    ENV_FILE=".env.dev"
    BUILD_TARGET="development"
else
    log_error "Invalid environment: $ENVIRONMENT"
    exit 1
fi

log_info "Desplegando Sistema DGSUC - Entorno: $ENVIRONMENT"

# Verificación de dependencias del sistema requeridas
log_info "Verificando prerrequisitos..."

if ! command -v docker &> /dev/null; then
    log_error "Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose no está instalado"
    exit 1
fi

# Validación de archivo de configuración de entorno
if [ ! -f "$ENV_FILE" ]; then
    log_error "Archivo de entorno $ENV_FILE no encontrado"
    log_info "Creando desde plantilla..."
    cp .env.docker.example $ENV_FILE
    log_warn "Por favor configura $ENV_FILE antes de continuar"
    exit 1
fi

# Carga de variables de entorno desde archivo de configuración
export $(cat $ENV_FILE | grep -v '^#' | xargs)
export BUILD_TARGET

# Creación de respaldo pre-despliegue (solo para producción)
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Creando respaldo pre-despliegue..."
    ./scripts/backup.sh pre-deploy
fi

# Sincronización del código fuente desde el repositorio remoto
log_info "Sincronizando código fuente..."
git pull origin main

# Compilación de assets frontend (ambos entornos)
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Compilando assets de producción..."
    docker run --rm \
        -v "$(pwd)/app:/var/www/html" \
        -w /var/www/html \
        node:18-alpine \
        sh -c "npm install --production && npm run build"
elif [ "$ENVIRONMENT" == "development" ]; then
    log_info "Compilando assets de desarrollo..."
    docker run --rm \
        -v "$(pwd)/app:/var/www/html" \
        -w /var/www/html \
        node:18-alpine \
        sh -c "npm install && npm run build"
fi

# Construcción de imágenes Docker sin caché
log_info "Construyendo imágenes Docker..."
docker-compose $COMPOSE_FILES build --no-cache

# Detención de contenedores actuales
log_info "Deteniendo contenedores actuales..."
docker-compose $COMPOSE_FILES down

# Inicialización de servicios de infraestructura
log_info "Iniciando servicios de infraestructura..."
docker-compose $COMPOSE_FILES up -d postgres redis ssh-tunnel

# Espera para estabilización de la base de datos
log_info "Esperando que la base de datos esté lista..."
sleep 10

# Ejecución de migraciones de base de datos
log_info "Ejecutando migraciones de base de datos..."
docker-compose $COMPOSE_FILES run --rm app php artisan migrate --force

# Limpieza y reconstrucción de cachés de Laravel
log_info "Limpiando cachés..."
docker-compose $COMPOSE_FILES run --rm app php artisan cache:clear
docker-compose $COMPOSE_FILES run --rm app php artisan config:clear
docker-compose $COMPOSE_FILES run --rm app php artisan view:clear

# Optimización de cachés para entorno de producción
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Construyendo cachés de producción..."
    docker-compose $COMPOSE_FILES run --rm app php artisan config:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan route:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan view:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan event:cache
fi

# Inicialización de todos los servicios de la aplicación
log_info "Iniciando todos los servicios..."
docker-compose $COMPOSE_FILES up -d

# Espera para estabilización de servicios
log_info "Esperando que los servicios estén saludables..."
sleep 10

# Verificación de estado de salud de servicios
log_info "Ejecutando verificaciones de salud..."
SERVICES=("app" "nginx" "postgres" "redis" "ssh-tunnel")

# Iteración para validar el estado de cada servicio
for service in "${SERVICES[@]}"; do
    if docker-compose $COMPOSE_FILES ps | grep -q "dgsuc_${service}.*Up"; then
        log_info "✓ ${service} está ejecutándose"
    else
        log_error "✗ ${service} no está ejecutándose"
        exit 1
    fi
done

# Verificación y generación de certificados SSL (solo para producción)
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Verificando certificados SSL..."
    
    # Generación automática de certificados SSL con Let's Encrypt
    if [ ! -f "docker/nginx/certs/fullchain.pem" ]; then
        log_warn "Certificado SSL no encontrado, generando con certbot..."
        docker run -it --rm \
            -v "$(pwd)/docker/nginx/certs:/etc/letsencrypt" \
            -v "$(pwd)/public:/var/www/html" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/html \
            --email admin@uba.ar \
            --agree-tos \
            --no-eff-email \
            -d dgsuc.uba.ar \
            -d www.dgsuc.uba.ar
    fi
fi

# Ejecución de pruebas automatizadas (solo para desarrollo)
if [ "$ENVIRONMENT" == "development" ]; then
    log_info "Ejecutando pruebas..."
    docker-compose $COMPOSE_FILES run --rm app php artisan test
fi

# Visualización del estado final de servicios
log_info "¡Despliegue completado! Estado de servicios:"
docker-compose $COMPOSE_FILES ps

# Visualización de logs recientes para diagnóstico
log_info "Logs recientes:"
docker-compose $COMPOSE_FILES logs --tail=20

# Mensaje final con información de acceso
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "¡Despliegue de producción exitoso!"
    log_info "Aplicación disponible en: https://dgsuc.uba.ar"
else
    log_info "¡Despliegue de desarrollo exitoso!"
    log_info "Aplicación disponible en: http://localhost:8080"
    log_info "Mailhog: http://localhost:8025"
    log_info "PHPMyAdmin: http://localhost:8090"
fi

# Comandos útiles para administración post-despliegue
log_info "Para ver logs: docker-compose $COMPOSE_FILES logs -f [nombre_servicio]"
log_info "Para entrar al contenedor: docker-compose $COMPOSE_FILES exec app bash"