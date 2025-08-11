#!/bin/bash
set -e

# Configuration
BACKUP_TYPE=${1:-"full"}
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Load environment
if [ -f ".env.prod" ]; then
    export $(cat .env.prod | grep -v '^#' | xargs)
elif [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

case "$BACKUP_TYPE" in
    "database"|"db")
        log_info "Starting database backup..."
        
        # Backup main database
        log_step "Backing up PostgreSQL database..."
        docker-compose exec -T postgres pg_dump \
            -U ${DB_USERNAME:-informes_user} \
            -d ${DB_DATABASE:-informes_app} \
            --no-owner \
            --no-acl \
            > "$BACKUP_DIR/db_${DATE}.sql"
        
        # Compress
        gzip "$BACKUP_DIR/db_${DATE}.sql"
        
        log_info "Database backup completed: db_${DATE}.sql.gz"
        ;;
        
    "files")
        log_info "Starting files backup..."
        
        # Backup application files
        log_step "Backing up application files..."
        tar -czf "$BACKUP_DIR/files_${DATE}.tar.gz" \
            --exclude='app/vendor' \
            --exclude='app/node_modules' \
            --exclude='app/storage/logs/*' \
            --exclude='app/storage/framework/cache/*' \
            --exclude='app/storage/framework/sessions/*' \
            --exclude='app/.git' \
            app/
        
        log_info "Files backup completed: files_${DATE}.tar.gz"
        ;;
        
    "storage")
        log_info "Starting storage backup..."
        
        # Backup storage directory
        log_step "Backing up storage..."
        tar -czf "$BACKUP_DIR/storage_${DATE}.tar.gz" \
            --exclude='storage/logs/*' \
            --exclude='storage/framework/cache/*' \
            --exclude='storage/framework/sessions/*' \
            app/storage/
        
        log_info "Storage backup completed: storage_${DATE}.tar.gz"
        ;;
        
    "config")
        log_info "Starting configuration backup..."
        
        # Backup configuration files
        log_step "Backing up configuration..."
        tar -czf "$BACKUP_DIR/config_${DATE}.tar.gz" \
            .env* \
            docker-compose*.yml \
            docker/ \
            scripts/
        
        log_info "Configuration backup completed: config_${DATE}.tar.gz"
        ;;
        
    "full")
        log_info "Starting full backup..."
        
        # Database
        log_step "Backing up database..."
        docker-compose exec -T postgres pg_dump \
            -U ${DB_USERNAME:-informes_user} \
            -d ${DB_DATABASE:-informes_app} \
            --no-owner \
            --no-acl \
            > "$BACKUP_DIR/full_db_${DATE}.sql"
        
        # Files
        log_step "Backing up files..."
        tar -czf "$BACKUP_DIR/full_files_${DATE}.tar.gz" \
            --exclude='app/vendor' \
            --exclude='app/node_modules' \
            --exclude='app/storage/logs/*' \
            --exclude='app/storage/framework/cache/*' \
            --exclude='app/storage/framework/sessions/*' \
            --exclude='app/.git' \
            app/ \
            docker/ \
            scripts/ \
            docker-compose*.yml \
            .env* \
            Makefile
        
        # Compress database
        gzip "$BACKUP_DIR/full_db_${DATE}.sql"
        
        # Create manifest
        cat > "$BACKUP_DIR/full_${DATE}.manifest" <<EOF
Backup Date: ${DATE}
Type: Full Backup
Database: full_db_${DATE}.sql.gz
Files: full_files_${DATE}.tar.gz
Docker Version: $(docker --version)
Compose Version: $(docker-compose --version)
EOF
        
        log_info "Full backup completed!"
        log_info "  - Database: full_db_${DATE}.sql.gz"
        log_info "  - Files: full_files_${DATE}.tar.gz"
        log_info "  - Manifest: full_${DATE}.manifest"
        ;;
        
    "pre-deploy")
        log_info "Creating pre-deployment backup..."
        
        # Quick backup before deployment
        BACKUP_NAME="pre-deploy_${DATE}"
        
        # Database only
        docker-compose exec -T postgres pg_dump \
            -U ${DB_USERNAME:-informes_user} \
            -d ${DB_DATABASE:-informes_app} \
            --no-owner \
            --no-acl \
            | gzip > "$BACKUP_DIR/${BACKUP_NAME}.sql.gz"
        
        log_info "Pre-deployment backup completed: ${BACKUP_NAME}.sql.gz"
        ;;
        
    *)
        log_error "Unknown backup type: $BACKUP_TYPE"
        echo "Usage: $0 [database|files|storage|config|full|pre-deploy]"
        exit 1
        ;;
esac

# Cleanup old backups
if [ "$RETENTION_DAYS" -gt 0 ]; then
    log_step "Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    find "$BACKUP_DIR" -name "*.manifest" -mtime +${RETENTION_DAYS} -delete
fi

# Upload to S3 if configured
if [ "${BACKUP_S3_ENABLED:-false}" = "true" ]; then
    log_step "Uploading to S3..."
    
    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not found, skipping S3 upload"
    else
        # Find latest backup files
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*_${DATE}* 2>/dev/null | head -1)
        
        if [ -f "$LATEST_BACKUP" ]; then
            aws s3 cp "$LATEST_BACKUP" "s3://${BACKUP_S3_BUCKET}/$(basename $LATEST_BACKUP)"
            log_info "Backup uploaded to S3: $(basename $LATEST_BACKUP)"
        fi
    fi
fi

# Show backup summary
echo ""
log_info "Backup Summary:"
echo "Location: $BACKUP_DIR"
echo "Size: $(du -sh $BACKUP_DIR | cut -f1)"
echo "Files:"
ls -lh "$BACKUP_DIR"/*_${DATE}* 2>/dev/null || echo "No files created"

log_info "Backup process completed successfully!"