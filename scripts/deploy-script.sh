#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-production}
COMPOSE_FILES="-f docker-compose.yml"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check environment
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

log_info "Deploying DGSUC System - Environment: $ENVIRONMENT"

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi

# Check environment file
if [ ! -f "$ENV_FILE" ]; then
    log_error "Environment file $ENV_FILE not found"
    log_info "Creating from example..."
    cp .env.docker.example $ENV_FILE
    log_warn "Please configure $ENV_FILE before continuing"
    exit 1
fi

# Load environment
export $(cat $ENV_FILE | grep -v '^#' | xargs)
export BUILD_TARGET

# Pre-deployment backup (production only)
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Creating pre-deployment backup..."
    ./scripts/backup.sh pre-deploy
fi

# Pull latest code
log_info "Pulling latest code..."
git pull origin main

# Build images
log_info "Building Docker images..."
docker-compose $COMPOSE_FILES build --no-cache

# Stop current containers
log_info "Stopping current containers..."
docker-compose $COMPOSE_FILES down

# Start database and redis first
log_info "Starting infrastructure services..."
docker-compose $COMPOSE_FILES up -d postgres redis ssh-tunnel

# Wait for database
log_info "Waiting for database to be ready..."
sleep 10

# Run migrations
log_info "Running database migrations..."
docker-compose $COMPOSE_FILES run --rm app php artisan migrate --force

# Clear and rebuild caches
log_info "Clearing caches..."
docker-compose $COMPOSE_FILES run --rm app php artisan cache:clear
docker-compose $COMPOSE_FILES run --rm app php artisan config:clear
docker-compose $COMPOSE_FILES run --rm app php artisan view:clear

if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Building production caches..."
    docker-compose $COMPOSE_FILES run --rm app php artisan config:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan route:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan view:cache
    docker-compose $COMPOSE_FILES run --rm app php artisan event:cache
fi

# Start all services
log_info "Starting all services..."
docker-compose $COMPOSE_FILES up -d

# Wait for services to be healthy
log_info "Waiting for services to be healthy..."
sleep 10

# Health check
log_info "Running health checks..."
SERVICES=("app" "nginx" "postgres" "redis" "ssh-tunnel")

for service in "${SERVICES[@]}"; do
    if docker-compose $COMPOSE_FILES ps | grep -q "dgsuc_${service}.*Up"; then
        log_info "✓ ${service} is running"
    else
        log_error "✗ ${service} is not running"
        exit 1
    fi
done

# SSL Certificate check (production only)
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Checking SSL certificates..."
    
    if [ ! -f "docker/nginx/certs/fullchain.pem" ]; then
        log_warn "SSL certificate not found, generating with certbot..."
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

# Run tests (development only)
if [ "$ENVIRONMENT" == "development" ]; then
    log_info "Running tests..."
    docker-compose $COMPOSE_FILES run --rm app php artisan test
fi

# Show status
log_info "Deployment complete! Services status:"
docker-compose $COMPOSE_FILES ps

# Show logs
log_info "Recent logs:"
docker-compose $COMPOSE_FILES logs --tail=20

# Final message
if [ "$ENVIRONMENT" == "production" ]; then
    log_info "Production deployment successful!"
    log_info "Application is available at: https://dgsuc.uba.ar"
else
    log_info "Development deployment successful!"
    log_info "Application is available at: http://localhost:8080"
    log_info "Mailhog: http://localhost:8025"
    log_info "PHPMyAdmin: http://localhost:8090"
fi

log_info "To view logs: docker-compose $COMPOSE_FILES logs -f [service_name]"
log_info "To enter container: docker-compose $COMPOSE_FILES exec app bash"