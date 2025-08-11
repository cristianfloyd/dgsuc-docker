#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}→${NC} $1"; }

# Header
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           DGSUC Docker Configuration Validator            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

# Check Docker Compose syntax
log_step "Validating Docker Compose syntax..."

if docker-compose config > /dev/null 2>&1; then
    log_info "Docker Compose syntax is valid"
else
    log_error "Docker Compose syntax is invalid"
    docker-compose config
    ERRORS=$((ERRORS + 1))
fi

# Check required files
log_step "Checking required files..."

REQUIRED_FILES=(
    "docker-compose.yml"
    "docker/app/Dockerfile"
    "docker/nginx/Dockerfile"
    "docker/nginx/nginx.conf"
    "docker/postgres/postgresql.conf"
    "docker/redis/redis.conf"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_info "$file exists"
    else
        log_error "$file is missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check environment files
log_step "Checking environment configuration..."

if [ -f ".env.dev" ]; then
    log_info ".env.dev exists"
else
    log_warn ".env.dev is missing (recommended for development)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f ".env.prod" ]; then
    log_info ".env.prod exists"
else
    log_warn ".env.prod is missing (recommended for production)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check application directory
log_step "Checking application directory..."

if [ -d "app" ]; then
    log_info "Application directory exists"
    
    # Check Laravel files
    if [ -f "app/.env" ]; then
        log_info "Laravel .env exists"
    else
        log_warn "Laravel .env is missing"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if [ -f "app/composer.json" ]; then
        log_info "Laravel composer.json exists"
    else
        log_error "Laravel composer.json is missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    log_warn "Application directory is missing (run ./scripts/clone-app.sh)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check SSL certificates
log_step "Checking SSL configuration..."

if [ -d "docker/nginx/certs" ]; then
    log_info "SSL certificates directory exists"
    
    if [ -f "docker/nginx/certs/fullchain.pem" ] && [ -f "docker/nginx/certs/privkey.pem" ]; then
        log_info "SSL certificates found"
    else
        log_warn "SSL certificates not found (run make ssl-setup)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_warn "SSL certificates directory is missing"
    WARNINGS=$((WARNINGS + 1))
fi

# Check SSH keys
log_step "Checking SSH configuration..."

if [ -d "ssh-keys" ] || [ -d "$HOME/.ssh" ]; then
    log_info "SSH keys directory exists"
else
    log_warn "SSH keys directory is missing (if using external databases)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Docker daemon
log_step "Checking Docker daemon..."

if docker info > /dev/null 2>&1; then
    log_info "Docker daemon is running"
else
    log_error "Docker daemon is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check available disk space
log_step "Checking disk space..."

DISK_SPACE=$(df . | awk 'NR==2 {print $4}')
DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))

if [ $DISK_SPACE_GB -gt 10 ]; then
    log_info "Sufficient disk space available (${DISK_SPACE_GB}GB)"
else
    log_warn "Low disk space (${DISK_SPACE_GB}GB) - recommend at least 10GB"
    WARNINGS=$((WARNINGS + 1))
fi

# Check memory
log_step "Checking system memory..."

if command -v free > /dev/null 2>&1; then
    MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
    if [ $MEMORY_GB -gt 4 ]; then
        log_info "Sufficient memory available (${MEMORY_GB}GB)"
    else
        log_warn "Low memory (${MEMORY_GB}GB) - recommend at least 4GB for production"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_warn "Cannot check memory (free command not available)"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Validation Summary                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_info "Configuration is valid! Ready to deploy."
    echo ""
    echo "Next steps:"
    echo "  • Development: make dev"
    echo "  • Production: make prod"
    echo "  • View logs: make logs"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log_warn "Configuration has $WARNINGS warnings but no errors."
    echo ""
    echo "Warnings should be addressed for optimal operation."
    exit 0
else
    log_error "Configuration has $ERRORS errors and $WARNINGS warnings."
    echo ""
    echo "Please fix the errors before proceeding."
    exit 1
fi
