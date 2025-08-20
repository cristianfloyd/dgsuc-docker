#!/bin/bash
set -e

# Configuration
REPO_URL=${1:-"https://github.com/cristianfloyd/dgsuc-app.git"}
BRANCH=${2:-"main"}
APP_DIR="./app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Header
echo "================================================"
echo "       DGSUC Application Clone Script"
echo "================================================"
echo ""

# Check if app directory exists
if [ -d "$APP_DIR" ]; then
    log_warn "Application directory already exists at $APP_DIR"
    
    # Check if it's a git repository
    if [ -d "$APP_DIR/.git" ]; then
        log_info "Updating existing repository..."
        cd $APP_DIR
        
        # Save any local changes
        if [[ -n $(git status -s) ]]; then
            log_warn "Local changes detected, stashing..."
            git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
        fi
        
        # Pull latest changes
        log_step "Pulling latest changes from $BRANCH..."
        git fetch origin
        git checkout $BRANCH
        git pull origin $BRANCH
        
        log_info "Repository updated successfully!"
    else
        log_error "Directory exists but is not a git repository"
        read -p "Do you want to remove it and clone fresh? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf $APP_DIR
        else
            log_error "Aborting..."
            exit 1
        fi
    fi
else
    # Clone repository
    log_step "Cloning repository from $REPO_URL..."
    git clone -b $BRANCH $REPO_URL $APP_DIR
    
    if [ $? -eq 0 ]; then
        log_info "Repository cloned successfully!"
    else
        log_error "Failed to clone repository"
        exit 1
    fi
fi

# Copy environment file if it doesn't exist
if [ ! -f "$APP_DIR/.env" ]; then
    if [ -f "$APP_DIR/.env.example" ]; then
        log_step "Creating .env file from example..."
        cp $APP_DIR/.env.example $APP_DIR/.env
        log_warn "Please configure $APP_DIR/.env with your settings"
    fi
fi

# Create necessary directories
log_step "Creating storage directories..."
mkdir -p $APP_DIR/storage/app/public
mkdir -p $APP_DIR/storage/framework/{cache,sessions,testing,views}
mkdir -p $APP_DIR/storage/logs
mkdir -p $APP_DIR/bootstrap/cache

# Set permissions
log_step "Setting permissions..."
chmod -R 775 $APP_DIR/storage
chmod -R 775 $APP_DIR/bootstrap/cache

# Summary
echo ""
echo "================================================"
echo "              Clone Complete!"
echo "================================================"
echo ""
log_info "Application cloned to: $APP_DIR"
log_info "Branch: $BRANCH"
log_info "Next steps:"
echo "  1. Configure environment: $APP_DIR/.env"
echo "  2. Run: make init"
echo "  3. Run: make dev (for development) or make prod (for production)"
echo ""