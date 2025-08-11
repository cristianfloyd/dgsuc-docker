#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}→${NC} $1"; }
log_title() { echo -e "${MAGENTA}═══ $1 ═══${NC}"; }

# Header
clear
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC Docker Environment Setup                  ║"
echo "║                 Initialization Script                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
log_title "Checking Prerequisites"

check_command() {
    if command -v $1 &> /dev/null; then
        log_info "$1 is installed ($(command -v $1))"
        return 0
    else
        log_error "$1 is not installed"
        return 1
    fi
}

MISSING_DEPS=0

check_command docker || MISSING_DEPS=1
check_command docker-compose || MISSING_DEPS=1
check_command git || MISSING_DEPS=1
check_command make || log_warn "make is not installed (optional but recommended)"

if [ $MISSING_DEPS -eq 1 ]; then
    log_error "Missing required dependencies. Please install them first."
    exit 1
fi

# Check Docker daemon
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi
log_info "Docker daemon is running"

echo ""

# Select environment
log_title "Environment Selection"
echo "Select environment to initialize:"
echo "  1) Development"
echo "  2) Production"
echo "  3) Both"
read -p "Enter choice [1-3]: " ENV_CHOICE

case $ENV_CHOICE in
    1) ENVIRONMENTS="dev" ;;
    2) ENVIRONMENTS="prod" ;;
    3) ENVIRONMENTS="dev prod" ;;
    *) log_error "Invalid choice"; exit 1 ;;
esac

echo ""

# Clone application
log_title "Application Setup"

if [ ! -d "./app" ]; then
    read -p "Enter Git repository URL (or press Enter for default): " REPO_URL
    REPO_URL=${REPO_URL:-"https://github.com/uba/dgsuc-sistema.git"}
    
    read -p "Enter branch name (default: main): " BRANCH
    BRANCH=${BRANCH:-"main"}
    
    log_step "Cloning application..."
    ./scripts/clone-app.sh "$REPO_URL" "$BRANCH"
else
    log_info "Application directory already exists"
    read -p "Do you want to update it? (y/N): " UPDATE_APP
    if [[ $UPDATE_APP =~ ^[Yy]$ ]]; then
        cd app && git pull && cd ..
        log_info "Application updated"
    fi
fi

echo ""

# Setup environment files
log_title "Environment Configuration"

for ENV in $ENVIRONMENTS; do
    ENV_FILE=".env.$ENV"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_step "Creating $ENV_FILE..."
        cp .env.example "$ENV_FILE"
        log_warn "Please configure $ENV_FILE before continuing"
        
        # Interactive configuration for critical values
        if [ "$ENV" = "prod" ]; then
            echo ""
            log_step "Configure production settings:"
            read -p "Database password: " -s DB_PASS
            echo ""
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" "$ENV_FILE"
            
            read -p "Redis password (optional): " -s REDIS_PASS
            echo ""
            if [ ! -z "$REDIS_PASS" ]; then
                sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASS/" "$ENV_FILE"
            fi
            
            read -p "App URL (e.g., https://dgsuc.uba.ar): " APP_URL
            sed -i "s|APP_URL=.*|APP_URL=$APP_URL|" "$ENV_FILE"
        fi
    else
        log_info "$ENV_FILE already exists"
    fi
done

echo ""

# Generate Laravel key if needed
if [ -f "./app/.env" ]; then
    if grep -q "APP_KEY=$" "./app/.env" || grep -q "APP_KEY=\s*$" "./app/.env"; then
        log_step "Generating Laravel application key..."
        docker run --rm -v $(pwd)/app:/app -w /app php:8.3-cli php artisan key:generate
        log_info "Application key generated"
    fi
fi

echo ""

# SSH keys setup
log_title "SSH Configuration"

if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
fi

read -p "Do you need to configure SSH tunnels for external databases? (y/N): " SETUP_SSH
if [[ $SETUP_SSH =~ ^[Yy]$ ]]; then
    log_step "Setting up SSH keys..."
    
    read -p "Path to SSH private key for tunnels: " SSH_KEY_PATH
    if [ -f "$SSH_KEY_PATH" ]; then
        cp "$SSH_KEY_PATH" "$HOME/.ssh/tunnel_key"
        chmod 600 "$HOME/.ssh/tunnel_key"
        log_info "SSH key configured"
    else
        log_error "SSH key not found at $SSH_KEY_PATH"
    fi
    
    # Update tunnel configuration
    read -p "SSH tunnel host: " SSH_HOST
    read -p "SSH tunnel user: " SSH_USER
    read -p "SSH tunnel port (default: 22): " SSH_PORT
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

# SSL setup for production
if [[ " $ENVIRONMENTS " =~ " prod " ]]; then
    log_title "SSL Configuration"
    
    echo "Select SSL certificate option:"
    echo "  1) Generate with Let's Encrypt"
    echo "  2) Use existing certificates"
    echo "  3) Generate self-signed (testing only)"
    echo "  4) Skip for now"
    read -p "Enter choice [1-4]: " SSL_CHOICE
    
    case $SSL_CHOICE in
        1)
            read -p "Enter domain (e.g., dgsuc.uba.ar): " DOMAIN
            read -p "Enter email for Let's Encrypt: " LE_EMAIL
            ./scripts/ssl-setup.sh letsencrypt "$DOMAIN" "$LE_EMAIL"
            ;;
        2)
            read -p "Path to certificate file: " CERT_PATH
            read -p "Path to private key file: " KEY_PATH
            if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
                cp "$CERT_PATH" docker/nginx/certs/fullchain.pem
                cp "$KEY_PATH" docker/nginx/certs/privkey.pem
                log_info "SSL certificates copied"
            else
                log_error "Certificate files not found"
            fi
            ;;
        3)
            ./scripts/ssl-setup.sh self-signed
            log_warn "Self-signed certificate generated (not for production!)"
            ;;
        4)
            log_warn "SSL configuration skipped"
            ;;
    esac
fi

echo ""

# Build Docker images
log_title "Building Docker Images"

for ENV in $ENVIRONMENTS; do
    log_step "Building $ENV images..."
    
    if [ "$ENV" = "dev" ]; then
        BUILD_TARGET=development docker-compose -f docker-compose.yml -f docker-compose.dev.yml build
    else
        BUILD_TARGET=production docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
    fi
    
    if [ $? -eq 0 ]; then
        log_info "$ENV images built successfully"
    else
        log_error "Failed to build $ENV images"
        exit 1
    fi
done

echo ""

# Initialize database
log_title "Database Initialization"

read -p "Do you want to initialize the database now? (Y/n): " INIT_DB
if [[ ! $INIT_DB =~ ^[Nn]$ ]]; then
    log_step "Starting database service..."
    docker-compose up -d postgres
    
    log_step "Waiting for database to be ready..."
    sleep 10
    
    log_step "Creating database schemas..."
    # Check if database is already initialized
    if docker-compose exec -T postgres psql -U informes_user -d informes_app -c "SELECT 1;" > /dev/null 2>&1; then
        log_info "Database already initialized and accessible"
    else
        # If not accessible, try with environment variables
        docker-compose exec -T -e PGPASSWORD="${DB_PASSWORD}" postgres psql -U informes_user -d informes_app << EOF
CREATE SCHEMA IF NOT EXISTS suc_app;
CREATE SCHEMA IF NOT EXISTS informes_app;
ALTER DATABASE informes_app SET search_path = 'suc_app,informes_app,public';
EOF
    fi
    
    log_info "Database initialized"
fi

echo ""

# Final summary
log_title "Setup Complete!"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Next Steps                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [[ " $ENVIRONMENTS " =~ " dev " ]]; then
    echo "  Development Environment:"
    echo "    1. Review configuration: .env.dev"
    echo "    2. Start services: make dev"
    echo "    3. Access application: http://localhost:8080"
    echo ""
fi

if [[ " $ENVIRONMENTS " =~ " prod " ]]; then
    echo "  Production Environment:"
    echo "    1. Review configuration: .env.prod"
    echo "    2. Deploy: make prod"
    echo "    3. Access application: https://your-domain.com"
    echo ""
fi

echo "  Useful commands:"
echo "    • make help       - Show all available commands"
echo "    • make logs       - View logs"
echo "    • make shell      - Enter container"
echo "    • make db-migrate - Run migrations"
echo ""

log_info "Initialization complete!"